import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'media_kit_player_page.dart';

// ============== 数据模型 ==============

class EmbyServer {
  String name;
  String url;
  String username;
  String password;
  String? accessToken;
  String? userId;

  EmbyServer({required this.name, required this.url, required this.username, this.password = '', this.accessToken, this.userId});
  Map<String, dynamic> toJson() => {'name': name, 'url': url, 'username': username, 'password': password};
  factory EmbyServer.fromJson(Map<String, dynamic> j) => EmbyServer(
    name: j['name'] ?? '', url: j['url'] ?? '', username: j['username'] ?? '', password: j['password'] ?? '',
  );
}

/// 视图模式 (和 egui 完全一致)
enum EmbyViewMode { serverList, dashboard, browser, itemDetail }

// ============== Emby 主页面 ==============

class EmbyPage extends StatefulWidget {
  const EmbyPage({super.key});
  @override
  State<EmbyPage> createState() => _EmbyPageState();
}

class _EmbyPageState extends State<EmbyPage> {
  // 服务器
  List<EmbyServer> _servers = [];
  EmbyServer? _activeServer;
  bool _isLoading = false;
  String? _errorMsg;

  // 视图模式
  EmbyViewMode _viewMode = EmbyViewMode.serverList;

  // 仪表板
  List<Map<String, dynamic>> _libraries = [];
  Map<String, List<Map<String, dynamic>>> _viewItems = {};

  // 浏览器
  List<List<String>> _navigationStack = []; // [[id, name], ...]
  List<Map<String, dynamic>> _browseItems = [];
  bool _isLoadingBrowse = false;

  // 详情页
  Map<String, dynamic>? _selectedItem;
  List<Map<String, dynamic>> _seriesSeasons = [];
  Map<String, List<Map<String, dynamic>>> _seasonEpisodes = {};
  int _selectedSeasonIndex = 0;

  @override
  void initState() {
    super.initState();
    print('[EmbyPage] initState 开始');
    _loadServers().then((_) {
      print('[EmbyPage] 服务器加载完成，共 ${_servers.length} 个服务器');
    }).catchError((e) {
      print('[EmbyPage] 加载服务器失败: $e');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ============== 服务器持久化 ==============

  Future<void> _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('emby_servers');
    if (data != null) {
      final list = jsonDecode(data) as List;
      setState(() => _servers = list.map((e) => EmbyServer.fromJson(e)).toList());
    }
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emby_servers', jsonEncode(_servers.map((s) => s.toJson()).toList()));
  }

  void _addServer(EmbyServer server) { setState(() => _servers.add(server)); _saveServers(); }
  void _removeServer(int index) { setState(() => _servers.removeAt(index)); _saveServers(); }

  // ============== Emby API ==============

  Map<String, String> _headers() => {
    'X-Emby-Authorization': 'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0", Token="${_activeServer?.accessToken ?? ""}"',
    'Content-Type': 'application/json',
  };

  String _imageUrl(String itemId, {String type = 'Primary', int maxWidth = 300}) {
    return '${_activeServer!.url}/emby/Items/$itemId/Images/$type?maxWidth=$maxWidth&api_key=${_activeServer!.accessToken}';
  }

  String _streamUrl(String itemId) {
    // 使用直接播放 URL（Direct Play）
    // 移除显式的端口 443，让 HTTPS 使用默认端口
    final server = _activeServer!;
    var baseUrl = server.url;
    
    // 如果 URL 包含 :443，移除它（HTTPS 默认端口）
    if (baseUrl.contains(':443')) {
      baseUrl = baseUrl.replaceAll(':443', '');
    }
    
    return '$baseUrl/Videos/$itemId/stream?static=true&api_key=${server.accessToken}';
  }

  Future<void> _connectServer(EmbyServer server) async {
    setState(() { _isLoading = true; _errorMsg = null; _activeServer = server; });
    try {
      final r = await http.post(
        Uri.parse('${server.url}/emby/Users/AuthenticateByName'),
        headers: {
          'X-Emby-Authorization': 'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0"',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'Username': server.username, 'Pw': server.password}),
      ).timeout(const Duration(seconds: 10));

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        server.accessToken = data['AccessToken'];
        server.userId = data['User']['Id'];
        setState(() { _isLoading = false; _viewMode = EmbyViewMode.dashboard; });
        await _loadDashboard();
      } else {
        setState(() { _isLoading = false; _errorMsg = '登录失败: 用户名或密码错误'; });
      }
    } catch (e) {
      setState(() { _isLoading = false; _errorMsg = '连接失败: $e'; });
    }
  }

  Future<void> _loadDashboard() async {
    if (_activeServer == null) return;
    await _loadLibraries();
    for (final lib in _libraries) {
      _loadViewItems(lib['Id'], limit: 12);
    }
  }

  Future<void> _loadLibraries() async {
    try {
      final s = _activeServer!;
      final r = await http.get(Uri.parse('${s.url}/emby/Users/${s.userId}/Views'), headers: _headers());
      if (r.statusCode == 200) {
        setState(() => _libraries = List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []));
      }
    } catch (_) {}
  }

  /// 递归加载 View 的所有内容
  Future<void> _loadViewItems(String viewId, {int limit = 12}) async {
    try {
      final s = _activeServer!;
      // Recursive=true + IncludeItemTypes=Movie,Series,Audio,Photo,MusicAlbum
      // 显示 Movie 和 Series（不显示单个 Episode），同时支持音乐和照片
      final r = await http.get(
        Uri.parse('${s.url}/emby/Users/${s.userId}/Items'
            '?ParentId=$viewId'
            '&Recursive=true'
            '&IncludeItemTypes=Movie,Series,Audio,Photo,MusicAlbum'
            '&Limit=$limit'
            '&Fields=Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,OfficialRating,ChildCount,RecursiveItemCount'
            '&SortBy=DateCreated,SortName'
            '&SortOrder=Descending'),
        headers: _headers(),
      );
      if (r.statusCode == 200) {
        final items = List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []);
        setState(() => _viewItems[viewId] = items);
      }
    } catch (_) {}
  }

  /// 加载浏览页项目 (和 egui get_items 一致)
  Future<void> _loadBrowserItems(String parentId, String name, {bool recursive = false}) async {
    setState(() { _isLoadingBrowse = true; });
    try {
      final s = _activeServer!;
      final fields = 'Fields=Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,OfficialRating,ChildCount,RecursiveItemCount';
      String url;
      if (recursive) {
        // 递归模式：穿透子目录，只显示 Movie 和 Series
        url = '${s.url}/emby/Users/${s.userId}/Items'
            '?ParentId=$parentId'
            '&Recursive=true'
            '&IncludeItemTypes=Movie,Series'
            '&SortBy=DateCreated,SortName'
            '&SortOrder=Descending'
            '&$fields';
      } else {
        // 非递归模式：Series → Season 或 Season → Episode
        url = '${s.url}/emby/Users/${s.userId}/Items'
            '?ParentId=$parentId'
            '&SortBy=SortName'
            '&$fields';
      }
      final r = await http.get(Uri.parse(url), headers: _headers());
      if (r.statusCode == 200) {
        setState(() {
          _browseItems = List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []);
          _isLoadingBrowse = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingBrowse = false);
    }
  }

  /// 加载 Series 的 Seasons
  Future<void> _loadSeriesSeasons(String seriesId) async {
    try {
      final s = _activeServer!;
      final r = await http.get(
        Uri.parse('${s.url}/emby/Users/${s.userId}/Items?ParentId=$seriesId&Fields=Overview'),
        headers: _headers(),
      );
      if (r.statusCode == 200) {
        final seasons = List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []);
        setState(() {
          _seriesSeasons = seasons;
          _selectedSeasonIndex = 0;
          _seasonEpisodes = {};
        });
        // 加载第一季的剧集
        if (seasons.isNotEmpty) {
          _loadSeasonEpisodes(seasons[0]['Id']);
        }
      }
    } catch (_) {}
  }

  /// 加载某季的剧集
  Future<void> _loadSeasonEpisodes(String seasonId) async {
    if (_seasonEpisodes.containsKey(seasonId)) return; // 已缓存
    try {
      final s = _activeServer!;
      final r = await http.get(
        Uri.parse('${s.url}/emby/Users/${s.userId}/Items?ParentId=$seasonId&Fields=Overview,MediaSources&SortBy=SortName'),
        headers: _headers(),
      );
      if (r.statusCode == 200) {
        final eps = List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []);
        setState(() => _seasonEpisodes[seasonId] = eps);
      }
    } catch (_) {}
  }

  // ============== 点击项目路由 (和 egui handle_emby_item_click 一致) ==============

  void _handleItemClick(Map<String, dynamic> item) {
    final type = item['Type'] as String?;

    switch (type) {
      case 'Series':
        // Series → 详情页，加载 Seasons
        setState(() {
          _selectedItem = item;
          _viewMode = EmbyViewMode.itemDetail;
          _seriesSeasons = [];
          _seasonEpisodes = {};
          _selectedSeasonIndex = 0;
        });
        _loadSeriesSeasons(item['Id']);
        break;

      case 'Folder':
      case 'CollectionFolder':
      case 'UserView':
      case 'BoxSet':
        // 文件夹 → Browser 模式
        setState(() {
          _navigationStack.add([item['Id'], item['Name'] ?? '']);
          _viewMode = EmbyViewMode.browser;
        });
        _loadBrowserItems(item['Id'], item['Name'] ?? '', recursive: true);
        break;

      case 'Season':
        // Season → Browser 模式 (显示 Episodes)
        setState(() {
          _navigationStack.add([item['Id'], item['Name'] ?? '']);
          _viewMode = EmbyViewMode.browser;
        });
        _loadBrowserItems(item['Id'], item['Name'] ?? '', recursive: false);
        break;

      default:
        // Movie / Episode → 详情页
        setState(() {
          _selectedItem = item;
          _viewMode = EmbyViewMode.itemDetail;
        });
        break;
    }
  }

  // ============== 播放 ==============

  Future<void> _playItem(String itemId, String name) async {
    print('[EmbyPage] 准备播放: $name');
    print('[EmbyPage] Item ID: $itemId');
    
    final server = _activeServer!;
    var baseUrl = server.url;
    if (baseUrl.contains(':443')) {
      baseUrl = baseUrl.replaceAll(':443', '');
    }
    
    // 使用直接流播放（不转码）
    final url = '$baseUrl/Videos/$itemId/stream?static=true&api_key=${server.accessToken}';
    
    print('[EmbyPage] Stream URL (Direct Play): $url');
    
    // 构建 HTTP headers
    final headers = _headers();
    
    // 获取字幕列表
    final subtitles = await _fetchSubtitles(itemId);
    
    // 使用 media_kit 播放器（所有平台）
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaKitPlayerPage(
            url: url,
            title: name,
            httpHeaders: headers,
            subtitles: subtitles,
          ),
        ),
      );
    }
  }

  /// 获取字幕列表
  Future<List<Map<String, String>>> _fetchSubtitles(String itemId) async {
    try {
      final server = _activeServer!;
      var baseUrl = server.url;
      if (baseUrl.contains(':443')) {
        baseUrl = baseUrl.replaceAll(':443', '');
      }
      
      final url = '$baseUrl/emby/Items/$itemId?Fields=MediaStreams&api_key=${server.accessToken}';
      final response = await http.get(Uri.parse(url), headers: _headers());
      
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final mediaStreams = data['MediaStreams'] as List<dynamic>?;
        
        if (mediaStreams != null) {
          final subtitles = <Map<String, String>>[];
          
          for (var stream in mediaStreams) {
            if (stream['Type'] == 'Subtitle') {
              final index = stream['Index'] as int;
              final language = stream['Language'] as String? ?? stream['DisplayLanguage'] as String? ?? 'Unknown';
              final title = stream['DisplayTitle'] as String? ?? language;
              final isExternal = stream['IsExternal'] as bool? ?? false;
              
              if (isExternal && stream['DeliveryUrl'] != null) {
                // 外部字幕
                var subtitleUrl = stream['DeliveryUrl'] as String;
                if (!subtitleUrl.startsWith('http')) {
                  subtitleUrl = '$baseUrl$subtitleUrl';
                }
                
                subtitles.add({
                  'title': title,
                  'url': subtitleUrl,
                  'language': language,
                });
              } else {
                // 内嵌字幕 - 通过 Emby API 提取
                final subtitleUrl = '$baseUrl/Videos/$itemId/$itemId/Subtitles/$index/Stream.srt?api_key=${server.accessToken}';
                
                subtitles.add({
                  'title': title,
                  'url': subtitleUrl,
                  'language': language,
                });
              }
            }
          }
          
          print('[EmbyPage] 找到 ${subtitles.length} 个字幕');
          return subtitles;
        }
      }
    } catch (e) {
      print('[EmbyPage] 获取字幕失败: $e');
    }
    
    return [];
  }

  void _goToServerList() {
    setState(() {
      _viewMode = EmbyViewMode.serverList;
      _activeServer?.accessToken = null;
      _activeServer?.userId = null;
      _activeServer = null;
      _libraries = [];
      _viewItems = {};
      _browseItems = [];
      _navigationStack = [];
      _selectedItem = null;
    });
  }

  void _goToDashboard() {
    setState(() {
      _viewMode = EmbyViewMode.dashboard;
      _browseItems = [];
      _navigationStack = [];
      _selectedItem = null;
    });
    _loadDashboard();
  }

  void _goBack() {
    if (_viewMode == EmbyViewMode.itemDetail) {
      setState(() {
        _selectedItem = null;
        _viewMode = _navigationStack.isEmpty ? EmbyViewMode.dashboard : EmbyViewMode.browser;
      });
    } else if (_viewMode == EmbyViewMode.browser) {
      if (_navigationStack.isNotEmpty) {
        _navigationStack.removeLast();
        if (_navigationStack.isEmpty) {
          _goToDashboard();
        } else {
          final prev = _navigationStack.last;
          _loadBrowserItems(prev[0], prev[1], recursive: true);
        }
      } else {
        _goToDashboard();
      }
    }
  }

  // ============== 页面路由 ==============

  @override
  Widget build(BuildContext context) {
    print('[EmbyPage] build 被调用，当前模式: $_viewMode');
    
    try {
      switch (_viewMode) {
        case EmbyViewMode.serverList:
          return _buildServerListPage();
        case EmbyViewMode.dashboard:
          return _buildDashboard();
        case EmbyViewMode.browser:
          return _buildBrowserPage();
        case EmbyViewMode.itemDetail:
          return _buildItemDetailPage();
      }
    } catch (e, stackTrace) {
      print('[EmbyPage] 构建页面时出错: $e');
      print('[EmbyPage] 堆栈跟踪: $stackTrace');
      
      // 返回错误页面
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          title: const Text('Emby'),
          backgroundColor: const Color(0xFF16213E),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                '页面加载失败',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _viewMode = EmbyViewMode.serverList;
                  });
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ===================================
  //  1) 服务器列表页
  // ===================================

  Widget _buildServerListPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Emby 服务器', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E), foregroundColor: Colors.white, elevation: 0,
      ),
      body: _servers.isEmpty ? _buildEmptyServerList() : _buildServerList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
        onPressed: () => _showAddServerDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyServerList() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.deepPurple.withOpacity(0.15)),
        child: Icon(Icons.dns_outlined, size: 40, color: Colors.deepPurple.shade200),
      ),
      const SizedBox(height: 20),
      const Text('还没有添加服务器', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      const Text('点击右下角 + 添加 Emby 服务器', style: TextStyle(color: Colors.white38, fontSize: 13)),
    ]));
  }

  Widget _buildServerList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _servers.length,
      itemBuilder: (ctx, i) {
        final s = _servers[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(colors: [Colors.deepPurple.withOpacity(0.15), const Color(0xFF16213E)]),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.deepPurple.withOpacity(0.2)),
              child: Icon(Icons.dns, color: Colors.deepPurple.shade200, size: 22),
            ),
            title: Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 2),
              Text(s.url, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              Text('用户: ${s.username}', style: const TextStyle(color: Colors.white24, fontSize: 11)),
            ]),
            trailing: (_isLoading && _activeServer == s)
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple))
                : const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: _isLoading ? null : () => _connectServer(s),
            onLongPress: () => _showServerOptions(i),
          ),
        );
      },
    );
  }

  void _showServerOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16213E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.edit, color: Colors.white70),
          title: const Text('编辑', style: TextStyle(color: Colors.white)),
          onTap: () { Navigator.pop(ctx); _showAddServerDialog(editIndex: index); },
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.redAccent),
          title: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          onTap: () { Navigator.pop(ctx); _removeServer(index); },
        ),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _showAddServerDialog({int? editIndex}) {
    final isEdit = editIndex != null;
    final nameCtrl = TextEditingController(text: isEdit ? _servers[editIndex].name : '');
    final urlCtrl = TextEditingController(text: isEdit ? _servers[editIndex].url : 'https://');
    final userCtrl = TextEditingController(text: isEdit ? _servers[editIndex].username : '');
    final passCtrl = TextEditingController(text: isEdit ? _servers[editIndex].password : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? '编辑服务器' : '添加服务器', style: const TextStyle(color: Colors.white, fontSize: 18)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _dialogField(nameCtrl, '名称', '我的 Emby'),
          const SizedBox(height: 12),
          _dialogField(urlCtrl, '服务器地址', 'https://your-server:8096'),
          const SizedBox(height: 12),
          _dialogField(userCtrl, '用户名', ''),
          const SizedBox(height: 12),
          _dialogField(passCtrl, '密码', '', obscure: true),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameCtrl.text.trim(); final url = urlCtrl.text.trim(); final user = userCtrl.text.trim();
              if (name.isEmpty || url.isEmpty || user.isEmpty) return;
              final server = EmbyServer(name: name, url: url, username: user, password: passCtrl.text);
              if (isEdit) { setState(() => _servers[editIndex] = server); _saveServers(); }
              else { _addServer(server); }
              Navigator.pop(ctx);
            },
            child: Text(isEdit ? '保存' : '添加'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController c, String label, String hint, {bool obscure = false}) {
    return TextField(
      controller: c, obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        hintStyle: const TextStyle(color: Colors.white12, fontSize: 13),
        filled: true, fillColor: const Color(0xFF16213E),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.deepPurple)),
      ),
    );
  }

  // ===================================
  //  2) 仪表板 - 每个库一行横向海报
  // ===================================

  Widget _buildDashboard() {
    final s = _activeServer!;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true, backgroundColor: const Color(0xFF16213E), foregroundColor: Colors.white,
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goToServerList),
            title: Row(children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.deepPurple, size: 24),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('${s.username}@${Uri.parse(s.url).host}', style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ])),
            ]),
            actions: [IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadDashboard)],
          ),
          for (final lib in _libraries) ...[
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
              child: Row(children: [
                Icon(_libraryIcon(lib['CollectionType'] ?? ''), color: Colors.deepPurple.shade200, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(lib['Name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _navigationStack = [[lib['Id'], lib['Name'] ?? '']];
                      _viewMode = EmbyViewMode.browser;
                    });
                    _loadBrowserItems(lib['Id'], lib['Name'] ?? '', recursive: true);
                  },
                  child: const Text('更多 →', style: TextStyle(color: Colors.deepPurple, fontSize: 13)),
                ),
              ]),
            )),
            SliverToBoxAdapter(child: _buildViewItemsRow(lib['Id'] ?? '')),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.white10, height: 1),
            )),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  IconData _libraryIcon(String type) {
    switch (type) {
      case 'movies': return Icons.movie_outlined;
      case 'tvshows': return Icons.tv;
      case 'music': return Icons.music_note;
      default: return Icons.folder_outlined;
    }
  }

  Widget _buildViewItemsRow(String viewId) {
    final items = _viewItems[viewId];
    if (items == null) {
      return SizedBox(
        height: 210,
        child: ListView.builder(
          scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            width: 130, margin: const EdgeInsets.only(right: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Container(
                decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(4)),
                child: const Center(child: Icon(Icons.hourglass_empty, color: Colors.white12, size: 30)),
              )),
              const SizedBox(height: 6),
              Container(height: 12, width: 80, decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(2))),
            ]),
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Text('暂无内容', style: TextStyle(color: Colors.white24, fontSize: 13)));
    }
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (_, i) => _posterCard(items[i]),
      ),
    );
  }

  Widget _posterCard(Map<String, dynamic> item) {
    final name = item['Name'] ?? '';
    final year = item['ProductionYear']?.toString() ?? '';
    final itemId = item['Id'] ?? '';
    final type = item['Type'] ?? '';
    // 对于 Series，优先使用 RecursiveItemCount（所有剧集数），否则使用 ChildCount（季数）
    final childCount = type == 'Series' 
        ? (item['RecursiveItemCount'] ?? item['ChildCount']) 
        : item['ChildCount'];

    return GestureDetector(
      onTap: () => _handleItemClick(item),
      child: Container(
        width: 130, margin: const EdgeInsets.only(right: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(fit: StackFit.expand, children: [
                Container(
                  color: const Color(0xFF16213E),
                  child: Image.network(_imageUrl(itemId), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Icon(
                      _itemIcon(type), color: Colors.white24, size: 36,
                    ))),
                ),
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.center,
                    colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                  )),
                )),
                // Series 集数徽章
                if (type == 'Series' && childCount != null)
                  Positioned(top: 8, right: 8, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF50C878), borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$childCount', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  )),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (year.isNotEmpty)
            Text(year, style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ]),
      ),
    );
  }

  IconData _itemIcon(String type) {
    switch (type) {
      case 'Movie': case 'Video': return Icons.movie;
      case 'Episode': return Icons.tv;
      case 'Series': case 'BoxSet': return Icons.tv;
      case 'Season': return Icons.folder;
      case 'Folder': case 'CollectionFolder': case 'UserView': return Icons.folder;
      default: return Icons.description;
    }
  }

  // ===================================
  //  3) Browser 浏览页 (面包屑导航 + 网格)
  // ===================================

  Widget _buildBrowserPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Column(children: [
        // 面包屑导航栏
        Container(
          color: const Color(0xFF16213E),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                // ⬅ 服务器
                TextButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('服务器'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  onPressed: _goToServerList,
                ),
                Container(width: 1, height: 20, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 4)),
                // 🏠 首页
                TextButton.icon(
                  icon: const Icon(Icons.home, size: 16),
                  label: const Text('首页'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  onPressed: _goToDashboard,
                ),
                // 面包屑路径
                Expanded(child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (int i = 0; i < _navigationStack.length; i++) ...[
                      const Text(' / ', style: TextStyle(color: Colors.white24)),
                      TextButton(
                        onPressed: i < _navigationStack.length - 1 ? () {
                          setState(() => _navigationStack = _navigationStack.sublist(0, i + 1));
                          _loadBrowserItems(_navigationStack.last[0], _navigationStack.last[1], recursive: true);
                        } : null,
                        child: Text(
                          _navigationStack[i][1],
                          style: TextStyle(
                            color: i == _navigationStack.length - 1 ? Colors.white : Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ]),
                )),
              ]),
            ),
          ),
        ),

        // 项目计数
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            Text('共 ${_browseItems.length} 项', style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ]),
        ),

        // 网格
        Expanded(
          child: _isLoadingBrowse
              ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
              : _browseItems.isEmpty
                  ? const Center(child: Text('暂无内容', style: TextStyle(color: Colors.white38)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160, childAspectRatio: 0.5,
                        crossAxisSpacing: 12, mainAxisSpacing: 12,
                      ),
                      itemCount: _browseItems.length,
                      itemBuilder: (_, i) => _posterCard(_browseItems[i]),
                    ),
        ),
      ]),
    );
  }

  // ===================================
  //  4) 详情页 (Hero + 海报 + 元数据 + 播放 + 剧集)
  // ===================================

  Widget _buildItemDetailPage() {
    if (_selectedItem == null) return const SizedBox();
    final item = _selectedItem!;
    final name = item['Name'] ?? '';
    final itemId = item['Id'] ?? '';
    final type = item['Type'] ?? '';
    final overview = item['Overview'] as String?;
    final year = item['ProductionYear']?.toString();
    final rating = item['CommunityRating'];
    final runtime = item['RunTimeTicks'] as int?;
    final officialRating = item['OfficialRating'] as String?;

    String? runtimeStr;
    if (runtime != null) {
      final mins = runtime ~/ 10000000 ~/ 60;
      final hours = mins ~/ 60;
      final m = mins % 60;
      runtimeStr = hours > 0 ? '${hours}小时${m}分钟' : '${m}分钟';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          // 顶部导航
          SliverAppBar(
            floating: true, backgroundColor: const Color(0xFF16213E), foregroundColor: Colors.white,
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack),
            title: Text(name, style: const TextStyle(fontSize: 15)),
            actions: [
              TextButton(onPressed: _goToDashboard, child: const Text('首页', style: TextStyle(color: Colors.white54))),
            ],
          ),

          // Hero Section: 背景图 + 覆盖信息
          SliverToBoxAdapter(child: _buildHeroSection(item)),

          // 播放按钮 (Movie 和 Episode 可播放)
          if (type == 'Movie' || type == 'Episode' || type == 'Video')
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow, size: 28),
                label: const Text('立即播放', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _playItem(itemId, name),
              ),
            )),

          // 简介
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('简介', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(overview ?? '暂无简介', style: TextStyle(color: overview != null ? Colors.white70 : Colors.white24, fontSize: 14, height: 1.6)),
            ]),
          )),

          // Series: 季 + 剧集选择器
          if (type == 'Series') ...[
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _buildSeasonSelector(),
            )),
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: _buildEpisodeList(),
            )),
          ],

          // 详细信息
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('详细信息', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _detailRow('类型', type),
              if (year != null) _detailRow('年份', year),
              if (officialRating != null) _detailRow('分级', officialRating),
              if (runtimeStr != null) _detailRow('时长', runtimeStr),
              if (rating != null) _detailRow('评分', '★ ${(rating as num).toStringAsFixed(1)}/10'),
              if (item['OriginalTitle'] != null) _detailRow('原始标题', item['OriginalTitle']),
            ]),
          )),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildHeroSection(Map<String, dynamic> item) {
    final itemId = item['Id'] ?? '';
    return SizedBox(
      height: 280,
      child: Stack(fit: StackFit.expand, children: [
        // 背景图 (Backdrop)
        Image.network(
          _imageUrl(itemId, type: 'Backdrop', maxWidth: 1200),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF16213E)),
        ),
        // 渐变遮罩
        Container(decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [const Color(0xFF1A1A2E), Colors.transparent],
        ))),
        // 内容: 海报 + 标题
        Positioned(left: 20, bottom: 20, right: 20, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // 海报
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 120, height: 180,
              child: Image.network(_imageUrl(itemId), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF16213E),
                  child: Icon(_itemIcon(item['Type'] ?? ''), color: Colors.white24, size: 48))),
            ),
          ),
          const SizedBox(width: 16),
          // 标题 + 元信息
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['Name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              if (item['ProductionYear'] != null)
                Text('${item['ProductionYear']}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
              if (item['OfficialRating'] != null)
                Text('${item['OfficialRating']}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
              if (item['CommunityRating'] != null)
                Text('★ ${(item['CommunityRating'] as num).toStringAsFixed(1)}', style: const TextStyle(color: Colors.amber, fontSize: 14)),
            ]),
          ])),
        ])),
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 80, child: Text('$label:', style: const TextStyle(color: Colors.white38, fontSize: 13))),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ]),
    );
  }

  // ============== Series: Seasons + Episodes ==============

  Widget _buildSeasonSelector() {
    if (_seriesSeasons.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(color: Colors.deepPurple, strokeWidth: 2),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('季', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        // 季选择下拉
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedSeasonIndex < _seriesSeasons.length ? _selectedSeasonIndex : 0,
              dropdownColor: const Color(0xFF16213E),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: List.generate(_seriesSeasons.length, (i) => DropdownMenuItem(
                value: i,
                child: Text(_seriesSeasons[i]['Name'] ?? '季 ${i + 1}'),
              )),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedSeasonIndex = val);
                  final seasonId = _seriesSeasons[val]['Id'];
                  _loadSeasonEpisodes(seasonId);
                }
              },
            ),
          ),
        ),
      ]),
    ]);
  }

  Widget _buildEpisodeList() {
    if (_seriesSeasons.isEmpty || _selectedSeasonIndex >= _seriesSeasons.length) return const SizedBox();
    final seasonId = _seriesSeasons[_selectedSeasonIndex]['Id'];
    final episodes = _seasonEpisodes[seasonId];

    if (episodes == null) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(color: Colors.deepPurple, strokeWidth: 2),
      ));
    }

    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: episodes.length,
        itemBuilder: (_, i) {
          final ep = episodes[i];
          final epName = ep['Name'] ?? '';
          final epNum = ep['IndexNumber'];
          final epId = ep['Id'] ?? '';
          final label = epNum != null ? '${i + 1}. Episode $epNum' : '${i + 1}. $epName';

          return GestureDetector(
            onTap: () => _playItem(epId, epName),
            child: Container(
              width: 230, margin: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(fit: StackFit.expand, children: [
                  Image.network(_imageUrl(epId), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: const Color(0xFF16213E),
                      child: const Center(child: Icon(Icons.tv, color: Colors.white24, size: 36)))),
                  // 底部标签
                  Positioned(left: 0, right: 0, bottom: 0, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    color: Colors.black.withOpacity(0.7),
                    child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  )),
                  // 播放图标
                  Positioned.fill(child: Center(
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                    ),
                  )),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
