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

  // 媒体库
  List<Map<String, dynamic>> _libraries = [];
  List<Map<String, dynamic>> _items = [];
  String _currentLibraryName = '';
  bool _isLoadingItems = false;

  // 播放
  VideoPlayerController? _playerController;
  bool _isPlayingEmby = false;
  String _playingTitle = '';

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
    'X-Emby-Authorization': 'MediaBrowser Client="BovaPlayer", Device="Android", DeviceId="bova-flutter", Version="1.0.0", Token="${_accessToken ?? ""}"',
    'Content-Type': 'application/json',
  };

  Future<void> _login() async {
    final server = _serverController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (server.isEmpty || username.isEmpty) {
      setState(() => _errorMsg = '请输入服务器地址和用户名');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final url = '$server/emby/Users/AuthenticateByName';
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode({
          'Username': username,
          'Pw': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['AccessToken'];
        _userId = data['User']['Id'];
        _serverUrl = server;

        setState(() {
          _isConnected = true;
          _isLoading = false;
        });

        // 加载媒体库
        await _loadLibraries();
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = '登录失败 (${response.statusCode}): 用户名或密码错误';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = '连接失败: $e';
      });
    }
  }

  Future<void> _loadLibraries() async {
    try {
      final url = '$_serverUrl/emby/Users/$_userId/Views';
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _libraries = List<Map<String, dynamic>>.from(data['Items'] ?? []);
        });
      }
    } catch (e) {
      print('加载媒体库失败: $e');
    }
  }

  Future<void> _loadLibraryItems(String libraryId, String name) async {
    setState(() {
      _isLoadingItems = true;
      _currentLibraryName = name;
    });

    try {
      final url = '$_serverUrl/emby/Users/$_userId/Items?ParentId=$libraryId&Limit=50&Fields=Overview,MediaSources';
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _items = List<Map<String, dynamic>>.from(data['Items'] ?? []);
          _isLoadingItems = false;
        });
      }
    } catch (e) {
      print('加载项目失败: $e');
      setState(() => _isLoadingItems = false);
    }
  }

  Future<void> _playItem(Map<String, dynamic> item) async {
    final itemId = item['Id'];
    final name = item['Name'] ?? '未知';

    // 构建播放 URL
    final playUrl = '$_serverUrl/emby/Videos/$itemId/stream?Static=true&api_key=$_accessToken';

    setState(() {
      _isPlayingEmby = true;
      _playingTitle = name;
    });

    try {
      _playerController?.dispose();
      _playerController = VideoPlayerController.networkUrl(
        Uri.parse(playUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: true,
        ),
      );

      await _playerController!.initialize();
      await _playerController!.play();
      setState(() {});

      if (mounted) {
        // 进入播放页面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _EmbyPlayerPage(
              controller: _playerController!,
              title: name,
            ),
          ),
        ).then((_) {
          // 返回时停止播放
          _playerController?.pause();
          setState(() => _isPlayingEmby = false);
        });
      }
    } catch (e) {
      setState(() => _isPlayingEmby = false);
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
      _items = [];
      _currentLibraryName = '';
    });
  }

  // ============== UI ==============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(
          _isConnected ? (_currentLibraryName.isNotEmpty ? _currentLibraryName : 'Emby 媒体库') : 'Emby 连接',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _isConnected && _currentLibraryName.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _items = [];
                  _currentLibraryName = '';
                }),
              )
            : null,
        actions: [
          if (_isConnected)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: '断开连接',
            ),
        ],
      ),
      body: _isConnected ? _buildLibraryView() : _buildLoginView(),
    );
  }

  Widget _buildLoginView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          // Logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purple.shade300],
              ),
            ),
            child: const Icon(Icons.apps, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Emby 媒体服务器',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '连接到你的 Emby 服务器以浏览和播放媒体',
            style: TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // 表单
          _buildTextField(
            controller: _serverController,
            label: '服务器地址',
            hint: 'http://192.168.1.100:8096',
            icon: Icons.dns,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _usernameController,
            label: '用户名',
            hint: '输入用户名',
            icon: Icons.person,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _passwordController,
            label: '密码',
            hint: '输入密码',
            icon: Icons.lock,
            obscure: true,
          ),
          const SizedBox(height: 24),

          // 错误提示
          if (_errorMsg != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                ],
              ),
            ),

          // 登录按钮
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('连接', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.deepPurple),
        filled: true,
        fillColor: const Color(0xFF16213E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple),
        ),
      ),
    );
  }

  Widget _buildLibraryView() {
    if (_currentLibraryName.isNotEmpty) {
      return _buildItemsGrid();
    }
    return _buildLibrariesGrid();
  }

  Widget _buildLibrariesGrid() {
    if (_libraries.isEmpty) {
      return const Center(
        child: Text('没有发现媒体库', style: TextStyle(color: Colors.white54)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _libraries.length,
      itemBuilder: (context, index) {
        final lib = _libraries[index];
        final name = lib['Name'] ?? '未知';
        final type = lib['CollectionType'] ?? '';
        IconData icon;
        switch (type) {
          case 'movies':
            icon = Icons.movie;
            break;
          case 'tvshows':
            icon = Icons.tv;
            break;
          case 'music':
            icon = Icons.music_note;
            break;
          default:
            icon = Icons.folder;
        }

        return InkWell(
          onTap: () => _loadLibraryItems(lib['Id'], name),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.3),
                  const Color(0xFF16213E),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.deepPurple.shade200),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsGrid() {
    if (_isLoadingItems) {
      return const Center(child: CircularProgressIndicator(color: Colors.deepPurple));
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('暂无内容', style: TextStyle(color: Colors.white54)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final name = item['Name'] ?? '';
        final year = item['ProductionYear']?.toString() ?? '';
        final itemId = item['Id'];

        // 封面图 URL
        final imageUrl = '$_serverUrl/emby/Items/$itemId/Images/Primary?maxWidth=200&api_key=$_accessToken';

        return InkWell(
          onTap: () => _playItem(item),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: const Color(0xFF16213E),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.movie, color: Colors.white24, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (year.isNotEmpty)
                Text(year, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        );
      },
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
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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

  void _listener() {
    if (mounted) setState(() {});
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
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
        onTap: () {
          setState(() => _showControls = !_showControls);
          if (_showControls) _startTimer();
        },
        child: Stack(
          children: [
            // 视频
            Center(
              child: v.isInitialized
                  ? AspectRatio(
                      aspectRatio: v.aspectRatio,
                      child: VideoPlayer(widget.controller),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
            ),

            // 控制层
            if (_showControls)
              Positioned.fill(
                child: Container(
                  color: Colors.black26,
                  child: Column(
                    children: [
                      // 顶部
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // 中间按钮
                      IconButton(
                        iconSize: 56,
                        icon: Icon(
                          v.isPlaying ? Icons.pause_circle : Icons.play_circle,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          v.isPlaying ? widget.controller.pause() : widget.controller.play();
                          _startTimer();
                        },
                      ),
                      const Spacer(),
                      // 底部进度
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Text(_fmt(v.position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: v.position.inMilliseconds.toDouble().clamp(0, v.duration.inMilliseconds.toDouble()),
                                max: v.duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                                activeColor: Colors.deepPurple,
                                onChanged: (val) {
                                  widget.controller.seekTo(Duration(milliseconds: val.toInt()));
                                },
                              ),
                            ),
                            Text(_fmt(v.duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
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
