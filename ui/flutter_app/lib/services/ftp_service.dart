import 'dart:io';
import 'package:ftpconnect/ftpconnect.dart';
import '../models/network_connection.dart';
import '../models/network_file.dart';

class FTPService {
  FTPConnect? _ftpConnect;
  NetworkConnection? _currentConnection;

  /// 连接到 FTP 服务器
  Future<bool> connect(NetworkConnection connection) async {
    try {
      print('[FTP] 连接到 ${connection.host}:${connection.port}');
      
      _ftpConnect = FTPConnect(
        connection.host,
        port: connection.port,
        user: connection.username,
        pass: connection.password,
        timeout: 30,
      );

      await _ftpConnect!.connect();
      _currentConnection = connection;
      
      print('[FTP] 连接成功');
      return true;
    } catch (e) {
      print('[FTP] 连接失败: $e');
      _ftpConnect = null;
      _currentConnection = null;
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      await _ftpConnect?.disconnect();
    } catch (e) {
      print('[FTP] 断开连接失败: $e');
    }
    _ftpConnect = null;
    _currentConnection = null;
  }

  /// 列出目录内容
  Future<List<NetworkFile>> listDirectory(String path) async {
    if (_ftpConnect == null) {
      throw Exception('未连接到 FTP 服务器');
    }

    try {
      print('[FTP] 列出目录: $path');
      
      // 切换到目标目录
      if (path.isNotEmpty && path != '/') {
        await _ftpConnect!.changeDirectory(path);
      }

      // 获取目录列表
      final List<FTPEntry> entries = await _ftpConnect!.listDirectoryContent();
      
      final files = <NetworkFile>[];
      for (final entry in entries) {
        // 跳过 . 和 ..
        if (entry.name == '.' || entry.name == '..') continue;

        files.add(NetworkFile(
          name: entry.name,
          path: path.endsWith('/') ? '$path${entry.name}' : '$path/${entry.name}',
          isDirectory: entry.type == FTPEntryType.dir,
          size: entry.size ?? 0,
          modified: entry.modifyTime,
        ));
      }

      print('[FTP] 找到 ${files.length} 个文件/目录');
      return files;
    } catch (e) {
      print('[FTP] 列出目录失败: $e');
      rethrow;
    }
  }

  /// 下载文件到本地
  Future<String> downloadFile(String remotePath, String localPath) async {
    if (_ftpConnect == null) {
      throw Exception('未连接到 FTP 服务器');
    }

    try {
      print('[FTP] 下载文件: $remotePath -> $localPath');
      await _ftpConnect!.downloadFileWithRetry(remotePath, File(localPath));
      return localPath;
    } catch (e) {
      print('[FTP] 下载文件失败: $e');
      rethrow;
    }
  }

  /// 读取文件内容（用于代理服务器）
  Future<List<int>> readFileBytes(String remotePath, {int? start, int? end}) async {
    if (_ftpConnect == null) {
      throw Exception('未连接到 FTP 服务器');
    }

    try {
      // FTP 不直接支持 Range 请求，需要下载整个文件
      // 这里先实现简单版本，后续可以优化
      print('[FTP] 读取文件: $remotePath');
      
      // 使用临时文件
      final tempPath = '/tmp/${DateTime.now().millisecondsSinceEpoch}_${remotePath.split('/').last}';
      await _ftpConnect!.downloadFileWithRetry(remotePath, File(tempPath));
      
      // 读取文件内容
      final file = File(tempPath);
      final bytes = await file.readAsBytes();
      
      // 删除临时文件
      await file.delete();
      
      // 如果指定了范围，返回部分内容
      if (start != null || end != null) {
        final startIndex = start ?? 0;
        final endIndex = end ?? bytes.length;
        return bytes.sublist(startIndex, endIndex);
      }
      
      return bytes;
    } catch (e) {
      print('[FTP] 读取文件失败: $e');
      rethrow;
    }
  }

  /// 测试连接
  static Future<bool> testConnection(NetworkConnection connection) async {
    final service = FTPService();
    try {
      final result = await service.connect(connection);
      await service.disconnect();
      return result;
    } catch (e) {
      return false;
    }
  }

  bool get isConnected => _ftpConnect != null;
  NetworkConnection? get currentConnection => _currentConnection;
}
