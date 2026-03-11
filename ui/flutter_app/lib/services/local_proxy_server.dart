import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/network_connection.dart';
import 'ftp_service.dart';
import 'smb_service.dart';

class LocalProxyServer {
  static const int _defaultChunkSize = 4 * 1024 * 1024;

  HttpServer? _server;
  int _port = 8080;
  final Map<String, _ProxySession> _sessions = {};

  FTPService? _ftpService;
  SMBService? _smbService;

  bool get isRunning => _server != null;
  int get port => _port;

  Future<void> start({int port = 8080}) async {
    if (_server != null) {
      print('[ProxyServer] 服务器已在运行');
      return;
    }

    _port = port;

    try {
      final router = Router();
      router.get('/proxy/<sessionId>', _handleProxyRequest);
      router.head('/proxy/<sessionId>', _handleProxyRequest);
      router.get('/health', (Request request) => Response.ok('OK'));

      final handler =
          Pipeline().addMiddleware(logRequests()).addHandler(router);

      _server = await shelf_io.serve(handler, 'localhost', _port);
      print('[ProxyServer] 代理服务器启动成功: http://localhost:$_port');
    } catch (e) {
      print('[ProxyServer] 启动失败: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;

    for (final session in _sessions.values) {
      await session.dispose();
    }
    _sessions.clear();

    print('[ProxyServer] 代理服务器已停止');
  }

  String createProxyUrl(NetworkConnection connection, String remotePath) {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

    _sessions[sessionId] = _ProxySession(
      connection: connection,
      remotePath: remotePath,
    );

    return 'http://localhost:$_port/proxy/$sessionId';
  }

  Future<Response> _handleProxyRequest(
      Request request, String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return Response.notFound('Session not found');
    }

    try {
      final range = _parseRangeHeader(request.headers['range']);
      final isHeadRequest = request.method.toUpperCase() == 'HEAD';

      if (session.connection.protocol == NetworkProtocol.smb) {
        return await _handleSmbRequest(
          request: request,
          session: session,
          range: range,
          isHeadRequest: isHeadRequest,
        );
      }

      if (session.connection.protocol == NetworkProtocol.ftp) {
        return await _handleFtpRequest(
          session: session,
          range: range,
          isHeadRequest: isHeadRequest,
        );
      }

      return Response.internalServerError(body: 'Unsupported protocol');
    } catch (e) {
      print('[ProxyServer] 处理请求失败: $e');
      return Response.internalServerError(body: 'Error: $e');
    }
  }

  Future<Response> _handleSmbRequest({
    required Request request,
    required _ProxySession session,
    required _ByteRange? range,
    required bool isHeadRequest,
  }) async {
    _smbService ??= SMBService();
    if (!_smbService!.isConnected) {
      final connected = await _smbService!.connect(session.connection);
      if (!connected) {
        return Response.internalServerError(body: 'SMB connect failed');
      }
    }

    if (_smbService!.supportsNativeStreaming) {
      final file = _smbService!.getNativeFile(session.remotePath);
      if (file == null || !await file.exists()) {
        return Response.notFound('File not found');
      }

      final totalSize = await file.length();
      final start = range?.start ?? 0;
      final end =
          range?.resolveEnd(totalSize, _defaultChunkSize) ?? (totalSize - 1);
      final contentLength = end >= start ? end - start + 1 : 0;

      final headers = _buildHeaders(
        path: session.remotePath,
        totalSize: totalSize,
        start: start,
        end: end,
        contentLength: contentLength,
      );

      if (isHeadRequest) {
        return Response(range == null ? 200 : 206, headers: headers);
      }

      return Response(
        range == null ? 200 : 206,
        body: file.openRead(start, end + 1),
        headers: headers,
      );
    }

    final dataResult = await _readSMBFile(
      session.remotePath,
      range?.start,
      range?.end,
    );
    final data = dataResult['data'] as List<int>;
    final totalSize = dataResult['totalSize'] as int;
    final start = range?.start ?? 0;
    final end = range?.end ?? (start + data.length - 1);
    final headers = _buildHeaders(
      path: session.remotePath,
      totalSize: totalSize,
      start: start,
      end: end,
      contentLength: data.length,
    );

    if (isHeadRequest) {
      return Response(range == null ? 200 : 206, headers: headers);
    }

    return Response(
      range == null ? 200 : 206,
      body: Stream.value(data),
      headers: headers,
    );
  }

  Future<Response> _handleFtpRequest({
    required _ProxySession session,
    required _ByteRange? range,
    required bool isHeadRequest,
  }) async {
    _ftpService ??= FTPService();
    if (!_ftpService!.isConnected) {
      final connected = await _ftpService!.connect(session.connection);
      if (!connected) {
        return Response.internalServerError(body: 'FTP connect failed');
      }
    }

    final result =
        await _readFTPFile(session.remotePath, range?.start, range?.end);
    final data = result['data'] as List<int>;
    final totalSize = result['totalSize'] as int;
    final start = range?.start ?? 0;
    final end = range?.end ?? (start + data.length - 1);
    final headers = _buildHeaders(
      path: session.remotePath,
      totalSize: totalSize,
      start: start,
      end: end,
      contentLength: data.length,
    );

    if (isHeadRequest) {
      return Response(range == null ? 200 : 206, headers: headers);
    }

    return Response(
      range == null ? 200 : 206,
      body: Stream.value(data),
      headers: headers,
    );
  }

  Map<String, String> _buildHeaders({
    required String path,
    required int totalSize,
    required int start,
    required int end,
    required int contentLength,
  }) {
    final headers = <String, String>{
      'Content-Type': _getMimeType(path),
      'Accept-Ranges': 'bytes',
      'Access-Control-Allow-Origin': '*',
      'Content-Length': contentLength.toString(),
      'Cache-Control': 'no-store',
      'Connection': 'keep-alive',
    };

    if (start > 0 || end < totalSize - 1) {
      headers['Content-Range'] = 'bytes $start-$end/$totalSize';
    }

    return headers;
  }

  _ByteRange? _parseRangeHeader(String? rangeHeader) {
    if (rangeHeader == null || rangeHeader.isEmpty) return null;
    final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
    if (match == null) return null;
    final start = int.tryParse(match.group(1) ?? '');
    final endText = match.group(2);
    final end =
        endText == null || endText.isEmpty ? null : int.tryParse(endText);
    if (start == null) return null;
    return _ByteRange(start: start, end: end);
  }

  Future<Map<String, dynamic>> _readFTPFile(
    String remotePath,
    int? start,
    int? end,
  ) async {
    final totalSize = 1000000000;
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_${remotePath.split('/').last}',
    );

    await _ftpService!.downloadFile(remotePath, tempFile.path);

    final file = await tempFile.open();
    if (start != null) {
      await file.setPosition(start);
    }

    final length = end != null ? (end - (start ?? 0) + 1) : null;
    final data = await file.read(length ?? totalSize);
    await file.close();
    await tempFile.delete();

    return {
      'data': data,
      'totalSize': totalSize,
    };
  }

  Future<Map<String, dynamic>> _readSMBFile(
    String remotePath,
    int? start,
    int? end,
  ) async {
    final result = await _smbService!.readFileBytes(
      remotePath,
      start: start,
      end: end,
    );
    return {
      'data': result['data'],
      'totalSize': result['totalSize'],
    };
  }

  String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    switch (ext) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
        return 'video/x-flv';
      case 'webm':
        return 'video/webm';
      case 'mp3':
        return 'audio/mpeg';
      case 'flac':
        return 'audio/flac';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      default:
        return 'application/octet-stream';
    }
  }
}

class _ProxySession {
  _ProxySession({
    required this.connection,
    required this.remotePath,
  });

  final NetworkConnection connection;
  final String remotePath;

  Future<void> dispose() async {}
}

class _ByteRange {
  const _ByteRange({required this.start, this.end});

  final int start;
  final int? end;

  int resolveEnd(int totalSize, int fallbackChunkSize) {
    if (end != null) {
      return end!.clamp(start, totalSize - 1);
    }
    final target = start + fallbackChunkSize - 1;
    return target.clamp(start, totalSize - 1);
  }
}
