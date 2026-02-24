// 网络协议枚举
enum NetworkProtocol {
  local,    // 本地文件
  smb,      // SMB/CIFS
  ftp,      // FTP/FTPS
  http,     // HTTP/HTTPS
}

// 网络文件信息
class NetworkFile {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedTime;
  final NetworkProtocol protocol;

  NetworkFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modifiedTime,
    required this.protocol,
  });

  String get displaySize {
    if (size == null) return '';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    if (size! < 1024 * 1024 * 1024) {
      return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  bool get isVideoFile {
    final ext = name.toLowerCase().split('.').last;
    return ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'm4v', 'webm', 'ts', 'm3u8']
        .contains(ext);
  }
}

// 网络连接配置
class NetworkConnection {
  final NetworkProtocol protocol;
  final String host;
  final int port;
  final String? username;
  final String? password;
  final String? shareName; // SMB 共享名
  final String? workgroup; // SMB 工作组
  final bool passive; // FTP 被动模式
  final bool secure; // FTPS

  NetworkConnection({
    required this.protocol,
    required this.host,
    required this.port,
    this.username,
    this.password,
    this.shareName,
    this.workgroup,
    this.passive = true,
    this.secure = false,
  });

  String get displayName {
    switch (protocol) {
      case NetworkProtocol.smb:
        return 'smb://$host${shareName != null ? '/$shareName' : ''}';
      case NetworkProtocol.ftp:
        return '${secure ? 'ftps' : 'ftp'}://$host:$port';
      case NetworkProtocol.http:
        return 'http://$host:$port';
      default:
        return host;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol.name,
      'host': host,
      'port': port,
      'username': username,
      'shareName': shareName,
      'workgroup': workgroup,
      'passive': passive,
      'secure': secure,
    };
  }

  factory NetworkConnection.fromJson(Map<String, dynamic> json) {
    return NetworkConnection(
      protocol: NetworkProtocol.values.firstWhere(
        (e) => e.name == json['protocol'],
        orElse: () => NetworkProtocol.ftp,
      ),
      host: json['host'],
      port: json['port'],
      username: json['username'],
      shareName: json['shareName'],
      workgroup: json['workgroup'],
      passive: json['passive'] ?? true,
      secure: json['secure'] ?? false,
    );
  }
}

// 网络客户端抽象接口
abstract class NetworkClient {
  Future<bool> connect();
  Future<void> disconnect();
  Future<List<NetworkFile>> listDirectory(String path);
  Future<String> getPlayableUrl(String path);
  bool get isConnected;
}
