import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/network_file.dart';
import '../../../services/ftp_service.dart';
import '../../../services/local_proxy_server.dart';
import '../../../services/smb_service.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../models/media_source.dart';
import '../services/media_library_source_service.dart';

class MediaLibraryController extends ChangeNotifier {
  final MediaLibrarySourceService _sourceService;
  final LocalProxyServer _proxyServer;

  MediaLibraryController({
    MediaLibrarySourceService? sourceService,
    LocalProxyServer? proxyServer,
  })  : _sourceService = sourceService ?? MediaLibrarySourceService(),
        _proxyServer = proxyServer ?? LocalProxyServer();

  List<MediaSource> _sources = [];
  MediaSource? _activeSource;
  List<NetworkFile> _currentItems = [];
  String _currentPath = '/';
  bool _isLoading = false;
  String? _errorMessage;

  FTPService? _ftpService;
  SMBService? _smbService;

  List<MediaSource> get sources => _sources;
  MediaSource? get activeSource => _activeSource;
  List<NetworkFile> get currentItems => _currentItems;
  String get currentPath => _currentPath;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    await _proxyServer.start();
    await loadSources();
  }

  Future<void> disposeController() async {
    await _proxyServer.stop();
    await _disconnectClients();
  }

  Future<void> loadSources() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sources = await _sourceService.loadSources();
      _isLoading = false;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('[MediaLibrary] 加载失败: $error');
      debugPrint('[MediaLibrary] 堆栈: $stackTrace');
      _errorMessage = '加载失败: $error';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> connectToSource(MediaSource source) async {
    if (source.type == SourceType.emby) {
      return;
    }

    await _disconnectClients();
    _activeSource = source;
    _currentItems = [];
    _currentPath = '/';
    _errorMessage = null;
    _isLoading = true;
    notifyListeners();

    try {
      if (source.type == SourceType.ftp) {
        _ftpService = FTPService();
        final success = await _ftpService!.connect(
          source.toNetworkConnection(lastConnected: DateTime.now()),
        );
        if (!success) {
          throw Exception('连接失败');
        }
      } else if (source.type == SourceType.smb) {
        _smbService = SMBService();
        final success = await _smbService!.connect(
          source.toNetworkConnection(lastConnected: DateTime.now()),
        );
        if (!success) {
          throw Exception('连接失败');
        }
      }

      await _sourceService.updateLastConnected(source.id);
      final files = await _fetchDirectory('/');
      _currentItems = files;
      _currentPath = '/';
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _activeSource = null;
      _currentItems = [];
      _currentPath = '/';
      _isLoading = false;
      notifyListeners();
      throw Exception('连接失败: $error');
    }
  }

  void leaveFileBrowser() {
    unawaited(_disconnectClients());
    _activeSource = null;
    _currentItems = [];
    _currentPath = '/';
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadDirectory(String path) async {
    if (_activeSource == null) {
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final files = await _fetchDirectory(path);
      _currentItems = files;
      _currentPath = path;
      _isLoading = false;
      notifyListeners();
    } catch (error) {
      _errorMessage = '加载目录失败: $error';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> saveEmbySource({
    MediaSource? existingSource,
    required String name,
    required String url,
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedSource = await _sourceService.saveEmbySource(
        existingSource: existingSource,
        name: name,
        url: url,
        username: username,
        password: password,
      );
      _upsertSource(updatedSource);
      _isLoading = false;
      notifyListeners();
      return existingSource == null ? '添加成功' : '服务器更新成功';
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      throw Exception('$error');
    }
  }

  Future<String> saveNetworkSource({
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedSource = await _sourceService.saveNetworkSource(
        existingSource: existingSource,
        type: type,
        name: name,
        host: host,
        port: port,
        username: username,
        password: password,
        shareName: shareName,
        workgroup: workgroup,
        savePassword: savePassword,
      );
      _upsertSource(updatedSource);
      _isLoading = false;
      notifyListeners();
      return existingSource == null ? '添加成功' : '媒体源更新成功';
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      throw Exception('$error');
    }
  }

  Future<String> deleteSource(MediaSource source) async {
    try {
      await _sourceService.deleteSource(source);
      _sources.removeWhere((item) => item.id == source.id);
      notifyListeners();
      return '删除成功';
    } catch (error) {
      throw Exception('删除失败: $error');
    }
  }

  Future<String> refreshAndSync(AuthProvider authProvider) async {
    if (!authProvider.isAuthenticated) {
      throw Exception('请先登录');
    }
    if (!authProvider.isSyncEnabled) {
      throw Exception('请先在账户页面启用云同步');
    }

    await authProvider.triggerSync();
    await loadSources();
    return '同步完成';
  }

  String createProxyUrl(NetworkFile file) {
    final activeSource = _activeSource;
    if (activeSource == null) {
      throw Exception('当前没有激活的媒体源');
    }

    final connection = activeSource.toNetworkConnection();
    return _proxyServer.createProxyUrl(connection, file.path);
  }

  Future<List<NetworkFile>> _fetchDirectory(String path) async {
    final source = _activeSource;
    if (source == null) {
      return const [];
    }

    if (source.type == SourceType.ftp) {
      _ftpService ??= FTPService();
      return _ftpService!.listDirectory(path);
    }
    if (source.type == SourceType.smb) {
      _smbService ??= SMBService();
      return _smbService!.listDirectory(path);
    }
    return const [];
  }

  Future<void> _disconnectClients() async {
    await _ftpService?.disconnect();
    await _smbService?.disconnect();
    _ftpService = null;
    _smbService = null;
  }

  void _upsertSource(MediaSource source) {
    final index = _sources.indexWhere((item) => item.id == source.id);
    if (index >= 0) {
      _sources[index] = source;
    } else {
      _sources.add(source);
    }
  }
}
