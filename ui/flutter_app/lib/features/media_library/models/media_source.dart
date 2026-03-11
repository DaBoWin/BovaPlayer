import '../../../models/network_connection.dart';

enum SourceType { emby, smb, ftp }

class MediaSource {
  final String id;
  final String name;
  final SourceType type;
  final String url;
  final String username;
  final String password;
  final String? shareName;
  final String? workgroup;
  final String? accessToken;
  final String? userId;

  const MediaSource({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.username,
    this.password = '',
    this.shareName,
    this.workgroup,
    this.accessToken,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.toString(),
        'url': url,
        'username': username,
        'password': password,
        'shareName': shareName,
        'workgroup': workgroup,
        'accessToken': accessToken,
        'userId': userId,
      };

  factory MediaSource.fromJson(Map<String, dynamic> json) => MediaSource(
        id: json['id']?.toString() ?? json['name']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        type: SourceType.values.firstWhere(
          (item) => item.toString() == json['type'],
          orElse: () => SourceType.emby,
        ),
        url: json['url']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        password: json['password']?.toString() ?? '',
        shareName: json['shareName']?.toString(),
        workgroup: json['workgroup']?.toString(),
        accessToken: json['accessToken']?.toString(),
        userId: json['userId']?.toString(),
      );

  factory MediaSource.fromNetworkConnection(NetworkConnection connection) {
    return MediaSource(
      id: connection.id,
      name: connection.name,
      type: connection.protocol == NetworkProtocol.smb
          ? SourceType.smb
          : SourceType.ftp,
      url:
          '${connection.protocol.name}://${connection.host}:${connection.port}',
      username: connection.username,
      password: connection.password,
      shareName: connection.shareName,
      workgroup: connection.workgroup,
    );
  }

  NetworkConnection toNetworkConnection({DateTime? lastConnected}) {
    final uri = Uri.parse(url);
    return NetworkConnection(
      id: id,
      protocol:
          type == SourceType.smb ? NetworkProtocol.smb : NetworkProtocol.ftp,
      name: name,
      host: uri.host,
      port: uri.port,
      username: username,
      password: password,
      shareName: shareName,
      workgroup: workgroup,
      lastConnected: lastConnected ?? DateTime.now(),
      savePassword: password.isNotEmpty,
    );
  }
}
