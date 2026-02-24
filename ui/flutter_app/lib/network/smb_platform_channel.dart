import 'package:flutter/services.dart';
import 'dart:convert';

class SmbPlatformChannel {
  static const MethodChannel _channel = MethodChannel('com.bova.player/smb');

  // 连接到 SMB 服务器
  static Future<bool> connect({
    required String host,
    required String shareName,
    String? username,
    String? password,
    String? domain,
  }) async {
    try {
      final result = await _channel.invokeMethod('connect', {
        'host': host,
        'shareName': shareName,
        'username': username ?? 'guest',
        'password': password ?? '',
        'domain': domain ?? '',
      });
      return result == true;
    } catch (e) {
      print('[SmbPlatformChannel] 连接错误: $e');
      return false;
    }
  }

  // 断开连接
  static Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (e) {
      print('[SmbPlatformChannel] 断开连接错误: $e');
    }
  }

  // 列出目录
  static Future<List<Map<String, dynamic>>> listDirectory(String path) async {
    try {
      final result = await _channel.invokeMethod('listDirectory', {
        'path': path,
      });
      
      if (result is String) {
        final List<dynamic> jsonList = jsonDecode(result);
        return jsonList.cast<Map<String, dynamic>>();
      }
      
      return [];
    } catch (e) {
      print('[SmbPlatformChannel] 列出目录错误: $e');
      rethrow;
    }
  }

  // 获取文件 URL（用于播放）
  static Future<String> getFileUrl(String path) async {
    try {
      final result = await _channel.invokeMethod('getFileUrl', {
        'path': path,
      });
      return result as String;
    } catch (e) {
      print('[SmbPlatformChannel] 获取文件 URL 错误: $e');
      rethrow;
    }
  }

  // 检查是否已连接
  static Future<bool> isConnected() async {
    try {
      final result = await _channel.invokeMethod('isConnected');
      return result == true;
    } catch (e) {
      print('[SmbPlatformChannel] 检查连接状态错误: $e');
      return false;
    }
  }
}
