import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../models/network_connection.dart';
import 'ftp_service.dart';
import 'smb_service.dart';

class LocalProxyServer {
  HttpServer? _server;
  int _port = 8080;
  final Map<String, _ProxySession> _sessions = {};
  
  FTPService? _ftpService;
  SMBService? _smbService;

  bool get isRunning => _server != null;
  int get port => _port;

  /// 启动代理服务器
  Future<void> start({int port = 8080}) async {
    if (_server != null) {
      print('[ProxyServer] 服务器已在运行');
      return;
    }

    _port = port;
    
    try {
      final router = Router();
      
      // 代理路由
      router.get('/proxy/<sessionId>', _handleProxyRequest);
      
      // 健康检查
      router.get('/health', (Request request) {
        return Response.ok('OK');
      });

      final handler = Pipeline()
          .addMiddleware(logRequests())
          .addHandler(router);

      _server = await shelf_io.serve(handler, 'localhost', _port);
      print('[ProxyServer] 代理服务器启动成功: http://localhost:$_port');
    } catch (e) {
      print('[ProxyServer] 启动失败: $e');
      rethrow;
    }
  }

  /// 停止代理服务器
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    
    // 清理所有会话
    for (final session in _sessions.values) {
      await session.dispose();
    }
    _sessions.clear();
    
    print('[ProxyServer] 代理服务器已停止');
  }

  /// 创建代理 URL
  String createProxyUrl(NetworkConnection connection, String remotePath) {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    _sessions[sessionId] = _ProxySession(
      connection: connection,
      remotePath: remotePath,
    );

    return 'http://localhost:$_port/proxy/$sessionId';
  }

  /// 处理代理请求
  Future<Response> _handleProxyRequest(Request request, String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return Response.notFound('Session not found');
    }

    try {
      // 解析 Range 请求
      final rangeHeader = request.headers['range'];
      int? start;
      int? end;
      
      if (rangeHeader != null) {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (match != null) {
          start = int.parse(match.group(1)!);
          final endStr = match.group(2);
          end = endStr != null && endStr.isNotEmpty ? int.parse(endStr) : null;
        }
      }

      // 根据协议读取数据
      List<int> data;
      int totalSize;

      if (session.connection.protocol == NetworkProtocol.ftp) {
        _ftpService ??= FTPService();
        if (!_ftpService!.isConnected) {
          await _ftpService!.connect(session.connection);
        }
        
        final result = await _readFTPFile(session.remotePath, start, end);
        data = result['data'] as List<int>;
        totalSize = result['totalSize'] as int;
      } else if (session.connection.protocol == NetworkProtocol.smb) {
        _smbService ??= SMBService();
        if (!_smbService!.isConnected) {
          await _smbService!.connect(session.connection);
        }
        
        final result = await _readSMBFile(session.remotePath, start, end);
        data = result['data'] as List<int>;
        totalSize = result['totalSize'] as int;
      } else {
        return Response.internalServerError(body: 'Unsupported protocol');
      }

      // 构建响应
      final headers = <String, String>{
        'Content-Type': _getMimeType(session.remotePath),
        'Accept-Ranges': 'bytes',
        'Access-Control-Allow-Origin': '*',
      };

      if (start != null) {
        // 部分内容响应
        final actualEnd = end ?? (totalSize - 1);
        headers['Content-Range'] = 'bytes $start-$actualEnd/$totalSize';
        headers['Content-Length'] = data.length.toString();
        
        return Response(206, body: Stream.value(data), headers: headers);
      } else {
        // 完整内容响应
        headers['Content-Length'] = data.length.toString();
        return Response.ok(Stream.value(data), headers: headers);
      }
    } catch (e) {
      print('[ProxyServer] 处理请求失败: $e');
      return Response.internalServerError(body: 'Error: $e');
    }
  }

  /// 读取 FTP 文件
  Future<Map<String, dynamic>> _readFTPFile(String remotePath, int? start, int? end) async {
    // 先获取文件大小
    // TODO: 实现获取文件大小的方法
    final totalSize = 1000000000; // 临时值

    // 下载文件到临时位置
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_${remotePath.split('/').last}');
    
    await _ftpService!.downloadFile(remotePath, tempFile.path);
    
    // 读取指定范围
    final file = await tempFile.open();
    if (start != null) {
      await file.setPosition(start);
    }
    
    final length = end != null ? (end - (start ?? 0) + 1) : null;
    final data = await file.read(length ?? totalSize);
    await file.close();
    
    // 清理临时文件
    await tempFile.delete();

    return {
      'data': data,
      'totalSize': totalSize,
    };
  }

  /// 读取 SMB 文件
  Future<Map<String, dynamic>> _readSMBFile(String remotePath, int? start, int? end) async {
    final result = await _smbService!.readFileBytes(remotePath, start: start, end: end);
    return {
      'data': result['data'],
      'totalSize': result['totalSize'],
    };
  }

  /// 获取 MIME 类型
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
      case 'ts':
      case 'm2ts':
        return 'video/mp2t';
      case 'mp3':
        return 'audio/mpeg';
      case 'flac':
        return 'audio/flac';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  /// 清理会话
  void cleanupSession(String sessionId) {
    final session = _sessions.remove(sessionId);
    session?.dispose();
  }
}

class _ProxySession {
  final NetworkConnection connection;
  final String remotePath;
  final DateTime createdAt;

  _ProxySession({
    required this.connection,
    required this.remotePath,
  }) : createdAt = DateTime.now();

  Future<void> dispose() async {
    // 清理资源
  }
}
