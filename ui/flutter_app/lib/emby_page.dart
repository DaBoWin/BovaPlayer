import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class EmbyPage extends StatefulWidget {
  const EmbyPage({super.key});

  @override
  State<EmbyPage> createState() => _EmbyPageState();
}

class _EmbyPageState extends State<EmbyPage> {
  // 连接状态
  bool _isConnected = false;
  bool _isLoading = false;
  String? _errorMsg;

  // 服务器信息
  final _serverController = TextEditingController(text: 'http://');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _accessToken;
  String? _userId;
  String? _serverUrl;
  String _userName = '';

  // 首页数据
  List<Map<String, dynamic>> _libraries = [];
  List<Map<String, dynamic>> _resumeItems = [];   // 继续观看
  List<Map<String, dynamic>> _latestItems = [];    // 最近添加
  List<Map<String, dynamic>> _browseItems = [];    // 浏览中的媒体库内容
  String _browseLibraryName = '';
  bool _isLoadingBrowse = false;

  // 播放
  VideoPlayerController? _playerController;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _playerController?.dispose();
    super.dispose();
  }

  // ============== Emby API ==============

  Map<String, String> get _headers => {
    'X-Emby-Authorization': 'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0", Token="${_accessToken ?? ""}"',
    'Content-Type': 'application/json',
  };

  String _imageUrl(String itemId, {String type = 'Primary', int maxWidth = 300}) {
    return '$_serverUrl/emby/Items/$itemId/Images/$type?maxWidth=$maxWidth&api_key=$_accessToken';
  }

  Future<void> _login() async {
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (server.isEmpty || username.isEmpty) {
      setState(() => _errorMsg = '请输入服务器地址和用户名');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      final response = await http.post(
        Uri.parse('$server/emby/Users/AuthenticateByName'),
        headers: _headers,
        body: jsonEncode({'Username': username, 'Pw': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['AccessToken'];
        _userId = data['User']['Id'];
        _userName = data['User']['Name'] ?? username;
        _serverUrl = server;

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
    await Future.wait([_loadLibraries(), _loadResumeItems(), _loadLatestItems()]);
  }

  Future<void> _loadLibraries() async {
    try {
      final r = await http.get(Uri.parse('$_serverUrl/emby/Users/$_userId/Views'), headers: _headers);
      if (r.statusCode == 200) {
        setState(() => _libraries = List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadResumeItems() async {
    try {
      final r = await http.get(
        Uri.parse('$_serverUrl/emby/Users/$_userId/Items/Resume?Limit=10&Fields=Overview,MediaSources'),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        setState(() => _resumeItems = List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadLatestItems() async {
    try {
      final r = await http.get(
        Uri.parse('$_serverUrl/emby/Users/$_userId/Items/Latest?Limit=16&Fields=Overview,MediaSources'),
        headers: _headers,
      );
      if (r.statusCode == 200) {
        setState(() => _latestItems = List<Map<String, dynamic>>.from(jsonDecode(r.body)));
      }
    } catch (_) {}
  }

  Future<void> _loadLibraryItems(String libraryId, String name) async {
    setState(() { _isLoadingBrowse = true; _browseLibraryName = name; });
    try {
      final r = await http.get(
        Uri.parse('$_serverUrl/emby/Users/$_userId/Items?ParentId=$libraryId&Limit=50&Fields=Overview,MediaSources&SortBy=SortName'),
        headers: _headers,
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
    final playUrl = '$_serverUrl/emby/Videos/$itemId/stream?Static=true&api_key=$_accessToken';

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
        )).then((_) {
          _playerController?.pause();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _logout() {
    _playerController?.dispose();
    setState(() {
      _isConnected = false;
      _accessToken = null;
      _userId = null;
      _serverUrl = null;
      _libraries = [];
      _resumeItems = [];
      _latestItems = [];
      _browseItems = [];
      _browseLibraryName = '';
    });
  }

  // ============== UI ==============

  @override
  Widget build(BuildContext context) {
    if (!_isConnected) return _buildLoginPage();
    if (_browseLibraryName.isNotEmpty) return _buildBrowsePage();
    return _buildHomePage();
  }

  // ---- 登录页 ----
  Widget _buildLoginPage() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Colors.deepPurple.shade400, Colors.purple.shade300]),
                    boxShadow: [BoxShadow(color: Colors.deepPurple.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 36, color: Colors.white),
                ),
                const SizedBox(height: 20),
                const Text('连接 Emby 服务器', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('输入服务器信息以浏览和播放媒体', style: TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 32),

                _inputField(_serverController, '服务器地址', 'https://your-server:8096', Icons.dns),
                const SizedBox(height: 12),
                _inputField(_usernameController, '用户名', '', Icons.person),
                const SizedBox(height: 12),
                _inputField(_passwordController, '密码', '', Icons.lock, obscure: true),
                const SizedBox(height: 20),

                if (_errorMsg != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),

                SizedBox(
                  width: double.infinity, height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('连接', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField(TextEditingController c, String label, String hint, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        hintStyle: const TextStyle(color: Colors.white12, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.deepPurple.shade200, size: 20),
        filled: true,
        fillColor: const Color(0xFF16213E),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.deepPurple)),
      ),
    );
  }

  // ---- 首页仪表板 ----
  Widget _buildHomePage() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          // 顶部 AppBar
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF16213E),
            foregroundColor: Colors.white,
            title: Row(
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.deepPurple, size: 28),
                const SizedBox(width: 8),
                Text('你好, $_userName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHomePage, tooltip: '刷新'),
              IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: '断开'),
            ],
          ),

          // 继续观看
          if (_resumeItems.isNotEmpty) ...[
            _sectionTitle('继续观看', Icons.play_circle_outline),
            SliverToBoxAdapter(child: _buildHorizontalList(_resumeItems, showProgress: true)),
          ],

          // 最近添加
          if (_latestItems.isNotEmpty) ...[
            _sectionTitle('最近添加', Icons.new_releases_outlined),
            SliverToBoxAdapter(child: _buildHorizontalList(_latestItems)),
          ],

          // 媒体库
          _sectionTitle('媒体库', Icons.folder_outlined),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildLibraryCard(_libraries[i]),
                childCount: _libraries.length,
              ),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 2.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
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
        child: Row(
          children: [
            Icon(icon, color: Colors.deepPurple.shade200, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalList(List<Map<String, dynamic>> items, {bool showProgress = false}) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (ctx, i) => _buildPosterCard(items[i], showProgress: showProgress),
      ),
    );
  }

  Widget _buildPosterCard(Map<String, dynamic> item, {bool showProgress = false}) {
    final name = item['Name'] ?? '';
    final year = item['ProductionYear']?.toString() ?? '';
    final itemId = item['Id'] ?? '';
    final type = item['Type'] ?? '';

    // 播放进度
    double progress = 0;
    if (showProgress) {
      final ticks = item['UserData']?['PlaybackPositionTicks'] ?? 0;
      final runTicks = item['RunTimeTicks'] ?? 1;
      if (runTicks > 0) progress = ticks / runTicks;
    }

    return GestureDetector(
      onTap: () => _playItem(item),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFF16213E),
                      child: Image.network(
                        _imageUrl(itemId),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            type == 'Movie' ? Icons.movie : Icons.tv,
                            color: Colors.white24, size: 36,
                          ),
                        ),
                      ),
                    ),
                    // 播放按钮悬浮
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    // 进度条
                    if (showProgress && progress > 0)
                      Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.black45,
                          valueColor: const AlwaysStoppedAnimation(Colors.deepPurple),
                          minHeight: 3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 标题
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (year.isNotEmpty)
              Text(year, style: const TextStyle(color: Colors.white30, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryCard(Map<String, dynamic> lib) {
    final name = lib['Name'] ?? '未知';
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
            gradient: LinearGradient(
              colors: [Colors.deepPurple.withValues(alpha: 0.2), const Color(0xFF16213E)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: Colors.deepPurple.shade200),
              const SizedBox(width: 8),
              Flexible(
                child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- 媒体库浏览页 ----
  Widget _buildBrowsePage() {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(_browseLibraryName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() { _browseItems = []; _browseLibraryName = ''; }),
        ),
      ),
      body: _isLoadingBrowse
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _browseItems.isEmpty
              ? const Center(child: Text('暂无内容', style: TextStyle(color: Colors.white38)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    childAspectRatio: 0.55,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _browseItems.length,
                  itemBuilder: (ctx, i) => _buildPosterCard(_browseItems[i]),
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
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
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
        child: Stack(
          children: [
            Center(
              child: v.isInitialized
                  ? AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(widget.controller))
                  : const CircularProgressIndicator(color: Colors.white),
            ),
            if (_showControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: Column(
                    children: [
                      // 顶部
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(children: [
                            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                            Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 15), overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                      ),
                      const Spacer(),
                      // 中间
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(icon: const Icon(Icons.replay_10, color: Colors.white, size: 32), onPressed: () {
                            widget.controller.seekTo(v.position - const Duration(seconds: 10));
                          }),
                          const SizedBox(width: 32),
                          IconButton(iconSize: 56, icon: Icon(v.isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.white), onPressed: () {
                            v.isPlaying ? widget.controller.pause() : widget.controller.play(); _startTimer();
                          }),
                          const SizedBox(width: 32),
                          IconButton(icon: const Icon(Icons.forward_10, color: Colors.white, size: 32), onPressed: () {
                            widget.controller.seekTo(v.position + const Duration(seconds: 10));
                          }),
                        ],
                      ),
                      const Spacer(),
                      // 底部进度
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(children: [
                          Text(_fmt(v.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                value: v.position.inMilliseconds.toDouble().clamp(0, v.duration.inMilliseconds.toDouble()),
                                max: v.duration.inMilliseconds > 0 ? v.duration.inMilliseconds.toDouble() : 1,
                                onChanged: (val) => widget.controller.seekTo(Duration(milliseconds: val.toInt())),
                              ),
                            ),
                          ),
                          Text(_fmt(v.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
