import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'unified_player_page.dart';
import 'models/network_connection.dart';
import 'models/network_file.dart';
import 'services/connection_manager.dart';
import 'services/ftp_service.dart';
import 'services/smb_service.dart';
import 'services/local_proxy_server.dart';
import 'emby_page.dart';
import 'widgets/custom_app_bar.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

// ============== 数据模型 ==============

enum SourceType { emby, smb, ftp }

class MediaSource {
  final String id;
  final String name;
  final SourceType type;
  final String url;
  final String username;
  final String password;
  String? accessToken;
  String? userId;

  MediaSource({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.username,
    this.password = '',
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
    'accessToken': accessToken,
    'userId': userId,
  };

  factory MediaSource.fromJson(Map<String, dynamic> j) => MediaSource(
    id: j['id'] ?? '',
    name: j['name'] ?? '',
    type: SourceType.values.firstWhere(
      (e) => e.toString() == j['type'],
      orElse: () => SourceType.emby,
    ),
    url: j['url'] ?? '',
    username: j['username'] ?? '',
    password: j['password'] ?? '',
    accessToken: j['accessToken'],
    userId: j['userId'],
  );

  // 从 NetworkConnection 转换
  factory MediaSource.fromNetworkConnection(NetworkConnection conn) {
    final type = conn.protocol == NetworkProtocol.smb ? SourceType.smb : SourceType.ftp;
    return MediaSource(
      id: conn.id,
      name: conn.name,
      type: type,
      url: '${conn.protocol.name}://${conn.host}:${conn.port}',
      username: conn.username,
      password: conn.password,
    );
  }

  // 转换为 NetworkConnection
  NetworkConnection toNetworkConnection() {
    return NetworkConnection(
      id: id,
      protocol: type == SourceType.smb ? NetworkProtocol.smb : NetworkProtocol.ftp,
      name: name,
      host: Uri.parse(url).host,
      port: Uri.parse(url).port,
      username: username,
      password: password,
      lastConnected: DateTime.now(),
    );
  }
}

// ============== 主题配置 ==============

class AppTheme {
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color primary = Color(0xFF1F2937);
  static const Color primaryDark = Color(0xFF111827);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];
}

// ============== 媒体库页面 ==============

class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({super.key});

  @override
  State<MediaLibraryPage> createState() => MediaLibraryPageState();
}

class MediaLibraryPageState extends State<MediaLibraryPage> {
  List<MediaSource> _sources = [];
  MediaSource? _activeSource;
  bool _isLoading = false;
  String? _errorMsg;

  // 网络服务
  final ConnectionManager _connectionManager = ConnectionManager();
  final LocalProxyServer _proxyServer = LocalProxyServer();
  FTPService? _ftpService;
  SMBService? _smbService;

  // 文件浏览
  List<dynamic> _currentItems = []; // Emby items 或 NetworkFile
  String _currentPath = '/';

  @override
  void initState() {
    super.initState();
    _loadSources();
    _startProxyServer();
  }

  @override
  void dispose() {
    _proxyServer.stop();
    _ftpService?.disconnect();
    _smbService?.disconnect();
    super.dispose();
  }

  Future<void> _startProxyServer() async {
    await _proxyServer.start();
  }

  Future<void> _loadSources() async {
    print('[MediaLibrary] 开始加载源列表');
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 加载 Emby 服务器
      final embySources = <MediaSource>[];
      final embyJson = prefs.getString('emby_servers');
      print('[MediaLibrary] Emby JSON: $embyJson');
      if (embyJson != null) {
        final List<dynamic> list = jsonDecode(embyJson);
        for (var item in list) {
          embySources.add(MediaSource.fromJson({
            ...item,
            'id': item['name'], // 使用 name 作为 id
            'type': SourceType.emby.toString(),
          }));
        }
      }
      print('[MediaLibrary] 加载了 ${embySources.length} 个 Emby 源');

      // 加载网络连接
      final connections = await _connectionManager.getConnections();
      print('[MediaLibrary] 加载了 ${connections.length} 个网络连接');
      final networkSources = connections.map((c) => MediaSource.fromNetworkConnection(c)).toList();

      setState(() {
        _sources = [...embySources, ...networkSources];
        _isLoading = false;
      });
      print('[MediaLibrary] 总共加载了 ${_sources.length} 个源');
    } catch (e, stackTrace) {
      print('[MediaLibrary] 加载失败: $e');
      print('[MediaLibrary] 堆栈: $stackTrace');
      setState(() {
        _errorMsg = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _activeSource != null
          ? CustomAppBar(
              showBackButton: true,
              title: _activeSource!.name,
              onBackPressed: () => setState(() {
                _activeSource = null;
                _currentItems = [];
              }),
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildAddButton() {
    return PopupMenuButton<SourceType>(
      icon: const Icon(Icons.add, color: AppTheme.textPrimary, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      offset: const Offset(0, 40),
      onSelected: (type) => _showAddSourceDialog(type),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: SourceType.emby,
          child: Row(
            children: [
              Icon(Icons.cloud_outlined, size: 18),
              SizedBox(width: 12),
              Text('Emby 服务器', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: SourceType.smb,
          child: Row(
            children: [
              Icon(Icons.folder_shared_outlined, size: 18),
              SizedBox(width: 12),
              Text('SMB 共享', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: SourceType.ftp,
          child: Row(
            children: [
              Icon(Icons.storage_outlined, size: 18),
              SizedBox(width: 12),
              Text('FTP 服务器', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMsg!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSources,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_activeSource != null) {
      return _buildFileBrowser();
    }

    return _buildSourceList();
  }

  Widget _buildSourceList() {
    if (_sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_add_outlined, size: 64, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              '暂无媒体源',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右上角 + 添加',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _sources.length,
      itemBuilder: (context, index) {
        final source = _sources[index];
        return _buildSourceCard(source);
      },
    );
  }

  Widget _buildSourceCard(MediaSource source) {
    IconData icon;
    Color iconColor;
    Color iconColorDark;
    String typeLabel;

    switch (source.type) {
      case SourceType.emby:
        icon = Icons.dns;
        iconColor = AppTheme.primary;
        iconColorDark = AppTheme.primaryDark;
        typeLabel = 'Emby';
        break;
      case SourceType.smb:
        icon = Icons.folder_shared;
        iconColor = const Color(0xFFFF9800);
        iconColorDark = const Color(0xFFF57C00);
        typeLabel = 'SMB';
        break;
      case SourceType.ftp:
        icon = Icons.storage;
        iconColor = const Color(0xFF4CAF50);
        iconColorDark = const Color(0xFF388E3C);
        typeLabel = 'FTP';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [iconColor, iconColorDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Text(
          source.name,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    source.url,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '用户: ${source.username}',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        trailing: (_isLoading && _activeSource == source)
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              )
            : const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
        onTap: _isLoading ? null : () => _connectToSource(source),
        onLongPress: () => _showSourceOptions(source),
      ),
    );
  }

  void _showSourceOptions(MediaSource source) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.textPrimary),
              title: const Text('编辑', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _editSource(source);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteSource(source);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileBrowser() {
    // TODO: 实现文件浏览器
    return const Center(child: Text('文件浏览器开发中...'));
  }

  // 公开方法，供外部调用（如 main.dart）
  void showAddSourceDialog(SourceType type) {
    if (type == SourceType.emby) {
      _showAddEmbyDialog();
    } else {
      _showAddNetworkDialog(type);
    }
  }
  
  // 内部使用的私有方法
  Future<void> _showAddSourceDialog(SourceType type) async {
    showAddSourceDialog(type);
  }

  void _showAddEmbyDialog({MediaSource? editSource}) {
    final isEdit = editSource != null;
    final nameCtrl = TextEditingController(text: isEdit ? editSource.name : '');
    final urlCtrl = TextEditingController(text: isEdit ? editSource.url : 'https://');
    final userCtrl = TextEditingController(text: isEdit ? editSource.username : '');
    final passCtrl = TextEditingController(text: isEdit ? editSource.password : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          isEdit ? '编辑 Emby 服务器' : '添加 Emby 服务器',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, '名称', '我的 Emby'),
              const SizedBox(height: 12),
              _dialogField(urlCtrl, '服务器地址', 'https://your-server:8096'),
              const SizedBox(height: 12),
              _dialogField(userCtrl, '用户名', ''),
              const SizedBox(height: 12),
              _dialogField(passCtrl, '密码', '', obscure: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              final user = userCtrl.text.trim();
              if (name.isEmpty || url.isEmpty || user.isEmpty) {
                _showError('请填写所有必填字段');
                return;
              }
              Navigator.pop(ctx);
              
              if (isEdit) {
                // 编辑现有服务器
                await _updateEmbyServer(
                  oldSource: editSource!,
                  name: name,
                  url: url,
                  username: user,
                  password: passCtrl.text,
                );
              } else {
                // 添加新服务器
                _addSource(
                  type: SourceType.emby,
                  name: name,
                  url: url,
                  username: user,
                  password: passCtrl.text,
                );
              }
            },
            child: Text(isEdit ? '保存' : '添加'),
          ),
        ],
      ),
    );
  }

  void _showAddNetworkDialog(SourceType type, {MediaSource? editSource}) {
    final isEdit = editSource != null;
    final formKey = GlobalKey<FormState>();
    
    final nameCtrl = TextEditingController(text: isEdit ? editSource.name : '');
    final hostCtrl = TextEditingController(text: isEdit ? Uri.parse(editSource.url).host : '');
    final portCtrl = TextEditingController(
      text: isEdit ? Uri.parse(editSource.url).port.toString() : (type == SourceType.ftp ? '21' : '445'),
    );
    final userCtrl = TextEditingController(text: isEdit ? editSource.username : '');
    final passCtrl = TextEditingController(text: isEdit ? editSource.password : '');
    final shareNameCtrl = TextEditingController();
    final workgroupCtrl = TextEditingController(text: 'WORKGROUP');
    bool savePassword = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          ),
          title: Text(
            isEdit ? '编辑${type == SourceType.smb ? ' SMB' : ' FTP'}' : '添加${type == SourceType.smb ? ' SMB 共享' : ' FTP 服务器'}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(nameCtrl, '名称', '例如：家庭服务器'),
                  const SizedBox(height: 12),
                  _dialogField(hostCtrl, '主机地址', '192.168.1.100'),
                  const SizedBox(height: 12),
                  _dialogField(portCtrl, '端口', type == SourceType.ftp ? '21' : '445', isNumber: true),
                  const SizedBox(height: 12),
                  _dialogField(userCtrl, '用户名', ''),
                  const SizedBox(height: 12),
                  _dialogField(passCtrl, '密码', '', obscure: true),
                  if (type == SourceType.smb) ...[
                    const SizedBox(height: 12),
                    _dialogField(shareNameCtrl, '共享名', '例如: share, movies'),
                    const SizedBox(height: 12),
                    _dialogField(workgroupCtrl, '工作组', 'WORKGROUP'),
                  ],
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('保存密码', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                    value: savePassword,
                    onChanged: (v) => setDialogState(() => savePassword = v!),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                '取消',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final name = nameCtrl.text.trim();
                final host = hostCtrl.text.trim();
                final port = int.tryParse(portCtrl.text.trim());
                
                if (name.isEmpty || host.isEmpty || port == null) {
                  _showError('请填写所有必填字段');
                  return;
                }
                
                if (type == SourceType.smb && shareNameCtrl.text.trim().isEmpty) {
                  _showError('请输入共享名');
                  return;
                }
                
                Navigator.pop(ctx);
                _addSource(
                  type: type,
                  name: name,
                  host: host,
                  port: port,
                  username: userCtrl.text,
                  password: savePassword ? passCtrl.text : '',
                  shareName: shareNameCtrl.text,
                  workgroup: workgroupCtrl.text,
                );
              },
              child: Text(isEdit ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscure = false,
    bool isNumber = false,
  }) {
    // 如果是密码字段，需要状态管理
    if (obscure) {
      return _PasswordField(
        controller: controller,
        label: label,
        hint: hint,
      );
    }
    
    // 非密码字段
    return TextField(
      controller: controller,
      obscureText: false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        filled: true,
        fillColor: AppTheme.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.textTertiary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }

  Future<void> _addSource({
    required SourceType type,
    required String name,
    String url = '',
    String host = '',
    int port = 0,
    required String username,
    required String password,
    String shareName = '',
    String workgroup = '',
  }) async {
    if (name.isEmpty) {
      _showError('请输入名称');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (type == SourceType.emby) {
        // 保存 Emby 服务器
        if (url.isEmpty) {
          _showError('请输入服务器地址');
          setState(() => _isLoading = false);
          return;
        }

        // 先登录获取 accessToken
        final loginResult = await _loginToEmby(url, username, password);
        
        if (loginResult == null) {
          _showError('登录失败，请检查服务器地址和凭据');
          setState(() => _isLoading = false);
          return;
        }

        final source = MediaSource(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          type: type,
          url: url,
          username: username,
          password: password,
          accessToken: loginResult['accessToken'],
          userId: loginResult['userId'],
        );

        final prefs = await SharedPreferences.getInstance();
        final embyJson = prefs.getString('emby_servers');
        final List<dynamic> list = embyJson != null ? jsonDecode(embyJson) : [];
        list.add({
          'name': name,
          'url': url,
          'username': username,
          'password': password,
          'accessToken': loginResult['accessToken'],
          'userId': loginResult['userId'],
        });
        await prefs.setString('emby_servers', jsonEncode(list));

        setState(() {
          _sources.add(source);
          _isLoading = false;
        });
        
        _showSuccess('添加成功');
        _triggerSync();
      } else {
        // 保存网络连接
        if (host.isEmpty) {
          _showError('请输入主机地址');
          return;
        }

        final connection = NetworkConnection(
          id: ConnectionManager().generateId(),
          protocol: type == SourceType.smb ? NetworkProtocol.smb : NetworkProtocol.ftp,
          name: name,
          host: host,
          port: port,
          username: username,
          password: password,
          shareName: type == SourceType.smb ? shareName : null,
          workgroup: type == SourceType.smb ? workgroup : null,
          lastConnected: DateTime.now(),
        );

        await _connectionManager.saveConnection(connection);

        final source = MediaSource.fromNetworkConnection(connection);
        setState(() {
          _sources.add(source);
          _isLoading = false;
        });
      }

      _showSuccess('添加成功');
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('添加失败: $e');
    }
  }

  Future<void> _connectToSource(MediaSource source) async {
    if (source.type == SourceType.emby) {
      // 创建 EmbyServer 对象并导航到 EmbyPage
      final embyServer = EmbyServer(
        name: source.name,
        url: source.url,
        username: source.username,
        password: source.password,
        accessToken: source.accessToken,
        userId: source.userId,
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmbyPage(initialServer: embyServer),
        ),
      );
      return;
    }

    setState(() {
      _activeSource = source;
      _isLoading = true;
    });

    try {
      if (source.type == SourceType.ftp) {
        _ftpService = FTPService();
        final conn = source.toNetworkConnection();
        final success = await _ftpService!.connect(conn);
        
        if (success) {
          final files = await _ftpService!.listDirectory('/');
          setState(() {
            _currentItems = files;
            _currentPath = '/';
            _isLoading = false;
          });
        } else {
          throw Exception('连接失败');
        }
      } else if (source.type == SourceType.smb) {
        _smbService = SMBService();
        final conn = source.toNetworkConnection();
        final success = await _smbService!.connect(conn);
        
        if (success) {
          final files = await _smbService!.listDirectory('/');
          setState(() {
            _currentItems = files;
            _currentPath = '/';
            _isLoading = false;
          });
        } else {
          throw Exception('连接失败');
        }
      }
    } catch (e) {
      setState(() {
        _activeSource = null;
        _isLoading = false;
      });
      _showError('连接失败: $e');
    }
  }

  Future<void> _deleteSource(MediaSource source) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        title: const Text('确认删除', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('确定要删除 "${source.name}" 吗？', style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (source.type == SourceType.emby) {
          final prefs = await SharedPreferences.getInstance();
          final embyJson = prefs.getString('emby_servers');
          if (embyJson != null) {
            final List<dynamic> list = jsonDecode(embyJson);
            list.removeWhere((item) => item['name'] == source.name);
            await prefs.setString('emby_servers', jsonEncode(list));
          }
        } else {
          await _connectionManager.deleteConnection(source.id);
        }

        setState(() {
          _sources.removeWhere((s) => s.id == source.id);
        });

        _showSuccess('删除成功');
      } catch (e) {
        _showError('删除失败: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _editSource(MediaSource source) async {
    if (source.type == SourceType.emby) {
      _showAddEmbyDialog(editSource: source);
    } else {
      _showAddNetworkDialog(source.type, editSource: source);
    }
  }
  
  Future<void> _updateEmbyServer({
    required MediaSource oldSource,
    required String name,
    required String url,
    required String username,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final embyJson = prefs.getString('emby_servers');
      
      if (embyJson != null) {
        final List<dynamic> list = jsonDecode(embyJson);
        
        // 查找并更新服务器
        final index = list.indexWhere((item) => 
          item['name'] == oldSource.name && item['url'] == oldSource.url
        );
        
        if (index != -1) {
          // 先登录获取新的 accessToken
          final loginResult = await _loginToEmby(url, username, password);
          
          if (loginResult != null) {
            // 更新服务器信息
            list[index] = {
              'name': name,
              'url': url,
              'username': username,
              'password': password,
              'accessToken': loginResult['accessToken'],
              'userId': loginResult['userId'],
            };
            
            await prefs.setString('emby_servers', jsonEncode(list));
            
            // 更新 UI
            setState(() {
              final sourceIndex = _sources.indexWhere((s) => s.id == oldSource.id);
              if (sourceIndex != -1) {
                _sources[sourceIndex] = MediaSource(
                  id: oldSource.id,
                  type: SourceType.emby,
                  name: name,
                  url: url,
                  username: username,
                  password: password,
                  accessToken: loginResult['accessToken'],
                  userId: loginResult['userId'],
                );
              }
            });
            
            _showSuccess('服务器更新成功');
            
            // 触发同步
            _triggerSync();
          } else {
            _showError('登录失败，请检查服务器地址和凭据');
          }
        }
      }
    } catch (e) {
      _showError('更新失败: $e');
    }
  }

  void _triggerSync() {
    // 触发后台同步
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.isAuthenticated) {
        print('[MediaLibrary] 触发同步...');
        authProvider.triggerSync();
      } else {
        print('[MediaLibrary] 用户未登录，跳过同步');
      }
    } catch (e) {
      print('[MediaLibrary] 触发同步失败: $e');
    }
  }
  
  /// 刷新并同步（供外部调用）
  Future<void> refreshAndSync() async {
    print('[MediaLibrary] 🔄 刷新并同步...');
    
    // 1. 先触发同步
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.isAuthenticated) {
        if (authProvider.isSyncEnabled) {
          print('[MediaLibrary] 开始同步...');
          await authProvider.triggerSync();
          print('[MediaLibrary] 同步完成');
          
          // 2. 同步完成后重新加载本地数据
          await _loadSources();
          
          _showSuccess('同步完成');
        } else {
          print('[MediaLibrary] 同步未启用');
          _showError('请先在账户页面启用云同步');
        }
      } else {
        print('[MediaLibrary] 用户未登录');
        _showError('请先登录');
      }
    } catch (e) {
      print('[MediaLibrary] 同步失败: $e');
      _showError('同步失败: $e');
    }
  }
  
  Future<Map<String, dynamic>?> _loginToEmby(String url, String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$url/Users/AuthenticateByName'),
        headers: {
          'Content-Type': 'application/json',
          'X-Emby-Authorization':
              'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="flutter-app", Version="1.0.0"',
        },
        body: jsonEncode({
          'Username': username,
          'Pw': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'accessToken': data['AccessToken'],
          'userId': data['User']['Id'],
        };
      }
    } catch (e) {
      print('[MediaLibrary] Emby 登录失败: $e');
    }
    return null;
  }
}

// ============== 密码输入字段组件 ==============

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscureText,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        filled: true,
        fillColor: AppTheme.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.textTertiary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppTheme.textSecondary,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _obscureText = !_obscureText;
            });
          },
        ),
      ),
    );
  }
}
