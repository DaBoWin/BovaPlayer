/// 网络连接协议类型
enum NetworkProtocol {
  smb,
  ftp,
}

/// 网络连接配置
class NetworkConnection {
  final String id;
  final NetworkProtocol protocol;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String? shareName; // SMB only
  final String? workgroup; // SMB only
  final DateTime lastConnected;
  final bool savePassword;

  NetworkConnection({
    required this.id,
    required this.protocol,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.shareName,
    this.workgroup,
    required this.lastConnected,
    this.savePassword = true,
  });

  factory NetworkConnection.fromJson(Map<String, dynamic> json) {
    return NetworkConnection(
      id: json['id'] as String,
      protocol: NetworkProtocol.values.firstWhere(
        (e) => e.toString() == json['protocol'],
      ),
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      username: json['username'] as String,
      password: json['password'] as String? ?? '',
      shareName: json['shareName'] as String?,
      workgroup: json['workgroup'] as String?,
      lastConnected: DateTime.parse(json['lastConnected'] as String),
      savePassword: json['savePassword'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'protocol': protocol.toString(),
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': savePassword ? password : '',
      'shareName': shareName,
      'workgroup': workgroup,
      'lastConnected': lastConnected.toIso8601String(),
      'savePassword': savePassword,
    };
  }

  NetworkConnection copyWith({
    String? id,
    NetworkProtocol? protocol,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? shareName,
    String? workgroup,
    DateTime? lastConnected,
    bool? savePassword,
  }) {
    return NetworkConnection(
      id: id ?? this.id,
      protocol: protocol ?? this.protocol,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      shareName: shareName ?? this.shareName,
      workgroup: workgroup ?? this.workgroup,
      lastConnected: lastConnected ?? this.lastConnected,
      savePassword: savePassword ?? this.savePassword,
    );
  }

  String get displayName => name.isNotEmpty ? name : '$host:$port';
  
  String get protocolName {
    switch (protocol) {
      case NetworkProtocol.smb:
        return 'SMB';
      case NetworkProtocol.ftp:
        return 'FTP';
    }
  }
}
