import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/network_connection.dart';

class ConnectionManager {
  static const String _connectionsKey = 'network_connections';
  static const String _passwordPrefix = 'password_';
  
  final _secureStorage = const FlutterSecureStorage();
  final _uuid = const Uuid();

  /// 获取所有连接
  Future<List<NetworkConnection>> getConnections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_connectionsKey);
      
      if (data == null) return [];

      final List<dynamic> jsonList = jsonDecode(data);
      final connections = <NetworkConnection>[];

      for (final json in jsonList) {
        final connection = NetworkConnection.fromJson(json as Map<String, dynamic>);
        
        // 如果保存了密码，从安全存储中读取
        if (connection.savePassword) {
          final password = await _secureStorage.read(key: '$_passwordPrefix${connection.id}');
          connections.add(connection.copyWith(password: password ?? ''));
        } else {
          connections.add(connection);
        }
      }

      return connections;
    } catch (e) {
      print('[ConnectionManager] 加载连接失败: $e');
      return [];
    }
  }

  /// 保存连接
  Future<void> saveConnection(NetworkConnection connection) async {
    try {
      final connections = await getConnections();
      
      // 检查是否已存在
      final index = connections.indexWhere((c) => c.id == connection.id);
      if (index >= 0) {
        connections[index] = connection;
      } else {
        connections.add(connection);
      }

      // 保存密码到安全存储
      if (connection.savePassword && connection.password.isNotEmpty) {
        await _secureStorage.write(
          key: '$_passwordPrefix${connection.id}',
          value: connection.password,
        );
      }

      // 保存连接列表（不包含密码）
      final prefs = await SharedPreferences.getInstance();
      final jsonList = connections.map((c) => c.toJson()).toList();
      await prefs.setString(_connectionsKey, jsonEncode(jsonList));

      print('[ConnectionManager] 保存连接成功: ${connection.name}');
    } catch (e) {
      print('[ConnectionManager] 保存连接失败: $e');
      rethrow;
    }
  }

  /// 删除连接
  Future<void> deleteConnection(String id) async {
    try {
      final connections = await getConnections();
      connections.removeWhere((c) => c.id == id);

      // 删除密码
      await _secureStorage.delete(key: '$_passwordPrefix$id');

      // 保存更新后的列表
      final prefs = await SharedPreferences.getInstance();
      final jsonList = connections.map((c) => c.toJson()).toList();
      await prefs.setString(_connectionsKey, jsonEncode(jsonList));

      print('[ConnectionManager] 删除连接成功: $id');
    } catch (e) {
      print('[ConnectionManager] 删除连接失败: $e');
      rethrow;
    }
  }

  /// 更新最后连接时间
  Future<void> updateLastConnected(String id) async {
    try {
      final connections = await getConnections();
      final index = connections.indexWhere((c) => c.id == id);
      
      if (index >= 0) {
        connections[index] = connections[index].copyWith(
          lastConnected: DateTime.now(),
        );
        
        final prefs = await SharedPreferences.getInstance();
        final jsonList = connections.map((c) => c.toJson()).toList();
        await prefs.setString(_connectionsKey, jsonEncode(jsonList));
      }
    } catch (e) {
      print('[ConnectionManager] 更新连接时间失败: $e');
    }
  }

  /// 生成新的连接 ID
  String generateId() => _uuid.v4();

  /// 获取最近使用的连接
  Future<List<NetworkConnection>> getRecentConnections({int limit = 5}) async {
    final connections = await getConnections();
    connections.sort((a, b) => b.lastConnected.compareTo(a.lastConnected));
    return connections.take(limit).toList();
  }
}
