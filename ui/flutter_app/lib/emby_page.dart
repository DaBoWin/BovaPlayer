import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

// ============== 服务器数据模型 ==============

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

// ============== Emby 主页面 ==============

class EmbyPage extends StatefulWidget {
  const EmbyPage({super.key});

  @override
  State<EmbyPage> createState() => _EmbyPageState();
}

class _EmbyPageState extends State<EmbyPage> {
  List<EmbyServer> _servers = [];
  EmbyServer? _activeServer;
  bool _isLoading = false;
  String? _errorMsg;

  // 登录后数据
  bool _isConnected = false;
  List<Map<String, dynamic>> _libraries = [];
  List<Map<String, dynamic>> _resumeItems = [];
  List<Map<String, dynamic>> _latestItems = [];
  List<Map<String, dynamic>> _browseItems = [];
  String _browseLibraryName = '';
  bool _isLoadingBrowse = false;

  VideoPlayerController? _playerController;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  @override
  void dispose() {
    _playerController?.dispose();
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

  void _addServer(EmbyServer server) {
    setState(() => _servers.add(server));
    _saveServers();
  }

  void _removeServer(int index) {
    setState(() => _servers.removeAt(index));
    _saveServers();
  }

  // ============== Emby API ==============

  Map<String, String> _headers(EmbyServer s) => {
    'X-Emby-Authorization': 'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0", Token="${s.accessToken ?? ""}"',
    'Content-Type': 'application/json',
  };

  String _imageUrl(String itemId, {String type = 'Primary', int maxWidth = 300}) {
    return '${_activeServer!.url}/emby/Items/$itemId/Images/$type?maxWidth=$maxWidth&api_key=${_activeServer!.accessToken}';
  }

  Future<void> _connectServer(EmbyServer server) async {
    setState(() { _isLoading = true; _errorMsg = null; _activeServer = server; });

    try {
      final response = await http.post(
        Uri.parse('${server.url}/emby/Users/AuthenticateByName'),
        headers: _headers(server),
        body: jsonEncode({'Username': server.username, 'Pw': server.password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        server.accessToken = data['AccessToken'];
        server.userId = data['User']['Id'];

        setState(() { _isConnected = true; _isLoading = false; });
        await _loadHomePage();
      } else {
        setState(() { _isLoading = false; _errorMsg = '登录失败: 用户名或密码错误'; });
      }
    } catch (e) {
      setState(() { _isLoading = false; _errorMsg = '连接失败: $e'; });
    }
  }

  Future<void> _loadHomePage() async {
    if (_activeServer == null) return;
    await Future.wait([_loadLibraries(), _loadResumeItems(), _loadLatestItems()]);
  }

  Future<void> _loadLibraries() async {
    try {
      final s = _activeServer!;
      final r = await http.get(Uri.parse('${s.url}/emby/Users/${s.userId}/Views'), headers: _headers(s));
      if (r.statusCode == 200) {
        setState(() => _libraries = List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadResumeItems() async {
    try {
      final s = _activeServer!;
      final r = await http.get(
        Uri.parse('${s.url}/emby/Users/${s.userId}/Items/Resume?Limit=10&Fields=Overview,MediaSources'),
        headers: _headers(s),
      );
      if (r.statusCode == 200) {
        setState(() => _resumeItems = List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadLatestItems() async {
    try {
      final s = _activeServer!;
      final r = await http.get(
        Uri.parse('${s.url}/emby/Users/${s.userId}/Items/Latest?Limit=16&Fields=Overview,MediaSources'),
        headers: _headers(s),
      );
      if (r.statusCode == 200) {
        setState(() => _latestItems = List<Map<String, dynamic>>.from(jsonDecode(r.body)));
      }
    } catch (_) {}
  }

  Future<void> _loadLibraryItems(String libraryId, String name) async {
    setState(() { _isLoadingBrowse = true; _browseLibraryName = name; });
    try {
      final s = _activeServer!;
      final r = await http.get(
        Uri.parse('${s.url}/emby/Users/${s.userId}/Items?ParentId=$libraryId&Limit=50&Fields=Overview,MediaSources&SortBy=SortName'),
        headers: _headers(s),
      );
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

  Future<void> _playItem(Map<String, dynamic> item) async {
    final itemId = item['Id'];
    final name = item['Name'] ?? '未知';
    final s = _activeServer!;
    final playUrl = '${s.url}/emby/Videos/$itemId/stream?Static=true&api_key=${s.accessToken}';

    try {
      _playerController?.dispose();
      _playerController = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true, allowBackgroundPlayback: true),
      );
      await _playerController!.initialize();
      await _playerController!.play();

      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => _EmbyPlayerPage(controller: _playerController!, title: name),
        )).then((_) => _playerController?.pause());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('播放失败: $e'), backgroundColor: Colors.red));
    }
  }

  void _disconnect() {
    setState(() {
      _isConnected = false;
      _activeServer?.accessToken = null;
      _activeServer?.userId = null;
      _activeServer = null;
      _libraries = [];
      _resumeItems = [];
      _latestItems = [];
      _browseItems = [];
      _browseLibraryName = '';
    });
  }

  // ============== 页面路由 ==============

  @override
  Widget build(BuildContext context) {
    if (_isConnected && _activeServer != null) {
      if (_browseLibraryName.isNotEmpty) return _buildBrowsePage();
      return _buildHomePage();
    }
    return _buildServerListPage();
  }

  // ===================================
  //  1) 服务器列表页
  // ===================================

  Widget _buildServerListPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Emby 服务器', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _servers.isEmpty ? _buildEmptyServerList() : _buildServerList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        onPressed: () => _showAddServerDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyServerList() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.deepPurple.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.dns_outlined, size: 40, color: Colors.deepPurple.shade200),
          ),
          const SizedBox(height: 20),
          const Text('还没有添加服务器', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('点击右下角 + 添加 Emby 服务器', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
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
            gradient: LinearGradient(
              colors: [Colors.deepPurple.withValues(alpha: 0.15), const Color(0xFF16213E)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white10),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple.withValues(alpha: 0.2),
              ),
              child: Icon(Icons.dns, color: Colors.deepPurple.shade200, size: 22),
            ),
            title: Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(s.url, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                Text('用户: ${s.username}', style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isLoading && _activeServer == s)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepPurple))
                else
                  const Icon(Icons.chevron_right, color: Colors.white24),
              ],
            ),
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white70),
              title: const Text('编辑', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddServerDialog(editIndex: index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('删除', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _removeServer(index);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, '名称', '我的 Emby 服务器'),
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              final user = userCtrl.text.trim();
              if (name.isEmpty || url.isEmpty || user.isEmpty) return;

              final server = EmbyServer(name: name, url: url, username: user, password: passCtrl.text);
              if (isEdit) {
                setState(() => _servers[editIndex] = server);
                _saveServers();
              } else {
                _addServer(server);
              }
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
      controller: c,
      obscureText: obscure,
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
  //  2) 首页仪表板
  // ===================================

  Widget _buildHomePage() {
    final s = _activeServer!;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF16213E),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _disconnect,
            ),
            title: Row(children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.deepPurple, size: 24),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text('${s.username}@${Uri.parse(s.url).host}', style: const TextStyle(fontSize: 11, color: Colors.white38)),
                ],
              ),
            ]),
            actions: [
              IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loadHomePage, tooltip: '刷新'),
            ],
          ),

          if (_resumeItems.isNotEmpty) ...[
            _sectionTitle('继续观看', Icons.play_circle_outline),
            SliverToBoxAdapter(child: _horizontalList(_resumeItems, showProgress: true)),
          ],

          if (_latestItems.isNotEmpty) ...[
            _sectionTitle('最近添加', Icons.new_releases_outlined),
            SliverToBoxAdapter(child: _horizontalList(_latestItems)),
          ],

          _sectionTitle('媒体库', Icons.folder_outlined),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((ctx, i) => _libraryCard(_libraries[i]), childCount: _libraries.length),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, childAspectRatio: 2.2, crossAxisSpacing: 10, mainAxisSpacing: 10),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  SliverToBoxAdapter _sectionTitle(String title, IconData icon) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(children: [
          Icon(icon, color: Colors.deepPurple.shade200, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _horizontalList(List<Map<String, dynamic>> items, {bool showProgress = false}) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _posterCard(items[i], showProgress: showProgress),
      ),
    );
  }

  Widget _posterCard(Map<String, dynamic> item, {bool showProgress = false}) {
    final name = item['Name'] ?? '';
    final year = item['ProductionYear']?.toString() ?? '';
    final itemId = item['Id'] ?? '';
    final type = item['Type'] ?? '';
    double progress = 0;
    if (showProgress) {
      final ticks = item['UserData']?['PlaybackPositionTicks'] ?? 0;
      final runTicks = item['RunTimeTicks'] ?? 1;
      if (runTicks > 0) progress = ticks / runTicks;
    }

    return GestureDetector(
      onTap: () => _playItem(item),
      child: Container(
        width: 120, margin: const EdgeInsets.only(right: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(fit: StackFit.expand, children: [
                Container(
                  color: const Color(0xFF16213E),
                  child: Image.network(_imageUrl(itemId), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Icon(type == 'Movie' ? Icons.movie : Icons.tv, color: Colors.white24, size: 36))),
                ),
                Positioned.fill(child: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.center,
                    colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                  )),
                )),
                if (showProgress && progress > 0)
                  Positioned(left: 0, right: 0, bottom: 0,
                    child: LinearProgressIndicator(value: progress.clamp(0.0, 1.0), backgroundColor: Colors.black45,
                      valueColor: const AlwaysStoppedAnimation(Colors.deepPurple), minHeight: 3)),
              ]),
            ),
          ),
          const SizedBox(height: 6),
          Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (year.isNotEmpty) Text(year, style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _libraryCard(Map<String, dynamic> lib) {
    final name = lib['Name'] ?? '';
    final type = lib['CollectionType'] ?? '';
    final id = lib['Id'] ?? '';
    IconData icon;
    switch (type) {
      case 'movies': icon = Icons.movie_outlined; break;
      case 'tvshows': icon = Icons.tv; break;
      case 'music': icon = Icons.music_note; break;
      default: icon = Icons.folder_outlined;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _loadLibraryItems(id, name),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: [Colors.deepPurple.withValues(alpha: 0.2), const Color(0xFF16213E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 22, color: Colors.deepPurple.shade200),
            const SizedBox(width: 8),
            Flexible(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }

  // ===================================
  //  3) 媒体库浏览页
  // ===================================

  Widget _buildBrowsePage() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(_browseLibraryName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E), foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() { _browseItems = []; _browseLibraryName = ''; })),
      ),
      body: _isLoadingBrowse
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _browseItems.isEmpty
              ? const Center(child: Text('暂无内容', style: TextStyle(color: Colors.white38)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 140, childAspectRatio: 0.55, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: _browseItems.length,
                  itemBuilder: (ctx, i) => _posterCard(_browseItems[i]),
                ),
    );
  }
}

// ============== Emby 播放器页面 ==============

class _EmbyPlayerPage extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  const _EmbyPlayerPage({required this.controller, required this.title});

  @override
  State<_EmbyPlayerPage> createState() => _EmbyPlayerPageState();
}

class _EmbyPlayerPageState extends State<_EmbyPlayerPage> {
  bool _showControls = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    widget.controller.addListener(_listener);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_listener);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _listener() { if (mounted) setState(() {}); }
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.controller.value.isPlaying) setState(() => _showControls = false);
    });
  }

  String _fmt(Duration d) {
    final h = d.inHours; final m = d.inMinutes.remainder(60); final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.controller.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () { setState(() => _showControls = !_showControls); if (_showControls) _startTimer(); },
        child: Stack(children: [
          Center(child: v.isInitialized ? AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(widget.controller)) : const CircularProgressIndicator(color: Colors.white)),
          if (_showControls) Positioned.fill(child: Container(
            color: Colors.black38,
            child: Column(children: [
              SafeArea(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 15), overflow: TextOverflow.ellipsis)),
              ]))),
              const Spacer(),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(icon: const Icon(Icons.replay_10, color: Colors.white, size: 32), onPressed: () => widget.controller.seekTo(v.position - const Duration(seconds: 10))),
                const SizedBox(width: 32),
                IconButton(iconSize: 56, icon: Icon(v.isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.white),
                  onPressed: () { v.isPlaying ? widget.controller.pause() : widget.controller.play(); _startTimer(); }),
                const SizedBox(width: 32),
                IconButton(icon: const Icon(Icons.forward_10, color: Colors.white, size: 32), onPressed: () => widget.controller.seekTo(v.position + const Duration(seconds: 10))),
              ]),
              const Spacer(),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
                Text(_fmt(v.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Expanded(child: SliderTheme(
                  data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24, thumbColor: Colors.white),
                  child: Slider(
                    value: v.position.inMilliseconds.toDouble().clamp(0, v.duration.inMilliseconds.toDouble()),
                    max: v.duration.inMilliseconds > 0 ? v.duration.inMilliseconds.toDouble() : 1,
                    onChanged: (val) => widget.controller.seekTo(Duration(milliseconds: val.toInt()))),
                )),
                Text(_fmt(v.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          )),
        ]),
      ),
    );
  }
}
