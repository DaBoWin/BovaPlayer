import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/network_connection.dart';
import '../../../services/connection_manager.dart';
import '../models/media_source.dart';

class MediaLibrarySourceService {
  final ConnectionManager _connectionManager;

  MediaLibrarySourceService({ConnectionManager? connectionManager})
      : _connectionManager = connectionManager ?? ConnectionManager();

  Future<List<MediaSource>> loadSources() async {
    final embySources = await _loadEmbySourcesFromPrefs();
    final connections = await _connectionManager.getConnections();
    final networkSources = connections
        .map(MediaSource.fromNetworkConnection)
        .toList(growable: false);
    return [...embySources, ...networkSources];
  }

  Future<MediaSource> saveEmbySource({
    MediaSource? existingSource,
    required String name,
    required String url,
    required String username,
    required String password,
  }) async {
    final loginResult = await _loginToEmby(url, username, password);
    if (loginResult == null) {
      throw Exception('登录失败，请检查服务器地址和凭据');
    }

    final updatedSource = MediaSource(
      id: existingSource?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: SourceType.emby,
      url: url,
      username: username,
      password: password,
      accessToken: loginResult['accessToken']?.toString(),
      userId: loginResult['userId']?.toString(),
    );

    final embySources = await _loadEmbySourcesFromPrefs();
    final index = embySources.indexWhere((item) => item.id == updatedSource.id);
    if (index >= 0) {
      embySources[index] = updatedSource;
    } else {
      embySources.add(updatedSource);
    }
    await _persistEmbySources(embySources);
    return updatedSource;
  }

  Future<MediaSource> refreshEmbySession(MediaSource source) async {
    if (source.type != SourceType.emby) {
      return source;
    }

    final loginResult =
        await _loginToEmby(source.url, source.username, source.password);
    if (loginResult == null) {
      throw Exception('登录失败，请检查服务器地址和凭据');
    }

    final updatedSource = MediaSource(
      id: source.id,
      name: source.name,
      type: source.type,
      url: source.url,
      username: source.username,
      password: source.password,
      accessToken: loginResult['accessToken']?.toString(),
      userId: loginResult['userId']?.toString(),
    );

    final embySources = await _loadEmbySourcesFromPrefs();
    final index = embySources.indexWhere((item) => item.id == updatedSource.id);
    if (index >= 0) {
      embySources[index] = updatedSource;
      await _persistEmbySources(embySources);
    }

    return updatedSource;
  }

  Future<MediaSource> saveNetworkSource({
    MediaSource? existingSource,
    required SourceType type,
    required String name,
    required String host,
    required int port,
    required String username,
    required String password,
    required String shareName,
    required String workgroup,
    required bool savePassword,
  }) async {
    final connection = NetworkConnection(
      id: existingSource?.id ?? _connectionManager.generateId(),
      protocol:
          type == SourceType.smb ? NetworkProtocol.smb : NetworkProtocol.ftp,
      name: name,
      host: host,
      port: port,
      username: username,
      password: savePassword ? password : '',
      shareName: type == SourceType.smb ? shareName : null,
      workgroup: type == SourceType.smb ? workgroup : null,
      lastConnected: DateTime.now(),
      savePassword: savePassword,
    );

    await _connectionManager.saveConnection(connection);
    return MediaSource.fromNetworkConnection(connection);
  }

  Future<void> deleteSource(MediaSource source) async {
    if (source.type == SourceType.emby) {
      final embySources = await _loadEmbySourcesFromPrefs();
      embySources.removeWhere((item) => item.id == source.id);
      await _persistEmbySources(embySources);
      return;
    }

    await _connectionManager.deleteConnection(source.id);
  }

  Future<void> updateLastConnected(String id) async {
    await _connectionManager.updateLastConnected(id);
  }

  Future<List<MediaSource>> _loadEmbySourcesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final embyJson = prefs.getString('emby_servers');
    if (embyJson == null) {
      return [];
    }

    final List<dynamic> rawList = jsonDecode(embyJson);
    return rawList
        .whereType<Map>()
        .map(
          (item) => MediaSource.fromJson({
            ...item.cast<String, dynamic>(),
            'id': item['id'] ?? item['name'],
            'type': SourceType.emby.toString(),
          }),
        )
        .toList(growable: true);
  }

  Future<void> _persistEmbySources(List<MediaSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'emby_servers',
      jsonEncode(
        sources
            .map(
              (source) => {
                'id': source.id,
                'name': source.name,
                'url': source.url,
                'username': source.username,
                'password': source.password,
                'accessToken': source.accessToken,
                'userId': source.userId,
              },
            )
            .toList(),
      ),
    );
  }

  Future<Map<String, dynamic>?> _loginToEmby(
    String url,
    String username,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$url/Users/AuthenticateByName'),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Authorization':
              'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="flutter-app", Version="1.0.0"',
        },
        body: jsonEncode({'Username': username, 'Pw': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'accessToken': data['AccessToken'],
          'userId': (data['User'] as Map<String, dynamic>)['Id'],
        };
      }
    } catch (error) {
      return null;
    }
    return null;
  }
}
