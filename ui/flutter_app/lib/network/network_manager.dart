import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_protocol.dart';
import 'ftp_client.dart';
import 'smb_client.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;
  NetworkManager._internal();

  NetworkClient? _currentClient;
  NetworkConnection? _currentConnection;

  NetworkClient? get currentClient => _currentClient;
  NetworkConnection? get currentConnection => _currentConnection;
  bool get isConnected => _currentClient?.isConnected ?? false;

  // 创建网络客户端
  NetworkClient createClient(NetworkConnection connection) {
    switch (connection.protocol) {
      case NetworkProtocol.ftp:
        return FTPClient(connection);
      case NetworkProtocol.smb:
        return SMBClient(connection);
      default:
        throw Exception('不支持的协议: ${connection.protocol}');
    }
  }

  // 连接到网络
  Future<bool> connect(NetworkConnection connection) async {
    try {
      // 断开现有连接
      await disconnect();

      print('[NetworkManager] 连接到 ${connection.displayName}');
      
      _currentClient = createClient(connection);
      final success = await _currentClient!.connect();
      
      if (success) {
        _currentConnection = connection;
        // 保存到历史记录
        await _saveToHistory(connection);
        print('[NetworkManager] 连接成功');
      } else {
        _currentClient = null;
        print('[NetworkManager] 连接失败');
      }
      
      return success;
    } catch (e) {
      print('[NetworkManager] 连接错误: $e');
      _currentClient = null;
      _currentConnection = null;
      rethrow;
    }
  }

  // 断开连接
  Future<void> disconnect() async {
    if (_currentClient != null) {
      try {
        await _currentClient!.disconnect();
      } catch (e) {
        print('[NetworkManager] 断开连接错误: $e');
      }
      _currentClient = null;
      _currentConnection = null;
    }
  }

  // 列出目录
  Future<List<NetworkFile>> listDirectory(String path) async {
    if (_currentClient == null || !isConnected) {
      throw Exception('未连接到网络');
    }
    return await _currentClient!.listDirectory(path);
  }

  // 获取可播放的 URL
  Future<String> getPlayableUrl(String path) async {
    if (_currentClient == null || !isConnected) {
      throw Exception('未连接到网络');
    }
    return await _currentClient!.getPlayableUrl(path);
  }

  // 保存连接历史
  Future<void> _saveToHistory(NetworkConnection connection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getConnectionHistory();
      
      // 移除重复项
      history.removeWhere((c) => 
        c.protocol == connection.protocol && 
        c.host == connection.host &&
        c.port == connection.port
      );
      
      // 添加到开头
      history.insert(0, connection);
      
      // 只保留最近 10 个
      if (history.length > 10) {
        history.removeRange(10, history.length);
      }
      
      // 保存（不包含密码）
      final jsonList = history.map((c) {
        final json = c.toJson();
        json.remove('password'); // 不保存密码
        return json;
      }).toList();
      
      await prefs.setString('network_history', jsonEncode(jsonList));
      print('[NetworkManager] 已保存连接历史');
    } catch (e) {
      print('[NetworkManager] 保存历史错误: $e');
    }
  }

  // 获取连接历史
  Future<List<NetworkConnection>> getConnectionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('network_history');
      
      if (jsonStr == null) return [];
      
      final jsonList = jsonDecode(jsonStr) as List;
      return jsonList
          .map((json) => NetworkConnection.fromJson(json))
          .toList();
    } catch (e) {
      print('[NetworkManager] 读取历史错误: $e');
      return [];
    }
  }

  // 清除连接历史
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('network_history');
      print('[NetworkManager] 已清除连接历史');
    } catch (e) {
      print('[NetworkManager] 清除历史错误: $e');
    }
  }
}
