import 'dart:io';
import 'package:flutter/services.dart';
import '../models/network_connection.dart';
import '../models/network_file.dart';

class SMBService {
  static const MethodChannel _channel = MethodChannel('com.bovaplayer/smb');
  
  NetworkConnection? _currentConnection;
  String? _mountPoint; // macOS/Linux 挂载点

  /// 连接到 SMB 服务器
  Future<bool> connect(NetworkConnection connection) async {
    try {
      print('[SMB] 连接到 ${connection.host}');
      
      if (Platform.isWindows) {
        return await _connectWindows(connection);
      } else if (Platform.isMacOS || Platform.isLinux) {
        return await _connectUnix(connection);
      } else if (Platform.isAndroid) {
        return await _connectAndroid(connection);
      }
      
      return false;
    } catch (e) {
      print('[SMB] 连接失败: $e');
      return false;
    }
  }

  /// Windows SMB 连接（使用 UNC 路径）
  Future<bool> _connectWindows(NetworkConnection connection) async {
    try {
      // 构建 UNC 路径
      final uncPath = '\\\\${connection.host}\\${connection.shareName ?? 'share'}';
      
      // 使用 net use 命令连接
      final result = await Process.run('net', [
        'use',
        uncPath,
        '/user:${connection.username}',
        connection.password,
      ]);

      if (result.exitCode == 0) {
        _currentConnection = connection;
        _mountPoint = uncPath;
        print('[SMB] Windows 连接成功: $uncPath');
        return true;
      } else {
        print('[SMB] Windows 连接失败: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('[SMB] Windows 连接异常: $e');
      return false;
    }
  }

  /// macOS/Linux SMB 连接（使用 mount）
  Future<bool> _connectUnix(NetworkConnection connection) async {
    try {
      // 创建临时挂载点
      final mountDir = Directory('/tmp/smb_${DateTime.now().millisecondsSinceEpoch}');
      await mountDir.create();
      
      // 构建 SMB URL
      final smbUrl = 'smb://${connection.username}:${connection.password}@${connection.host}/${connection.shareName ?? 'share'}';
      
      ProcessResult result;
      if (Platform.isMacOS) {
        // macOS 使用 mount_smbfs
        result = await Process.run('mount_smbfs', [
          smbUrl,
          mountDir.path,
        ]);
      } else {
        // Linux 使用 mount -t cifs
        result = await Process.run('mount', [
          '-t',
          'cifs',
          '//${connection.host}/${connection.shareName ?? 'share'}',
          mountDir.path,
          '-o',
          'username=${connection.username},password=${connection.password}',
        ]);
      }

      if (result.exitCode == 0) {
        _currentConnection = connection;
        _mountPoint = mountDir.path;
        print('[SMB] Unix 连接成功: ${mountDir.path}');
        return true;
      } else {
        print('[SMB] Unix 连接失败: ${result.stderr}');
        await mountDir.delete();
        return false;
      }
    } catch (e) {
      print('[SMB] Unix 连接异常: $e');
      return false;
    }
  }

  /// Android SMB 连接（使用 Platform Channel）
  Future<bool> _connectAndroid(NetworkConnection connection) async {
    try {
      final result = await _channel.invokeMethod('connect', {
        'host': connection.host,
        'port': connection.port,
        'username': connection.username,
        'password': connection.password,
        'shareName': connection.shareName ?? 'share',
        'workgroup': connection.workgroup ?? 'WORKGROUP',
      });

      if (result == true) {
        _currentConnection = connection;
        print('[SMB] Android 连接成功');
        return true;
      }
      return false;
    } catch (e) {
      print('[SMB] Android 连接失败: $e');
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    try {
      if (Platform.isWindows && _mountPoint != null) {
        await Process.run('net', ['use', _mountPoint!, '/delete']);
      } else if ((Platform.isMacOS || Platform.isLinux) && _mountPoint != null) {
        await Process.run('umount', [_mountPoint!]);
        await Directory(_mountPoint!).delete();
      } else if (Platform.isAndroid) {
        await _channel.invokeMethod('disconnect');
      }
    } catch (e) {
      print('[SMB] 断开连接失败: $e');
    }
    
    _currentConnection = null;
    _mountPoint = null;
  }

  /// 列出目录内容
  Future<List<NetworkFile>> listDirectory(String path) async {
    if (_currentConnection == null) {
      throw Exception('未连接到 SMB 服务器');
    }

    try {
      if (Platform.isAndroid) {
        return await _listDirectoryAndroid(path);
      } else {
        return await _listDirectoryNative(path);
      }
    } catch (e) {
      print('[SMB] 列出目录失败: $e');
      rethrow;
    }
  }

  /// 原生平台列出目录
  Future<List<NetworkFile>> _listDirectoryNative(String path) async {
    final fullPath = '$_mountPoint$path';
    final dir = Directory(fullPath);
    
    final files = <NetworkFile>[];
    await for (final entity in dir.list()) {
      final stat = await entity.stat();
      final name = entity.path.split(Platform.pathSeparator).last;
      
      files.add(NetworkFile(
        name: name,
        path: '$path/$name',
        isDirectory: entity is Directory,
        size: stat.size,
        modified: stat.modified,
      ));
    }

    return files;
  }

  /// Android 列出目录
  Future<List<NetworkFile>> _listDirectoryAndroid(String path) async {
    final result = await _channel.invokeMethod('listDirectory', {'path': path});
    final List<dynamic> items = result as List<dynamic>;
    
    return items.map((item) {
      final map = item as Map<dynamic, dynamic>;
      return NetworkFile(
        name: map['name'] as String,
        path: map['path'] as String,
        isDirectory: map['isDirectory'] as bool,
        size: map['size'] as int? ?? 0,
        modified: map['modified'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(map['modified'] as int)
            : null,
      );
    }).toList();
  }

  /// 读取文件字节（支持 Range）
  Future<Map<String, dynamic>> readFileBytes(String remotePath, {int? start, int? end}) async {
    if (_currentConnection == null) {
      throw Exception('未连接到 SMB 服务器');
    }

    try {
      if (Platform.isAndroid) {
        return await _readFileBytesAndroid(remotePath, start, end);
      } else {
        return await _readFileBytesNative(remotePath, start, end);
      }
    } catch (e) {
      print('[SMB] 读取文件失败: $e');
      rethrow;
    }
  }

  /// 原生平台读取文件
  Future<Map<String, dynamic>> _readFileBytesNative(String remotePath, int? start, int? end) async {
    final fullPath = '$_mountPoint$remotePath';
    final file = File(fullPath);
    
    final totalSize = await file.length();
    final fileHandle = await file.open();
    
    if (start != null) {
      await fileHandle.setPosition(start);
    }
    
    final length = end != null ? (end - (start ?? 0) + 1) : null;
    final data = await fileHandle.read(length ?? totalSize);
    await fileHandle.close();

    return {
      'data': data,
      'totalSize': totalSize,
    };
  }

  /// Android 读取文件
  Future<Map<String, dynamic>> _readFileBytesAndroid(String remotePath, int? start, int? end) async {
    final result = await _channel.invokeMethod('readFile', {
      'path': remotePath,
      'start': start,
      'end': end,
    });

    return {
      'data': result['data'] as List<int>,
      'totalSize': result['totalSize'] as int,
    };
  }

  /// 测试连接
  static Future<bool> testConnection(NetworkConnection connection) async {
    final service = SMBService();
    try {
      final result = await service.connect(connection);
      await service.disconnect();
      return result;
    } catch (e) {
      return false;
    }
  }

  bool get isConnected => _currentConnection != null;
  NetworkConnection? get currentConnection => _currentConnection;
}
