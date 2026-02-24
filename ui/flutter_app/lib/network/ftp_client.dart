import 'dart:io';
import 'package:ftpconnect/ftpconnect.dart';
import 'package:path/path.dart' as path_lib;
import 'network_protocol.dart';

class FTPClient implements NetworkClient {
  final NetworkConnection config;
  FTPConnect? _ftpConnect;
  bool _isConnected = false;

  FTPClient(this.config);

  @override
  bool get isConnected => _isConnected;

  @override
  Future<bool> connect() async {
    try {
      print('[FTPClient] 连接到 ${config.host}:${config.port}');
      
      _ftpConnect = FTPConnect(
        config.host,
        port: config.port,
        user: config.username ?? 'anonymous',
        pass: config.password ?? '',
        timeout: 30,
      );

      final connected = await _ftpConnect!.connect();
      _isConnected = connected;
      
      if (connected) {
        print('[FTPClient] 连接成功');
      } else {
        print('[FTPClient] 连接失败');
      }
      
      return connected;
    } catch (e) {
      print('[FTPClient] 连接错误: $e');
      _isConnected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      if (_ftpConnect != null) {
        await _ftpConnect!.disconnect();
        print('[FTPClient] 已断开连接');
      }
    } catch (e) {
      print('[FTPClient] 断开连接错误: $e');
    } finally {
      _isConnected = false;
      _ftpConnect = null;
    }
  }

  @override
  Future<List<NetworkFile>> listDirectory(String dirPath) async {
    if (!_isConnected || _ftpConnect == null) {
      throw Exception('FTP 未连接');
    }

    try {
      print('[FTPClient] 列出目录: $dirPath');
      
      // 切换到目标目录
      if (dirPath.isNotEmpty && dirPath != '/') {
        await _ftpConnect!.changeDirectory(dirPath);
      }
      
      // 获取目录列表
      final files = await _ftpConnect!.listDirectoryContent();
      
      final result = <NetworkFile>[];
      
      for (final file in files) {
        // 跳过 . 和 ..
        if (file.name == '.' || file.name == '..') continue;
        
        final filePath = path_lib.join(dirPath, file.name);
        
        result.add(NetworkFile(
          name: file.name,
          path: filePath,
          isDirectory: file.type == FTPEntryType.DIR,
          size: file.size,
          modifiedTime: file.modifyTime,
          protocol: NetworkProtocol.ftp,
        ));
      }
      
      // 排序：文件夹在前，然后按名称排序
      result.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      
      print('[FTPClient] 找到 ${result.length} 个项目');
      return result;
    } catch (e) {
      print('[FTPClient] 列出目录错误: $e');
      throw Exception('无法列出目录: $e');
    }
  }

  @override
  Future<String> getPlayableUrl(String filePath) async {
    if (!_isConnected || _ftpConnect == null) {
      throw Exception('FTP 未连接');
    }

    try {
      // 对于 FTP，我们需要下载到临时文件
      // 或者使用本地代理服务器（后续实现）
      
      // 方案1: 返回 FTP URL，让播放器尝试直接播放
      final username = config.username ?? 'anonymous';
      final password = config.password ?? '';
      final auth = username.isNotEmpty ? '$username:$password@' : '';
      
      return 'ftp://$auth${config.host}:${config.port}$filePath';
    } catch (e) {
      print('[FTPClient] 获取播放 URL 错误: $e');
      throw Exception('无法获取播放 URL: $e');
    }
  }

  // 下载文件到临时目录（备用方案）
  Future<String> downloadToTemp(String filePath) async {
    if (!_isConnected || _ftpConnect == null) {
      throw Exception('FTP 未连接');
    }

    try {
      final tempDir = Directory.systemTemp;
      final fileName = path_lib.basename(filePath);
      final localPath = path_lib.join(tempDir.path, 'bova_ftp_$fileName');
      
      print('[FTPClient] 下载文件到: $localPath');
      
      final success = await _ftpConnect!.downloadFile(filePath, File(localPath));
      
      if (success) {
        print('[FTPClient] 下载成功');
        return localPath;
      } else {
        throw Exception('下载失败');
      }
    } catch (e) {
      print('[FTPClient] 下载错误: $e');
      throw Exception('下载文件失败: $e');
    }
  }
}
