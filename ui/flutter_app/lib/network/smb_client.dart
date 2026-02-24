import 'network_protocol.dart';
import 'smb_platform_channel.dart';

// SMB 客户端 - 使用原生代码实现
class SMBClient implements NetworkClient {
  final NetworkConnection config;
  bool _isConnected = false;

  SMBClient(this.config);

  @override
  bool get isConnected => _isConnected;

  @override
  Future<bool> connect() async {
    try {
      print('[SMBClient] 连接到 ${config.host}/${config.shareName}');
      
      final success = await SmbPlatformChannel.connect(
        host: config.host,
        shareName: config.shareName ?? '',
        username: config.username,
        password: config.password,
        domain: config.workgroup,
      );
      
      _isConnected = success;
      
      if (success) {
        print('[SMBClient] 连接成功');
      } else {
        print('[SMBClient] 连接失败');
      }
      
      return success;
    } catch (e) {
      print('[SMBClient] 连接错误: $e');
      _isConnected = false;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      print('[SMBClient] 断开连接');
      await SmbPlatformChannel.disconnect();
    } catch (e) {
      print('[SMBClient] 断开连接错误: $e');
    } finally {
      _isConnected = false;
    }
  }

  @override
  Future<List<NetworkFile>> listDirectory(String path) async {
    if (!_isConnected) {
      throw Exception('SMB 未连接');
    }

    try {
      print('[SMBClient] 列出目录: $path');
      
      final files = await SmbPlatformChannel.listDirectory(path);
      
      final result = <NetworkFile>[];
      
      for (final file in files) {
        result.add(NetworkFile(
          name: file['name'] as String,
          path: file['path'] as String,
          isDirectory: file['isDirectory'] as bool,
          size: file['size'] as int?,
          modifiedTime: file['modifiedTime'] != null
              ? DateTime.fromMillisecondsSinceEpoch(file['modifiedTime'] as int)
              : null,
          protocol: NetworkProtocol.smb,
        ));
      }
      
      // 排序：文件夹在前，然后按名称排序
      result.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      
      print('[SMBClient] 找到 ${result.length} 个项目');
      return result;
    } catch (e) {
      print('[SMBClient] 列出目录错误: $e');
      rethrow;
    }
  }

  @override
  Future<String> getPlayableUrl(String path) async {
    if (!_isConnected) {
      throw Exception('SMB 未连接');
    }

    try {
      // 通过原生代码获取可播放的 URL
      // 可能是本地代理服务器的 URL
      return await SmbPlatformChannel.getFileUrl(path);
    } catch (e) {
      print('[SMBClient] 获取播放 URL 错误: $e');
      rethrow;
    }
  }
}
