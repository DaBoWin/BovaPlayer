import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'player_window/desktop_player_window.dart';

// ============== 现代化主题配置 ==============

class AppTheme {
  // 背景色
  static const Color background = Color(0xFFF5F5F5);
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF1A1A2E);

  // 主色调 - 高级黑
  static const Color primary = Color(0xFF1F2937);
  static const Color primaryLight = Color(0xFFF3F4F6);
  static const Color primaryDark = Color(0xFF111827);

  // 文字颜色
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // 功能色
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // 圆角
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  // 阴影
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> cardShadowHover = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

const Color _embyWorkspaceCanvas = Color(0xFFF1F3F6);
const Color _embyWorkspaceSurface = Colors.white;

// ============== 数据模型 ==============

class EmbyServer {
  String name;
  String url;
  String username;
  String password;
  String? accessToken;
  String? userId;

  EmbyServer(
      {required this.name,
      required this.url,
      required this.username,
      this.password = '',
      this.accessToken,
      this.userId});
  Map<String, dynamic> toJson() =>
      {'name': name, 'url': url, 'username': username, 'password': password};
  factory EmbyServer.fromJson(Map<String, dynamic> j) => EmbyServer(
        name: j['name'] ?? '',
        url: j['url'] ?? '',
        username: j['username'] ?? '',
        password: j['password'] ?? '',
      );
}

/// 视图模式 (和 egui 完全一致)
enum EmbyViewMode { serverList, dashboard, browser, itemDetail }

// ============== Emby 主页面 ==============

class EmbyPage extends StatefulWidget {
  final EmbyServer? initialServer; // 可选的初始服务器
  final bool embedded;
  final String? initialItemId;
  final String? initialItemName;
  final bool initialAutoplay;

  const EmbyPage({
    super.key,
    this.initialServer,
    this.embedded = false,
    this.initialItemId,
    this.initialItemName,
    this.initialAutoplay = false,
  });

  @override
  State<EmbyPage> createState() => _EmbyPageState();
}

class _CarouselLogoTitle extends StatefulWidget {
  final List<String> urls;
  final Widget fallback;

  const _CarouselLogoTitle({
    super.key,
    required this.urls,
    required this.fallback,
  });

  @override
  State<_CarouselLogoTitle> createState() => _CarouselLogoTitleState();
}

class _CarouselLogoTitleState extends State<_CarouselLogoTitle> {
  int _urlIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty || _urlIndex >= widget.urls.length) {
      return widget.fallback;
    }

    final imageUrl = widget.urls[_urlIndex];
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) {
        if (_urlIndex >= widget.urls.length - 1) {
          return widget.fallback;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _urlIndex += 1);
        });
        return const SizedBox.shrink();
      },
    );
  }
}

class _EmbyPageState extends State<EmbyPage> {
  // 服务器
  List<EmbyServer> _servers = [];
  EmbyServer? _activeServer;
  bool _isLoading = false;
  String? _errorMsg;
  Timer? _searchTimer;
  bool _handledInitialItemTarget = false;

  PreferredSizeWidget _buildDesktopAppBar({
    required Widget title,
    List<Widget>? actions,
    bool showBackButton = false,
    bool transparent = false,
  }) {
    final bool isDesktop =
        !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

    final bgColor = transparent ? Colors.transparent : AppTheme.cardBackground;
    final fgColor = transparent ? Colors.white : AppTheme.textPrimary;

    if (!isDesktop) {
      return AppBar(
        title: title,
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0,
        actions: actions,
      );
    }

    return PreferredSize(
      preferredSize: const Size.fromHeight(42.0),
      child: DragToMoveArea(
        child: AppBar(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          toolbarHeight: 42.0,
          centerTitle: true,
          // Reserve space on macOS for traffic lights if no back button
          leading: showBackButton
              ? BackButton(color: fgColor)
              : (Platform.isMacOS ? const SizedBox(width: 80) : null),
          leadingWidth: showBackButton ? 56 : (Platform.isMacOS ? 80 : 56),
          title: Padding(
            padding: EdgeInsets.only(
                top: Platform.isMacOS ? 4.0 : 0.0), // Bump title down slightly
            child: DefaultTextStyle(
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                  color: fgColor),
              child: title,
            ),
          ),
          actions: actions
              ?.map((action) => Padding(
                    padding: EdgeInsets.only(
                        top: Platform.isMacOS
                            ? 4.0
                            : 0.0), // Bump actions down slightly to match title
                    child: action,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPageScaffold({
    required Widget body,
    Color backgroundColor = AppTheme.background,
    PreferredSizeWidget? appBar,
    bool extendBodyBehindAppBar = false,
  }) {
    if (widget.embedded) {
      return ColoredBox(
        color: backgroundColor,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      appBar: appBar,
      body: body,
    );
  }

  Widget _buildEmbeddedActionShell({
    required Widget child,
    String? tooltip,
    bool bright = false,
  }) {
    final backgroundColor = bright
        ? Colors.white.withValues(alpha: 0.18)
        : _embyWorkspaceSurface.withValues(alpha: 0.94);

    final button = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: bright
              ? Colors.white.withValues(alpha: 0.18)
              : AppTheme.textPrimary.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: bright ? 0.14 : 0.08),
            blurRadius: bright ? 18 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    if (tooltip == null || tooltip.isEmpty) {
      return button;
    }
    return Tooltip(message: tooltip, child: button);
  }

  Widget _buildEmbeddedActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    bool bright = false,
  }) {
    final foregroundColor = bright ? Colors.white : AppTheme.textPrimary;

    return _buildEmbeddedActionShell(
      bright: bright,
      tooltip: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: foregroundColor),
        splashRadius: 20,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildEmbeddedSectionHeader({
    required String title,
    String? subtitle,
    List<Widget>? actions,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(24, 18, 24, 14),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _embyWorkspaceSurface.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.textPrimary.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    height: 1.05,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions.isNotEmpty) ...[
            const SizedBox(width: 16),
            Row(children: actions),
          ],
        ],
      ),
    );
  }

  void _showWorkspaceSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppTheme.error : const Color(0xFF047857),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
      ),
    );
  }

  Widget _buildEmbeddedEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            color: _embyWorkspaceSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: AppTheme.textPrimary.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryLight,
                ),
                child: Icon(icon, size: 40, color: AppTheme.primary),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDashboardInlineActions() {
    final trailingIcon = widget.initialServer != null
        ? Icons.arrow_back_rounded
        : Icons.menu_rounded;
    final trailingTooltip = widget.initialServer != null ? '返回媒体库' : '切换服务器';

    return [
      _buildEmbeddedActionButton(
        icon: Icons.refresh_rounded,
        tooltip: '刷新',
        bright: true,
        onPressed: () {
          if (_viewMode == EmbyViewMode.dashboard) {
            _loadDashboard();
          } else if (_navigationStack.isNotEmpty) {
            _loadBrowserItems(
              _navigationStack.last[0],
              _navigationStack.last[1],
              recursive: true,
            );
          }
        },
      ),
      const SizedBox(width: 10),
      _buildEmbeddedActionButton(
        icon: trailingIcon,
        tooltip: trailingTooltip,
        bright: true,
        onPressed: _goToServerList,
      ),
    ];
  }

  // 视图模式
  late EmbyViewMode _viewMode;

  // 仪表板
  List<Map<String, dynamic>> _libraries = [];
  Map<String, List<Map<String, dynamic>>> _viewItems = {};
  List<Map<String, dynamic>> _continueWatching = []; // 继续观看
  List<Map<String, dynamic>> _latestItems = []; // 最新添加
  int _carouselIndex = 0; // 轮播图当前索引
  final Color _carouselTitleColor = const Color(0xFFF7E6BF);
  final Color _carouselBodyColor = const Color(0xFFF5EFE3);

  // 浏览器
  List<List<String>> _navigationStack = []; // [[id, name], ...]
  List<Map<String, dynamic>> _browseItems = [];
  bool _isLoadingBrowse = false;
  bool _isGridView = true; // Grid/List 布局切换
  String _sortBy = 'DateCreated'; // 排序方式

  // 详情页
  Map<String, dynamic>? _selectedItem;
  List<Map<String, dynamic>> _seriesSeasons = [];
  Map<String, List<Map<String, dynamic>>> _seasonEpisodes = {};
  int _selectedSeasonIndex = 0;

  // 详情页 - 流格式选择
  List<Map<String, dynamic>> _itemMediaSources = [];
  String? _selectedMediaSourceId;
  int? _selectedAudioStreamIndex;

  // 详情页 - 动态头部文字颜色
  Color _heroTextColor = Colors.black87;
  Color _heroTextSecondary = Colors.black54;

  void _updateHeroTextColor(String imageUrl) async {
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: NetworkImage(imageUrl),
      );
      if (!mounted) return;

      final isLight = scheme.surface.computeLuminance() > 0.5;
      setState(() {
        if (isLight) {
          _heroTextColor = Colors.black87;
          _heroTextSecondary = Colors.black54;
        } else {
          _heroTextColor = Colors.white;
          _heroTextSecondary = Colors.white70;
        }
      });
    } catch (e) {
      debugPrint('Error extracting color scheme for hero text: $e');
    }
  }

  bool _isCjkTitle(String text) {
    return RegExp(r'[\u3400-\u9FFF]').hasMatch(text);
  }

  TextStyle _carouselDisplayTitleStyle(String title) {
    final isCjk = _isCjkTitle(title);
    return TextStyle(
      color: _carouselTitleColor,
      fontSize: isCjk ? 42 : 38,
      height: isCjk ? 1.02 : 0.94,
      fontWeight: isCjk ? FontWeight.w700 : FontWeight.w800,
      letterSpacing: isCjk ? 1.6 : -1.1,
      fontFamily: isCjk ? 'Songti SC' : null,
      fontFamilyFallback: isCjk
          ? const ['STKaiti', 'Kaiti SC', 'Noto Serif CJK SC', 'PingFang SC']
          : const ['Georgia', 'Times New Roman'],
      shadows: const [
        Shadow(
          color: Color.fromRGBO(20, 12, 6, 0.50),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  final ScrollController _browserScrollController = ScrollController();
  final ScrollController _dashboardScrollController = ScrollController();
  final ScrollController _episodeScrollController = ScrollController();
  final PageController _carouselController =
      PageController(viewportFraction: 1.0);

  @override
  void initState() {
    super.initState();
    print('[EmbyPage] initState 开始');

    // 如果有初始服务器，直接设置为加载状态，跳过服务器列表
    if (widget.initialServer != null) {
      _viewMode = EmbyViewMode.dashboard; // 先设置为 dashboard，避免显示服务器列表
      _isLoading = true;
      print('[EmbyPage] 有初始服务器，跳过服务器列表');
    } else {
      _viewMode = EmbyViewMode.serverList;
    }

    _loadServers().then((_) {
      print('[EmbyPage] 服务器加载完成，共 ${_servers.length} 个服务器');

      // 如果有初始服务器，查找匹配的服务器并自动连接
      if (widget.initialServer != null) {
        print('[EmbyPage] 收到初始服务器: ${widget.initialServer!.name}');

        // 在已加载的服务器列表中查找匹配的服务器
        final matchingServer = _servers.firstWhere(
          (s) =>
              s.name == widget.initialServer!.name &&
              s.url == widget.initialServer!.url,
          orElse: () => widget.initialServer!,
        );

        print('[EmbyPage] 自动连接到服务器: ${matchingServer.name}');
        _connectServer(matchingServer);
      }
    }).catchError((e) {
      print('[EmbyPage] 加载服务器失败: $e');
    });
  }

  @override
  void dispose() {
    _browserScrollController.dispose();
    _dashboardScrollController.dispose();
    _episodeScrollController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  // ============== 服务器持久化 ==============

  Future<void> _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('emby_servers');
    if (data != null) {
      final list = jsonDecode(data) as List;
      setState(
          () => _servers = list.map((e) => EmbyServer.fromJson(e)).toList());
    }
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'emby_servers', jsonEncode(_servers.map((s) => s.toJson()).toList()));
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

  Map<String, String> _headers() => {
        'X-Emby-Authorization':
            'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0", Token="${_activeServer?.accessToken ?? ""}"',
        'Content-Type': 'application/json',
      };

  String _imageUrl(String itemId,
      {String type = 'Primary', int maxWidth = 300}) {
    return '${_activeServer!.url}/emby/Items/$itemId/Images/$type?maxWidth=$maxWidth&api_key=${_activeServer!.accessToken}';
  }

  List<String> _carouselLogoUrls(Map<String, dynamic> item) {
    final urls = <String>[];
    final seen = <String>{};

    void addCandidates(String? itemId) {
      final normalizedId = itemId?.toString() ?? '';
      if (normalizedId.isEmpty) return;
      for (final type in const ['LogoLightColor', 'Logo', 'LogoLight']) {
        final url = _imageUrl(normalizedId, type: type, maxWidth: 1000);
        if (seen.add(url)) {
          urls.add(url);
        }
      }
    }

    final imageTags = item['ImageTags'];
    final hasDirectLogo = imageTags is Map && imageTags['Logo'] != null;

    if (hasDirectLogo) {
      addCandidates(item['Id']?.toString());
    }

    final parentLogoItemId = item['ParentLogoItemId']?.toString();
    if (parentLogoItemId != null && parentLogoItemId.isNotEmpty) {
      addCandidates(parentLogoItemId);
    }

    final seriesId = item['SeriesId']?.toString();
    if (seriesId != null && seriesId.isNotEmpty) {
      addCandidates(seriesId);
    }

    return urls;
  }

  Widget _buildCarouselTitle(Map<String, dynamic> item, String title) {
    final logoUrls = _carouselLogoUrls(item);
    final fallback = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Text(
        title,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: _carouselDisplayTitleStyle(title),
      ),
    );

    if (logoUrls.isEmpty) {
      return fallback;
    }

    return SizedBox(
      height: 110,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: _CarouselLogoTitle(
          key: ValueKey('${item['Id']}-logo'),
          urls: logoUrls,
          fallback: fallback,
        ),
      ),
    );
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
    print('[EmbyPage] 开始连接服务器: ${server.name}, URL: ${server.url}');
    setState(() {
      _isLoading = true;
      _errorMsg = null;
      _activeServer = server;
    });
    try {
      final r = await http
          .post(
            Uri.parse('${server.url}/emby/Users/AuthenticateByName'),
            headers: {
              'X-Emby-Authorization':
                  'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0"',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
                {'Username': server.username, 'Pw': server.password}),
          )
          .timeout(const Duration(seconds: 10));

      print('[EmbyPage] 认证响应状态码: ${r.statusCode}');

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        server.accessToken = data['AccessToken'];
        server.userId = data['User']['Id'];
        print('[EmbyPage] 认证成功，切换到 dashboard 模式');
        setState(() {
          _isLoading = false;
          _viewMode = EmbyViewMode.dashboard;
        });
        await _loadDashboard();
        await _openInitialItemIfNeeded();
      } else {
        print('[EmbyPage] 认证失败: ${r.statusCode}');
        setState(() {
          _isLoading = false;
          _errorMsg = '登录失败: 用户名或密码错误';
        });
      }
    } catch (e) {
      print('[EmbyPage] 连接异常: $e');
      setState(() {
        _isLoading = false;
        _errorMsg = '连接失败: $e';
      });
    }
  }

  Future<void> _loadDashboard() async {
    if (_activeServer == null) return;
    await _loadLibraries();
    await _loadContinueWatching();
    await _loadLatestItems();
    for (final lib in _libraries) {
      _loadViewItems(lib['Id'], limit: 12);
    }
  }

  Future<void> _openInitialItemIfNeeded() async {
    final itemId = widget.initialItemId;
    if (_handledInitialItemTarget ||
        itemId == null ||
        itemId.isEmpty ||
        _activeServer == null) {
      return;
    }

    _handledInitialItemTarget = true;

    try {
      final server = _activeServer!;
      final response = await http
          .get(
            Uri.parse('${server.url}/emby/Users/${server.userId}/Items/$itemId'
                '?Fields=Overview,PrimaryImageAspectRatio,ProductionYear,'
                'CommunityRating,OfficialRating,ChildCount,RecursiveItemCount,'
                'DateCreated,MediaSources,ImageTags,ParentLogoItemId,'
                'ParentLogoImageTag,SeriesId,MediaStreams'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return;
      }

      final item = Map<String, dynamic>.from(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );

      if (!mounted) return;
      if (widget.initialAutoplay) {
        await _playItem(
          item['Id']?.toString() ?? itemId,
          widget.initialItemName ?? item['Name']?.toString() ?? 'Unknown',
          item: item,
        );
        return;
      }
      _handleItemClick(item);
    } catch (e) {
      print('[EmbyPage] 打开初始项目失败: $e');
    }
  }

  Future<void> _loadContinueWatching() async {
    try {
      final s = _activeServer!;

      // 尝试方法1: 使用 Resume 端点，按最近播放时间排序
      var url = '${s.url}/emby/Users/${s.userId}/Items/Resume'
          '?Limit=10'
          '&Fields=Overview,PrimaryImageAspectRatio,ProductionYear,UserData'
          '&ImageTypeLimit=1'
          '&EnableImageTypes=Primary,Backdrop,Thumb'
          '&SortBy=DatePlayed'
          '&SortOrder=Descending'
          '&api_key=${s.accessToken}';

      print('[EmbyPage] 加载继续观看 (方法1): $url');

      var r = await http.get(
        Uri.parse(url),
        headers: _headers(),
      );

      print('[EmbyPage] 继续观看响应状态码: ${r.statusCode}');

      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        var items = data['Items'] ?? [];
        print('[EmbyPage] 继续观看项目数量 (方法1): ${items.length}');

        // 如果方法1没有数据，尝试方法2: 使用 IsResumable 过滤器
        if (items.isEmpty) {
          print('[EmbyPage] 方法1无数据，尝试方法2: IsResumable 过滤器');

          url = '${s.url}/emby/Users/${s.userId}/Items'
              '?Filters=IsResumable'
              '&Limit=10'
              '&Recursive=true'
              '&Fields=Overview,PrimaryImageAspectRatio,ProductionYear,UserData'
              '&ImageTypeLimit=1'
              '&EnableImageTypes=Primary,Backdrop,Thumb'
              '&SortBy=DatePlayed'
              '&SortOrder=Descending'
              '&api_key=${s.accessToken}';

          print('[EmbyPage] 加载继续观看 (方法2): $url');

          r = await http.get(
            Uri.parse(url),
            headers: _headers(),
          );

          print('[EmbyPage] 继续观看响应状态码 (方法2): ${r.statusCode}');

          if (r.statusCode == 200) {
            final data2 = jsonDecode(r.body);
            items = data2['Items'] ?? [];
            print('[EmbyPage] 继续观看项目数量 (方法2): ${items.length}');
          }
        }

        // 打印详细的继续观看信息
        if (items.isNotEmpty) {
          print('[EmbyPage] === 继续观看列表详情（按最近播放排序）===');
          for (var i = 0; i < items.length && i < 5; i++) {
            final item = items[i];
            final userData = item['UserData'];
            final playbackPositionTicks =
                userData?['PlaybackPositionTicks'] ?? 0;
            final playedPercentage = userData?['PlayedPercentage'] ?? 0;
            final played = userData?['Played'] ?? false;
            final lastPlayedDate = userData?['LastPlayedDate'];
            print('[EmbyPage] ${i + 1}. ${item['Name']}');
            print('   - 最后播放: $lastPlayedDate');
            print(
                '   - 播放位置: ${(playbackPositionTicks / 10000000).toStringAsFixed(0)}秒');
            print('   - 播放百分比: ${playedPercentage.toStringAsFixed(1)}%');
            print('   - 已看完: $played');
          }
          print('[EmbyPage] ========================');
        }

        setState(() {
          _continueWatching = List<Map<String, dynamic>>.from(items);
        });

        print('[EmbyPage] 继续观看列表已更新: ${_continueWatching.length} 项');
      } else {
        print('[EmbyPage] 继续观看 API 返回错误: ${r.statusCode}');
        print('[EmbyPage] 响应内容: ${r.body}');
      }
    } catch (e) {
      print('[EmbyPage] 加载继续观看失败: $e');
    }
  }

  Future<void> _loadLatestItems() async {
    try {
      final s = _activeServer!;
      final r = await http.get(
        Uri.parse('${s.url}/emby/Users/${s.userId}/Items/Latest'
            '?Limit=10'
            '&Fields=Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,ImageTags,ParentLogoItemId,ParentLogoImageTag,SeriesId'
            '&ImageTypeLimit=1'
            '&EnableImageTypes=Primary,Backdrop,Thumb,Logo'),
        headers: _headers(),
      );
      if (r.statusCode == 200) {
        setState(() {
          _latestItems =
              List<Map<String, dynamic>>.from(jsonDecode(r.body) ?? []);
        });
      }
    } catch (e) {
      print('[EmbyPage] 加载最新项目失败: $e');
    }
  }

  Future<void> _loadLibraries() async {
    try {
      final s = _activeServer!;
      final r = await http.get(
          Uri.parse('${s.url}/emby/Users/${s.userId}/Views'),
          headers: _headers());
      if (r.statusCode == 200) {
        setState(() => _libraries =
            List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []));
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
        final items =
            List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []);
        setState(() => _viewItems[viewId] = items);
      }
    } catch (_) {}
  }

  /// 加载浏览页项目 (和 egui get_items 一致)
  Future<void> _loadBrowserItems(String parentId, String name,
      {bool recursive = false}) async {
    setState(() {
      _isLoadingBrowse = true;
    });
    try {
      final s = _activeServer!;
      final fields =
          'Fields=Overview,PrimaryImageAspectRatio,ProductionYear,CommunityRating,OfficialRating,ChildCount,RecursiveItemCount,DateCreated';

      // 根据 _sortBy 确定 API 排序参数
      String sortBy;
      String sortOrder;
      switch (_sortBy) {
        case 'SortName':
          sortBy = 'SortName';
          sortOrder = 'Ascending';
          break;
        case 'ProductionYear':
          sortBy = 'ProductionYear';
          sortOrder = 'Descending';
          break;
        case 'CommunityRating':
          sortBy = 'CommunityRating';
          sortOrder = 'Descending';
          break;
        case 'DateCreated':
        default:
          sortBy = 'DateCreated';
          sortOrder = 'Descending';
          break;
      }

      String url;
      if (recursive) {
        // 递归模式：穿透子目录，只显示 Movie 和 Series
        url = '${s.url}/emby/Users/${s.userId}/Items'
            '?ParentId=$parentId'
            '&Recursive=true'
            '&IncludeItemTypes=Movie,Series'
            '&SortBy=$sortBy'
            '&SortOrder=$sortOrder'
            '&$fields';
      } else {
        // 非递归模式：Series → Season 或 Season → Episode
        url = '${s.url}/emby/Users/${s.userId}/Items'
            '?ParentId=$parentId'
            '&SortBy=$sortBy'
            '&SortOrder=$sortOrder'
            '&$fields';
      }

      print('[EmbyPage] 加载项目，排序: $sortBy $sortOrder');
      final r = await http.get(Uri.parse(url), headers: _headers());
      if (r.statusCode == 200) {
        setState(() {
          _browseItems = List<Map<String, dynamic>>.from(
              jsonDecode(r.body)['Items'] ?? []);
          _isLoadingBrowse = false;
        });
        print('[EmbyPage] 加载完成，共 ${_browseItems.length} 项');
      }
    } catch (e) {
      print('[EmbyPage] 加载失败: $e');
      setState(() => _isLoadingBrowse = false);
    }
  }

  /// 加载 Series 的 Seasons
  Future<void> _loadSeriesSeasons(String seriesId) async {
    try {
      final s = _activeServer!;
      final r = await http.get(
        Uri.parse(
            '${s.url}/emby/Users/${s.userId}/Items?ParentId=$seriesId&Fields=Overview'),
        headers: _headers(),
      );
      if (r.statusCode == 200) {
        final seasons =
            List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []);
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
        Uri.parse(
            '${s.url}/emby/Users/${s.userId}/Items?ParentId=$seasonId&Fields=Overview,MediaSources&SortBy=IndexNumber&SortOrder=Ascending'),
        headers: _headers(),
      );
      if (r.statusCode == 200) {
        final eps =
            List<Map<String, dynamic>>.from(jsonDecode(r.body)['Items'] ?? []);
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
          _heroTextColor = Colors.black87;
          _heroTextSecondary = Colors.black54;
        });
        _loadSeriesSeasons(item['Id']);
        _updateHeroTextColor(
            _imageUrl(item['Id'], type: 'Backdrop', maxWidth: 400));
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
          _itemMediaSources = [];
          _selectedMediaSourceId = null;
          _selectedAudioStreamIndex = null;
          _heroTextColor = Colors.black87;
          _heroTextSecondary = Colors.black54;
        });
        _loadItemPlaybackInfo(item['Id']);
        final backdropItemId = (type == 'Episode' && item['SeriesId'] != null)
            ? item['SeriesId']
            : item['Id'];
        _updateHeroTextColor(
            _imageUrl(backdropItemId, type: 'Backdrop', maxWidth: 400));
        break;
    }
  }

  // ============== 获取多版本与流信息 ==============
  Future<void> _loadItemPlaybackInfo(String itemId) async {
    try {
      final s = _activeServer!;
      var baseUrl = s.url;
      if (baseUrl.contains(':443')) baseUrl = baseUrl.replaceAll(':443', '');

      final playbackInfoUrl =
          '$baseUrl/Items/$itemId/PlaybackInfo?UserId=${s.userId}&api_key=${s.accessToken}';
      final response = await http
          .post(
            Uri.parse(playbackInfoUrl),
            headers: {'Content-Type': 'application/json', ..._headers()},
            body: jsonEncode({
              'DeviceProfile': {
                'MaxStreamingBitrate': 120000000,
                'MaxStaticBitrate': 100000000,
                'DirectPlayProfiles': [
                  {
                    'Container': 'mp4,m4v,mkv,avi,mov,wmv,asf,webm,flv,ts',
                    'Type': 'Video',
                    'VideoCodec': 'h264,hevc,vp8,vp9,av1,mpeg4,mpeg2video',
                    'AudioCodec': 'aac,mp3,ac3,eac3,dts,flac,opus,vorbis,pcm'
                  }
                ],
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['MediaSources'] != null) {
          final sources = List<Map<String, dynamic>>.from(data['MediaSources']);
          setState(() {
            _itemMediaSources = sources;
            if (sources.isNotEmpty) {
              _selectedMediaSourceId = sources[0]['Id'];
              // 寻找第一条默认音频轨
              final streams = sources[0]['MediaStreams'] as List?;
              if (streams != null) {
                final audioStream = streams.firstWhere(
                  (s) => s['Type'] == 'Audio' && s['IsDefault'] == true,
                  orElse: () => streams.firstWhere((s) => s['Type'] == 'Audio',
                      orElse: () => null),
                );
                if (audioStream != null) {
                  _selectedAudioStreamIndex = audioStream['Index'];
                }
              }
            }
          });
        }
      }
    } catch (e) {
      print('[EmbyPage] 获取 PlaybackInfo 失败: $e');
    }
  }

  // ============== 播放 ==============

  Future<void> _playItem(String itemId, String name,
      {Map<String, dynamic>? item}) async {
    print('[EmbyPage] 准备播放: $name');
    print('[EmbyPage] Item ID: $itemId');

    // 构建完整标题（包含季集信息）
    String fullTitle = name;
    if (item != null) {
      final type = item['Type'];
      if (type == 'Episode') {
        // 电视剧集：使用剧集名称（SeriesName）而不是单集标题
        final seriesName = item['SeriesName'] ?? name; // 剧集名称
        final season = item['ParentIndexNumber'];
        final episode = item['IndexNumber'];

        if (season != null && episode != null) {
          final seasonStr = season.toString().padLeft(2, '0');
          final episodeStr = episode.toString().padLeft(2, '0');
          fullTitle = '$seriesName S${seasonStr}E$episodeStr';
          print('[EmbyPage] 电视剧集，剧集名: $seriesName, 完整标题: $fullTitle');
        }
      } else if (type == 'Movie') {
        // 电影：如果存在发行年份，则追加年份以提高弹幕和字幕匹配的准确率
        final year = item['ProductionYear'];
        if (year != null) {
          fullTitle = '$name ($year)';
          print('[EmbyPage] 电影，原名: $name, 增加年份后标题: $fullTitle');
        }
      }
    }

    // 读取保存的播放位置
    Duration? savedPosition;
    int? startTimeTicks;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'play_position_$itemId';
      final savedSeconds = prefs.getInt(key);
      if (savedSeconds != null && savedSeconds > 5) {
        savedPosition = Duration(seconds: savedSeconds);
        // Emby 使用 Ticks (1 tick = 100 nanoseconds)
        startTimeTicks = savedSeconds * 10000000; // 秒 * 10,000,000 = ticks
        print('[EmbyPage] 找到保存的播放位置: ${savedSeconds}秒 ($startTimeTicks ticks)');
      }
    } catch (e) {
      print('[EmbyPage] 读取播放位置失败: $e');
    }

    final server = _activeServer!;
    var baseUrl = server.url;
    if (baseUrl.contains(':443')) {
      baseUrl = baseUrl.replaceAll(':443', '');
    }

    // 方法1: 使用 PlaybackInfo API 获取正确的播放地址
    String? playbackUrl;
    String? mediaSourceId;

    try {
      final playbackInfoUrl =
          '$baseUrl/Items/$itemId/PlaybackInfo?UserId=${server.userId}&api_key=${server.accessToken}';
      print('[EmbyPage] 获取 PlaybackInfo: $playbackInfoUrl');

      final response = await http
          .post(
            Uri.parse(playbackInfoUrl),
            headers: {
              'Content-Type': 'application/json',
              ..._headers(),
            },
            body: jsonEncode({
              if (_selectedMediaSourceId != null)
                'MediaSourceId': _selectedMediaSourceId,
              if (_selectedAudioStreamIndex != null)
                'AudioStreamIndex': _selectedAudioStreamIndex,
              'DeviceProfile': {
                'MaxStreamingBitrate': 120000000,
                'MaxStaticBitrate': 100000000,
                'MusicStreamingTranscodingBitrate': 384000,
                'DirectPlayProfiles': [
                  {
                    'Container': 'mp4,m4v,mkv,avi,mov,wmv,asf,webm,flv,ts',
                    'Type': 'Video',
                    'VideoCodec': 'h264,hevc,vp8,vp9,av1,mpeg4,mpeg2video',
                    // 移除 eac3, dts, truehd 等需要专利授权或不被支持的音轨编码，迫使 Emby 服务端触发音频降级转码
                    'AudioCodec': 'aac,mp3,ac3,flac,opus,vorbis,pcm'
                  }
                ],
                'TranscodingProfiles': [
                  {
                    'Container': 'ts',
                    'Type': 'Audio',
                    'AudioCodec': 'aac',
                    'Protocol': 'hls',
                    'Context': 'Streaming'
                  },
                  {
                    'Container': 'ts',
                    'Type': 'Video',
                    'AudioCodec': 'aac',
                    'VideoCodec': 'h264,hevc',
                    'Protocol': 'hls',
                    'Context': 'Streaming'
                  }
                ],
                'ContainerProfiles': [],
                'CodecProfiles': [],
                'SubtitleProfiles': [
                  {'Format': 'srt', 'Method': 'External'},
                  {'Format': 'ass', 'Method': 'External'},
                  {'Format': 'vtt', 'Method': 'External'}
                ]
              }
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[EmbyPage] PlaybackInfo 响应状态码: ${response.statusCode}');

        // 打印完整的 PlaybackInfo 响应（查找可能的播放域名）
        print('[EmbyPage] ===== PlaybackInfo 完整响应 =====');
        final playbackInfoKeys = data.keys.toList();
        print('[EmbyPage] PlaybackInfo 顶层字段: $playbackInfoKeys');

        // 检查是否有播放 URL 相关的字段
        if (data['PlaybackUrl'] != null) {
          print('[EmbyPage] PlaybackUrl: ${data['PlaybackUrl']}');
        }
        if (data['StreamUrl'] != null) {
          print('[EmbyPage] StreamUrl: ${data['StreamUrl']}');
        }
        if (data['PlaybackBaseUrl'] != null) {
          print('[EmbyPage] PlaybackBaseUrl: ${data['PlaybackBaseUrl']}');
        }
        print('[EmbyPage] =====================================');

        // 获取 MediaSources
        if (data['MediaSources'] != null &&
            (data['MediaSources'] as List).isNotEmpty) {
          final mediaSource = data['MediaSources'][0];
          mediaSourceId = mediaSource['Id'];

          // 打印完整的 MediaSource 信息
          print('[EmbyPage] ===== MediaSource 完整信息 =====');
          print('[EmbyPage] MediaSource: ${jsonEncode(mediaSource)}');
          print('[EmbyPage] =====================================');

          print('[EmbyPage] MediaSource ID: $mediaSourceId');
          print('[EmbyPage] Path: ${mediaSource['Path']}');
          print('[EmbyPage] Container: ${mediaSource['Container']}');
          print(
              '[EmbyPage] SupportsDirectPlay: ${mediaSource['SupportsDirectPlay']}');
          print(
              '[EmbyPage] SupportsDirectStream: ${mediaSource['SupportsDirectStream']}');
          print(
              '[EmbyPage] SupportsTranscoding: ${mediaSource['SupportsTranscoding']}');
          print(
              '[EmbyPage] DirectStreamUrl: ${mediaSource['DirectStreamUrl']}');
          print('[EmbyPage] TranscodingUrl: ${mediaSource['TranscodingUrl']}');

          // 优先使用 API 返回的 DirectStreamUrl
          if (mediaSource['DirectStreamUrl'] != null &&
              mediaSource['DirectStreamUrl'].toString().isNotEmpty) {
            final directStreamUrl = mediaSource['DirectStreamUrl'].toString();
            final extAudio = _selectedAudioStreamIndex != null
                ? '&AudioStreamIndex=$_selectedAudioStreamIndex'
                : '';
            final extStartTime =
                startTimeTicks != null ? '&StartTimeTicks=$startTimeTicks' : '';
            playbackUrl = directStreamUrl.startsWith('http')
                ? directStreamUrl
                : '$baseUrl$directStreamUrl';

            // 将 Static=true 改为 Static=false 以支持 HTTP Range 请求
            if (playbackUrl.contains('Static=true')) {
              playbackUrl =
                  playbackUrl.replaceAll('Static=true', 'Static=false');
              print('[EmbyPage] 已将 Static=true 改为 Static=false');
            }

            if (!playbackUrl.contains('AudioStreamIndex') &&
                extAudio.isNotEmpty) {
              playbackUrl += extAudio;
            }
            if (!playbackUrl.contains('StartTimeTicks') &&
                extStartTime.isNotEmpty) {
              playbackUrl += extStartTime;
              print(
                  '[EmbyPage] 添加 StartTimeTicks 参数，从 ${savedPosition!.inSeconds}秒 开始播放');
            }
            print('[EmbyPage] 使用 DirectStreamUrl: $playbackUrl');
          }
          // 其次才使用 API 返回的全局转码串流 URL（万一连 HEVC 也不支持，才会生成 HLS 地址）
          else if (mediaSource['SupportsTranscoding'] == true &&
              mediaSource['TranscodingUrl'] != null &&
              mediaSource['TranscodingUrl'].toString().isNotEmpty) {
            final transcodingUrl = mediaSource['TranscodingUrl'].toString();
            final extAudio = _selectedAudioStreamIndex != null
                ? '&AudioStreamIndex=$_selectedAudioStreamIndex'
                : '';
            playbackUrl = transcodingUrl.startsWith('http')
                ? transcodingUrl
                : '$baseUrl$transcodingUrl';
            if (!playbackUrl.contains('AudioStreamIndex') &&
                extAudio.isNotEmpty) {
              playbackUrl += extAudio;
            }
            print(
                '[EmbyPage] 使用 API 返回的 TranscodingUrl (音视频全局转码): $playbackUrl');
          }
          // 再次使用 Path（如果是完整 URL）
          else if (mediaSource['Path'] != null) {
            final path = mediaSource['Path'].toString();
            if (path.startsWith('http')) {
              playbackUrl = path;
              print('[EmbyPage] 使用 MediaSource Path: $playbackUrl');
            }
          }

          // 如果上面都没有，才尝试自己回退构建 URL
          if (playbackUrl == null || playbackUrl.isEmpty) {
            final extAudio = _selectedAudioStreamIndex != null
                ? '&AudioStreamIndex=$_selectedAudioStreamIndex'
                : '';
            final extStartTime =
                startTimeTicks != null ? '&StartTimeTicks=$startTimeTicks' : '';
            if (mediaSource['SupportsDirectPlay'] == true) {
              // 构建 DirectPlay URL - 使用 Static=false 支持 HTTP Range
              playbackUrl = '$baseUrl/Videos/$itemId/stream?'
                  'MediaSourceId=$mediaSourceId&'
                  'Static=false&'
                  'api_key=${server.accessToken}$extAudio$extStartTime';
              print('[EmbyPage] 构建手动 DirectPlay URL: $playbackUrl');
            } else if (mediaSource['SupportsDirectStream'] == true) {
              final container = mediaSource['Container'] ?? 'mkv';
              playbackUrl = '$baseUrl/Videos/$itemId/stream.'
                  '$container?'
                  'MediaSourceId=$mediaSourceId&'
                  'api_key=${server.accessToken}$extAudio$extStartTime';
              print('[EmbyPage] 构建手动 DirectStream URL: $playbackUrl');
            }
          }
        }
      } else {
        print('[EmbyPage] PlaybackInfo API 返回错误: ${response.statusCode}');
        print('[EmbyPage] 响应内容: ${response.body}');
      }
    } catch (e) {
      print('[EmbyPage] PlaybackInfo API 异常: $e');
    }

    // 方法2: 如果 PlaybackInfo 失败，使用最简单的 stream URL
    if (playbackUrl == null || playbackUrl.isEmpty) {
      playbackUrl =
          '$baseUrl/Videos/$itemId/stream?api_key=${server.accessToken}';
      print('[EmbyPage] 使用备用简单 Stream URL: $playbackUrl');
    }

    print('[EmbyPage] 最终播放 URL: $playbackUrl');

    // 构建播放器需要的 HTTP headers（只包含认证信息，不包含 Content-Type）
    final playbackHeaders = <String, String>{
      'X-Emby-Authorization':
          'MediaBrowser Client="BovaPlayer", Device="Flutter", DeviceId="bova-flutter", Version="1.0.0", Token="${server.accessToken}"',
    };

    // 获取字幕列表
    final subtitles = await _fetchSubtitles(itemId);

    // 确保有有效的播放 URL
    if (playbackUrl == null || playbackUrl.isEmpty) {
      if (mounted) {
        _showWorkspaceSnackBar('无法获取播放地址', isError: true);
      }
      return;
    }

    // 使用页面导航进入播放器
    if (mounted) {
      DesktopPlayerLauncher.openPlayer(
        context: context,
        url: playbackUrl!,
        title: fullTitle,
        httpHeaders: playbackHeaders,
        subtitles: subtitles,
        itemId: itemId,
        serverUrl: server.url,
        accessToken: server.accessToken,
        userId: server.userId,
        startPosition: savedPosition,
        startTimeTicks: startTimeTicks,
      ).then((launchMode) {
        if (launchMode != PlayerLaunchMode.inline) {
          return;
        }
        print('[EmbyPage] 播放器关闭，2秒后刷新继续观看');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _loadContinueWatching();
          }
        });
      });
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

      final url =
          '$baseUrl/emby/Items/$itemId?Fields=MediaStreams&api_key=${server.accessToken}';
      final response = await http.get(Uri.parse(url), headers: _headers());

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final mediaStreams = data['MediaStreams'] as List<dynamic>?;

        if (mediaStreams != null) {
          final subtitles = <Map<String, String>>[];

          for (var stream in mediaStreams) {
            if (stream['Type'] == 'Subtitle') {
              final index = stream['Index'] as int;
              final language = stream['Language'] as String? ??
                  stream['DisplayLanguage'] as String? ??
                  'Unknown';
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
                final subtitleUrl =
                    '$baseUrl/Videos/$itemId/$itemId/Subtitles/$index/Stream.srt?api_key=${server.accessToken}';

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
    // 如果是从媒体库进入的（有 initialServer），直接返回上一页
    if (widget.initialServer != null) {
      Navigator.pop(context);
      return;
    }

    // 否则切换到服务器列表
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
        _viewMode = _navigationStack.isEmpty
            ? EmbyViewMode.dashboard
            : EmbyViewMode.browser;
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
      return WillPopScope(
        onWillPop: () async {
          print('[EmbyPage] ========== onWillPop 被调用 ==========');
          print('[EmbyPage] 当前模式: $_viewMode');
          print('[EmbyPage] 导航栈: $_navigationStack');

          // 处理返回逻辑
          switch (_viewMode) {
            case EmbyViewMode.itemDetail:
              print('[EmbyPage] ✓ 从详情页返回');
              _goBack();
              return false;

            case EmbyViewMode.browser:
              print('[EmbyPage] ✓ 从浏览页返回');
              _goBack();
              return false;

            case EmbyViewMode.dashboard:
              print('[EmbyPage] ✓ 从首页返回');
              // 如果是从媒体库进入的，直接返回上一页
              if (widget.initialServer != null) {
                print('[EmbyPage] 返回到媒体库');
                return true;
              }
              // 否则返回到服务器列表
              print('[EmbyPage] 返回到服务器列表');
              _goToServerList();
              return false;

            case EmbyViewMode.serverList:
              if (widget.embedded || widget.initialServer != null) {
                print('[EmbyPage] ✓ 在嵌入式服务器列表页，返回媒体库');
                return true;
              }
              print('[EmbyPage] ✓ 在服务器列表页，显示退出确认');
              final shouldExit = await _showExitConfirmDialog();
              print('[EmbyPage] 用户选择: ${shouldExit ? "退出" : "取消"}');
              return shouldExit;
          }
        },
        child: _buildCurrentView(),
      );
    } catch (e, stackTrace) {
      print('[EmbyPage] 构建页面时出错: $e');
      print('[EmbyPage] 堆栈跟踪: $stackTrace');

      return _buildErrorPage(e);
    }
  }

  Future<bool> _showExitConfirmDialog() async {
    print('[EmbyPage] 显示退出确认对话框');

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 防止点击外部关闭
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: const Text(
          '退出应用',
          style: TextStyle(
              color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          '确定要退出应用吗？',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              print('[EmbyPage] 用户点击取消');
              Navigator.pop(context, false);
            },
            child: const Text('取消',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              print('[EmbyPage] 用户点击退出');
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    print('[EmbyPage] 对话框返回结果: $result');
    return result ?? false;
  }

  Widget _buildCurrentView() {
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
  }

  Widget _buildErrorPage(Object error) {
    final body = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade400, size: 64),
          const SizedBox(height: 16),
          const Text(
            '页面加载失败',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: AppTheme.background, child: body);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Emby'),
        backgroundColor: AppTheme.cardBackground,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: body,
    );
  }

  // ===================================
  //  1) 服务器列表页 - 现代化设计
  // ===================================

  Widget _buildServerListPage() {
    final content =
        _servers.isEmpty ? _buildEmptyServerList() : _buildServerList();

    if (widget.embedded) {
      return ColoredBox(
        color: _embyWorkspaceCanvas,
        child: Column(
          children: [
            _buildEmbeddedSectionHeader(
              title: 'Emby 服务器',
              subtitle: '在媒体库工作区里管理你的 Emby 连接。',
              actions: [
                _buildEmbeddedActionButton(
                  icon: Icons.add_rounded,
                  tooltip: '添加服务器',
                  onPressed: _showAddServerDialog,
                ),
              ],
            ),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildDesktopAppBar(
        title: const Text('BovaPlayer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppTheme.textPrimary),
            onPressed: () => _showAddServerDialog(),
            tooltip: '添加服务器',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: content,
    );
  }

  Widget _buildEmptyServerList() {
    if (widget.embedded) {
      return _buildEmbeddedEmptyState(
        icon: Icons.dns_outlined,
        title: '还没有添加服务器',
        subtitle: '点击右上角按钮添加 Emby 服务器，连接后这里会展示你的媒体世界。',
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryLight,
            ),
            child: const Icon(
              Icons.dns_outlined,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '还没有添加服务器',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击上方按钮添加 Emby 服务器',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
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
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.cardShadow,
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.dns, color: Colors.white, size: 24),
            ),
            title: Text(
              s.name,
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
                Text(
                  s.url,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '用户: ${s.username}',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            trailing: (_isLoading && _activeServer == s)
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                : Icon(Icons.chevron_right, color: AppTheme.textTertiary),
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
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLarge)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppTheme.primary),
              title: const Text('编辑',
                  style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddServerDialog(editIndex: index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppTheme.error),
              title: const Text('删除', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(ctx);
                _removeServer(index);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showAddServerDialog({int? editIndex}) {
    final isEdit = editIndex != null;
    final nameCtrl =
        TextEditingController(text: isEdit ? _servers[editIndex].name : '');
    final urlCtrl = TextEditingController(
        text: isEdit ? _servers[editIndex].url : 'https://');
    final userCtrl =
        TextEditingController(text: isEdit ? _servers[editIndex].username : '');
    final passCtrl =
        TextEditingController(text: isEdit ? _servers[editIndex].password : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          isEdit ? '编辑服务器' : '添加服务器',
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
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 12),
                  ),
                ),
              ],
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
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final url = urlCtrl.text.trim();
              final user = userCtrl.text.trim();
              if (name.isEmpty || url.isEmpty || user.isEmpty) return;
              final server = EmbyServer(
                name: name,
                url: url,
                username: user,
                password: passCtrl.text,
              );
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

  Widget _dialogField(TextEditingController c, String label, String hint,
      {bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle:
            const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        filled: true,
        fillColor: AppTheme.background,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: BorderSide(color: AppTheme.textTertiary.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
      ),
    );
  }

  // ===================================
  //  2) 仪表板 - 现代化设计
  // ===================================
  Widget _buildDashboard() {
    final dashboardBody = ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor:
            MaterialStateProperty.all(AppTheme.primary.withOpacity(0.4)),
        trackBorderColor: MaterialStateProperty.all(Colors.transparent),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
        minThumbLength: 64,
      ),
      child: Scrollbar(
        thumbVisibility: true,
        trackVisibility: false,
        interactive: true,
        thickness: 8,
        radius: const Radius.circular(4),
        controller: _dashboardScrollController,
        child: CustomScrollView(
          controller: _dashboardScrollController,
          slivers: [
            // 1. 全出血轮播横幅 (如果有最新内容)
            if (_latestItems.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildFeaturedCarousel(),
              ),

            // 2. 服务器信息展示 (已移除)

            // 继续观看
            if (_continueWatching.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    '继续观看',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildContinueWatchingRow(),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],

            // 媒体库列表
            for (final lib in _libraries) ...[
              SliverToBoxAdapter(
                child: Container(
                  color: AppTheme.cardBackground,
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                lib['Name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _navigationStack = [
                                    [lib['Id'], lib['Name'] ?? '']
                                  ];
                                  _viewMode = EmbyViewMode.browser;
                                });
                                _loadBrowserItems(lib['Id'], lib['Name'] ?? '',
                                    recursive: true);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Show all',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_ios, size: 12),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: AppTheme.cardBackground,
                  child: _buildViewItemsRow(lib['Id'] ?? ''),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return ColoredBox(
        color: _embyWorkspaceCanvas,
        child: dashboardBody,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: _buildDesktopAppBar(
        title: const Text('BovaPlayer'),
        transparent: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              if (_viewMode == EmbyViewMode.dashboard) {
                _loadDashboard();
              } else {
                _loadBrowserItems(
                    _navigationStack.last[0], _navigationStack.last[1],
                    recursive: true);
              }
            },
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: _goToServerList,
            tooltip: '切换服务器',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: dashboardBody,
    );
  }

  // ============== 轮播横幅 ==============

  Widget _buildFeaturedCarousel() {
    final featuredItems = _latestItems.take(5).toList();
    if (featuredItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 540,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: featuredItems.length,
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() => _carouselIndex = index);
            },
            itemBuilder: (_, i) {
              final item = featuredItems[i];
              final name = item['Name'] ?? '';
              final itemId = item['Id'] ?? '';
              final type = item['Type'] ?? '';
              final overview = (item['Overview'] ?? '').toString().trim();
              final year = item['ProductionYear']?.toString() ?? '';
              final ratingValue = item['CommunityRating'];
              final rating =
                  ratingValue is num ? ratingValue.toStringAsFixed(1) : '';
              final backdropUrl =
                  _imageUrl(itemId, type: 'Backdrop', maxWidth: 1600);

              return GestureDetector(
                onTap: () => _handleItemClick(item),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      backdropUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.primaryLight,
                        child: Icon(
                          _itemIcon(type),
                          color: AppTheme.textTertiary,
                          size: 60,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.transparent,
                              Color.fromRGBO(255, 255, 255, 0.20),
                              Color.fromRGBO(255, 255, 255, 0.74),
                              Color.fromRGBO(255, 255, 255, 1),
                            ],
                            stops: [0.0, 0.44, 0.64, 0.84, 1.0],
                          ).createShader(bounds),
                          blendMode: BlendMode.dstIn,
                          child: Transform.scale(
                            scale: 1.08,
                            child: ImageFiltered(
                              imageFilter:
                                  ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                              child: Image.network(
                                backdropUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF130D08).withValues(alpha: 0.10),
                              Colors.transparent,
                              const Color(0xFF18110B).withValues(alpha: 0.12),
                              AppTheme.background.withValues(alpha: 0.18),
                              AppTheme.background.withValues(alpha: 0.82),
                              AppTheme.background,
                            ],
                            stops: const [0.0, 0.24, 0.52, 0.68, 0.88, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(72, 28, 72, 48),
                        child: Column(
                          children: [
                            const Spacer(flex: 11),
                            if (year.isNotEmpty || rating.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (year.isNotEmpty)
                                      Text(
                                        year,
                                        style: TextStyle(
                                          color: _carouselBodyColor.withValues(
                                              alpha: 0.90),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.8,
                                        ),
                                      ),
                                    if (year.isNotEmpty && rating.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: _carouselBodyColor
                                                .withValues(alpha: 0.72),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    if (rating.isNotEmpty)
                                      Text(
                                        '★ $rating',
                                        style: TextStyle(
                                          color: _carouselBodyColor.withValues(
                                              alpha: 0.90),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            _buildCarouselTitle(item, name),
                            if (overview.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 820),
                                child: Text(
                                  overview,
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _carouselBodyColor.withValues(
                                        alpha: 0.88),
                                    fontSize: 14,
                                    height: 1.72,
                                    fontWeight: FontWeight.w500,
                                    shadows: const [
                                      Shadow(
                                        color: Color.fromRGBO(20, 12, 6, 0.28),
                                        blurRadius: 12,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                featuredItems.length,
                                (dotIndex) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  width: dotIndex == _carouselIndex ? 18 : 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: dotIndex == _carouselIndex
                                        ? _carouselTitleColor
                                        : _carouselBodyColor.withValues(
                                            alpha: 0.34),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (widget.embedded)
            Positioned(
              top: 22,
              left: 24,
              right: 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _activeServer?.name ?? 'Emby',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  Row(children: _buildDashboardInlineActions()),
                ],
              ),
            ),
          if (featuredItems.length > 1)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildCarouselArrow(
                  icon: Icons.chevron_left_rounded,
                  onTap: () {
                    if (_carouselController.page != null &&
                        _carouselController.page! > 0) {
                      _carouselController.previousPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ),
            ),
          if (featuredItems.length > 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildCarouselArrow(
                  icon: Icons.chevron_right_rounded,
                  onTap: () {
                    if (_carouselController.page != null &&
                        _carouselController.page! < featuredItems.length - 1) {
                      _carouselController.nextPage(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCarouselArrow({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white.withValues(alpha: 0.94), size: 30),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildContinueWatchingRow() {
    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _continueWatching.length,
        itemBuilder: (_, i) {
          final item = _continueWatching[i];
          final type = item['Type'] ?? '';
          final itemId = item['Id'] ?? '';
          final seriesName = item['SeriesName'];
          final parentIndex = item['ParentIndexNumber'];
          final indexNumber = item['IndexNumber'];
          final userData = item['UserData'] as Map<String, dynamic>?;
          final playedPercentage = userData?['PlayedPercentage'] ?? 0.0;

          String displayName = item['Name'] ?? '';
          String imageId = itemId;

          if (type == 'Episode' && seriesName != null) {
            displayName = seriesName;
            if (parentIndex != null && indexNumber != null) {
              displayName +=
                  ' s${parentIndex.toString().padLeft(2, '0')}-e${indexNumber.toString().padLeft(2, '0')}';
            }
            if (item['SeriesId'] != null) {
              imageId = item['SeriesId'];
            }
          }

          return GestureDetector(
            onTap: () => _handleItemClick(item),
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 背景图
                    Image.network(
                      _imageUrl(imageId, type: 'Primary', maxWidth: 400),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.primaryLight,
                        child: Icon(
                          _itemIcon(type),
                          color: AppTheme.textTertiary,
                          size: 40,
                        ),
                      ),
                    ),
                    // 渐变遮罩
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                            stops: const [0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // 播放进度条
                    if (playedPercentage > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LinearProgressIndicator(
                          value: playedPercentage / 100,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primary),
                          minHeight: 4,
                        ),
                      ),
                    // 标题和播放按钮
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewItemsRow(String viewId) {
    final items = _viewItems[viewId];
    if (items == null) {
      return SizedBox(
        height: 280,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          itemBuilder: (_, __) => _buildSkeletonCard(),
        ),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _embyWorkspaceSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: AppTheme.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          child: const Text(
            '暂无内容',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
          ),
        ),
      );
    }
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
    final childCount = type == 'Series'
        ? (item['RecursiveItemCount'] ?? item['ChildCount'])
        : item['ChildCount'];

    return GestureDetector(
      onTap: () => _handleItemClick(item),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 海报图片 - 现代化设计
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 背景和图片
                      Container(
                        color: AppTheme.primaryLight,
                        child: Image.network(
                          _imageUrl(itemId, maxWidth: 400),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              _itemIcon(type),
                              color: AppTheme.primary.withOpacity(0.3),
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                      // 渐变遮罩
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.4),
                              ],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 剧集数标签（如果有）
                      if (type == 'Series' && childCount != null)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSmall),
                            ),
                            child: Text(
                              '$childCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 标题
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            // 年份
            if (year.isNotEmpty)
              Text(
                year,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _libraryIcon(String type) {
    switch (type) {
      case 'movies':
        return Icons.movie_outlined;
      case 'tvshows':
        return Icons.tv_rounded;
      case 'music':
        return Icons.music_note_rounded;
      default:
        return Icons.folder_outlined;
    }
  }

  IconData _itemIcon(String type) {
    switch (type) {
      case 'Movie':
      case 'Video':
        return Icons.movie_rounded;
      case 'Episode':
        return Icons.tv_rounded;
      case 'Series':
      case 'BoxSet':
        return Icons.tv_rounded;
      case 'Season':
        return Icons.folder_rounded;
      case 'Folder':
      case 'CollectionFolder':
      case 'UserView':
        return Icons.folder_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  // 骨架屏加载卡片
  Widget _buildSkeletonCard() {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 海报骨架
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.3, end: 1.0),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: AppTheme.textTertiary.withOpacity(0.3),
                      ),
                    );
                  },
                  onEnd: () {
                    // 循环动画
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 标题骨架
          Container(
            height: 14,
            width: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          // 副标题骨架
          Container(
            height: 12,
            width: 60,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================
  //  3) Browser 浏览页 (面包屑导航 + 网格)
  // ===================================

  Widget _buildBrowserPage() {
    final sortMenu = PopupMenuButton<String>(
      icon: const Icon(Icons.sort_rounded),
      tooltip: '排序',
      onSelected: (value) {
        setState(() {
          _sortBy = value;
        });
        if (_navigationStack.isNotEmpty) {
          final current = _navigationStack.last;
          _loadBrowserItems(current[0], current[1], recursive: true);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'DateCreated',
          child: Text('最新添加'),
        ),
        const PopupMenuItem(
          value: 'SortName',
          child: Text('名称'),
        ),
        const PopupMenuItem(
          value: 'ProductionYear',
          child: Text('年份'),
        ),
        const PopupMenuItem(
          value: 'CommunityRating',
          child: Text('评分'),
        ),
      ],
    );

    final browserActions = [
      sortMenu,
      IconButton(
        icon: Icon(
            _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
        tooltip: _isGridView ? '列表视图' : '网格视图',
        onPressed: () {
          setState(() => _isGridView = !_isGridView);
        },
      ),
      IconButton(
        icon: const Icon(Icons.home_rounded),
        tooltip: '首页',
        onPressed: _goToDashboard,
      ),
    ];

    final embeddedBrowserActions = [
      _buildEmbeddedActionShell(
        tooltip: '排序',
        child: PopupMenuButton<String>(
          icon: const Icon(
            Icons.sort_rounded,
            size: 18,
            color: AppTheme.textPrimary,
          ),
          tooltip: '排序',
          padding: EdgeInsets.zero,
          splashRadius: 20,
          onSelected: (value) {
            setState(() {
              _sortBy = value;
            });
            if (_navigationStack.isNotEmpty) {
              final current = _navigationStack.last;
              _loadBrowserItems(current[0], current[1], recursive: true);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'DateCreated',
              child: Text('最新添加'),
            ),
            const PopupMenuItem(
              value: 'SortName',
              child: Text('名称'),
            ),
            const PopupMenuItem(
              value: 'ProductionYear',
              child: Text('年份'),
            ),
            const PopupMenuItem(
              value: 'CommunityRating',
              child: Text('评分'),
            ),
          ],
        ),
      ),
      _buildEmbeddedActionButton(
        icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
        tooltip: _isGridView ? '列表视图' : '网格视图',
        onPressed: () {
          setState(() => _isGridView = !_isGridView);
        },
      ),
      _buildEmbeddedActionButton(
        icon: Icons.home_rounded,
        tooltip: '首页',
        onPressed: _goToDashboard,
      ),
    ];

    final browserBody = Column(
      children: [
        if (_navigationStack.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.cardBackground,
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < _navigationStack.length; i++) ...[
                          if (i > 0)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          InkWell(
                            onTap: i < _navigationStack.length - 1
                                ? () {
                                    setState(() => _navigationStack =
                                        _navigationStack.sublist(0, i + 1));
                                    _loadBrowserItems(
                                      _navigationStack.last[0],
                                      _navigationStack.last[1],
                                      recursive: true,
                                    );
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: i == _navigationStack.length - 1
                                    ? AppTheme.primaryLight
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _navigationStack[i][1],
                                style: TextStyle(
                                  color: i == _navigationStack.length - 1
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: i == _navigationStack.length - 1
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          alignment: Alignment.centerLeft,
          child: Text(
            '共 ${_browseItems.length} 项内容',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: _isLoadingBrowse
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                )
              : _browseItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryLight,
                            ),
                            child: Icon(
                              Icons.folder_open_rounded,
                              size: 40,
                              color:
                                  AppTheme.textTertiary.withValues(alpha: 0.72),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '暂无内容',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '这个目录目前没有可显示的媒体项目。',
                            style: TextStyle(
                              color: AppTheme.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isGridView
                      ? _buildGridView()
                      : _buildListView(),
        ),
      ],
    );

    if (widget.embedded) {
      final currentTitle = _navigationStack.isNotEmpty
          ? _navigationStack.last[1]
          : (_activeServer?.name ?? '媒体内容');
      return ColoredBox(
        color: _embyWorkspaceCanvas,
        child: Column(
          children: [
            _buildEmbeddedSectionHeader(
              title: currentTitle,
              subtitle: _navigationStack.length > 1
                  ? '继续浏览你的媒体目录。'
                  : '按 Emby 目录整理的媒体内容。',
              actions: [
                _buildEmbeddedActionButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: '返回',
                  onPressed: _goBack,
                ),
                const SizedBox(width: 10),
                ...embeddedBrowserActions.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: action,
                  ),
                ),
              ],
            ),
            Expanded(child: browserBody),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBackground,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _goBack,
        ),
        actions: browserActions,
      ),
      body: browserBody,
    );
  }

  Widget _buildGridView() {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor:
            MaterialStateProperty.all(AppTheme.primary.withOpacity(0.4)),
        trackBorderColor: MaterialStateProperty.all(Colors.transparent),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
        minThumbLength: 64,
      ),
      child: Scrollbar(
        thumbVisibility: true, // 强制显示滚动条滑块
        trackVisibility: false, // 隐藏整条灰色背景轨道
        interactive: true,
        thickness: 8,
        radius: const Radius.circular(4),
        controller: _browserScrollController, // 绑定 Controller 才能在桌面端强制显示
        child: GridView.builder(
          controller: _browserScrollController, // 绑定 Controller
          key:
              ValueKey('grid_${_sortBy}_${_browseItems.length}'), // 添加 key 确保重建
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _browseItems.length,
          itemBuilder: (_, i) => _posterCard(_browseItems[i]),
        ),
      ),
    );
  }

  Widget _buildListView() {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thumbColor:
            MaterialStateProperty.all(AppTheme.primary.withOpacity(0.4)),
        trackBorderColor: MaterialStateProperty.all(Colors.transparent),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
        minThumbLength: 64,
      ),
      child: Scrollbar(
        thumbVisibility: true, // 强制显示滚动条滑块
        trackVisibility: false, // 隐藏整条灰色背景轨道
        interactive: true,
        thickness: 8,
        radius: const Radius.circular(4),
        controller: _browserScrollController, // 绑定 Controller
        child: ListView.builder(
          controller: _browserScrollController, // 绑定 Controller
          key:
              ValueKey('list_${_sortBy}_${_browseItems.length}'), // 添加 key 确保重建
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: _browseItems.length,
          itemBuilder: (_, i) {
            final item = _browseItems[i];
            final name = item['Name'] ?? '';
            final year = item['ProductionYear']?.toString() ?? '';
            final itemId = item['Id'] ?? '';
            final type = item['Type'] ?? '';
            final childCount = type == 'Series'
                ? (item['RecursiveItemCount'] ?? item['ChildCount'])
                : item['ChildCount'];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                boxShadow: AppTheme.cardShadow,
              ),
              child: InkWell(
                onTap: () => _handleItemClick(item),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // 缩略图
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSmall),
                        child: SizedBox(
                          width: 60,
                          height: 90,
                          child: Image.network(
                            _imageUrl(itemId),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.primaryLight,
                              child: Icon(
                                _itemIcon(type),
                                color: AppTheme.textTertiary,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            if (year.isNotEmpty)
                              Text(
                                year,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            if (childCount != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$childCount 集',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
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

    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    // 如果是单集，尝试使用剧集ID来获取背景图（单集通常没有独立的 Backdrop）
    final backdropItemId = (type == 'Episode' && item['SeriesId'] != null)
        ? item['SeriesId']
        : itemId;

    final bgColor = const Color(0xFFF5F5F5); // 浅白色，同海报墙底色
    final textColor = Colors.black87;

    return _buildPageScaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 底层：全屏铺开的背景图（结合顶部对齐避免核心内容被裁切）
          Positioned.fill(
            child: Image.network(
              _imageUrl(backdropItemId,
                  type: 'Backdrop', maxWidth: 3840), // 强制获取真4K原图，拒绝服务端压缩
              fit: BoxFit.cover,
              alignment: Alignment.topCenter, // 让海报靠上对齐，展示更多人物头部
              filterQuality: FilterQuality.high, // Flutter 高质量渲染插值
              errorBuilder: (_, __, ___) {
                if (type == 'Episode') {
                  // 单集如果没有Backdrop，退回到它的Primary缩略图
                  return Image.network(
                    _imageUrl(itemId, type: 'Primary', maxWidth: 1920),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (____, _____, ______) =>
                        Container(color: bgColor),
                  );
                }
                return Container(color: bgColor);
              },
            ),
          ),

          // 2. 覆盖层：背景渐变融合
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.20), // 顶部边缘微暗即可
                    Colors.black.withOpacity(0.0), // 顶部到中间全透视海报
                    bgColor.withOpacity(
                        0.0), // 即使到了中部也只留少量透视点，而且必须用bgColor的0透明度避免变黑
                    bgColor, // 缓缓延伸，到底部才会真正完全变成乳白色背景
                    bgColor, // 最底部纯白
                  ],
                  stops: const [
                    0.0,
                    0.15,
                    0.45,
                    0.95,
                    1.0
                  ], // 从 45% 开始向下缓慢渐变泛白，到 95% 才会完全融合
                ),
              ),
            ),
          ),

          // 3. 滚动内容层
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 留出上半部分的空白区域(往下挪到接近中间位置)
              SliverToBoxAdapter(
                child: SizedBox(height: screenHeight * 0.45),
              ),

              // Hero 区域 (左右结构)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Builder(
                    builder: (context) {
                      final bool hasPlayButtons = (type == 'Movie' ||
                          type == 'Episode' ||
                          type == 'Video');

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasPlayButtons)
                            // 左侧：信息和按钮区域 (定宽，带右侧内边距)
                            Container(
                              width: 200,
                              padding: const EdgeInsets.only(right: 32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (year != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: Text(
                                        year,
                                        style: TextStyle(
                                          color: _heroTextSecondary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.play_arrow_rounded,
                                          size: 22),
                                      label: const Text(
                                        '播放',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.85),
                                        foregroundColor: textColor,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _playItem(itemId, name, item: item),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(
                                          Icons.favorite_border_rounded,
                                          size: 20),
                                      label: const Text(
                                        '收藏',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.6),
                                        foregroundColor: textColor,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: () {},
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // 右侧：标题、简介、元信息 (自适应占满剩余宽度)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: _heroTextColor,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                if (overview != null && overview.isNotEmpty)
                                  Text(
                                    overview,
                                    style: TextStyle(
                                      color: _heroTextSecondary,
                                      fontSize: 15,
                                      height: 1.6,
                                    ),
                                    maxLines: 6,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (officialRating != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: _heroTextSecondary
                                                  .withOpacity(0.5)),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          officialRating,
                                          style: TextStyle(
                                            color: _heroTextSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (rating != null)
                                      Text(
                                        '★ ${(rating as num).toStringAsFixed(1)}',
                                        style: TextStyle(
                                            color: _heroTextSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    if (runtimeStr != null)
                                      Text(
                                        runtimeStr,
                                        style: TextStyle(
                                            color: _heroTextSecondary,
                                            fontSize: 13),
                                      ),
                                    if (!hasPlayButtons && year != null)
                                      Text(
                                        year,
                                        style: TextStyle(
                                            color: _heroTextSecondary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold),
                                      ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // 多版本选项与音轨选择
              if (type == 'Movie' || type == 'Episode' || type == 'Video')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMediaSourceSelectors(),
                        const SizedBox(height: 16),
                        _buildStreamInfoCards(),
                      ],
                    ),
                  ),
                ),

              // Series: 季 + 剧集选择器
              if (type == 'Series') ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                    child: _buildSeasonSelector(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
                    child: _buildEpisodeList(),
                  ),
                ),
              ],

              // 详细信息
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '详细信息',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _detailRow('类型', type),
                      if (year != null) _detailRow('年份', year),
                      if (officialRating != null)
                        _detailRow('分级', officialRating),
                      if (runtimeStr != null) _detailRow('时长', runtimeStr),
                      if (rating != null)
                        _detailRow(
                            '评分', '★ ${(rating as num).toStringAsFixed(1)}/10'),
                      if (item['OriginalTitle'] != null)
                        _detailRow('原始标题', item['OriginalTitle']),
                    ],
                  ),
                ),
              ),

              // 底部留白
              SliverToBoxAdapter(
                child: SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 40),
              ),
            ],
          ),

          // 4. 浮动导航按钮 (固定在屏幕上方)
          Positioned(
            top: topPadding + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.black87, size: 18),
                onPressed: _goBack,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(),
              ),
            ),
          ),
          Positioned(
            top: topPadding + 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.more_horiz_rounded,
                    color: Colors.black87, size: 24),
                onPressed: _goToDashboard,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSourceSelectors() {
    if (_itemMediaSources.isEmpty) {
      if (_isLoadingBrowse) {
        return const SizedBox(
            height: 48,
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.textTertiary))));
      }
      return const SizedBox();
    }

    // 取得当前选中的媒体源信息
    final currentSource = _itemMediaSources.firstWhere(
      (s) => s['Id'] == _selectedMediaSourceId,
      orElse: () => _itemMediaSources.first,
    );

    // 从当前媒体源提取音频流
    final streams = currentSource['MediaStreams'] as List? ?? [];
    final audioStreams = streams.where((s) => s['Type'] == 'Audio').toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '播放选项',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdownSelector(
                  icon: Icons.movie_creation_outlined,
                  label: '视频格式',
                  value: _selectedMediaSourceId,
                  items: _itemMediaSources,
                  valueKey: 'Id',
                  displayBuilder: (item) {
                    final name = item['Name'] ?? 'Unknown';
                    final container =
                        item['Container']?.toString().toUpperCase() ?? '';
                    final videoCodec =
                        item['VideoType']?.toString().toUpperCase() ??
                            item['VideoCodec']?.toString().toUpperCase() ??
                            '';

                    List<String> tags = [];
                    if (container.isNotEmpty) tags.add(container);
                    if (videoCodec.isNotEmpty && videoCodec != container)
                      tags.add(videoCodec);

                    if (tags.isNotEmpty) {
                      return '$name (${tags.join(' / ')})';
                    }
                    return name;
                  },
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedMediaSourceId = val;
                        // 切换 Source 后，尝试重置为其默认的 Audio
                        final newSource =
                            _itemMediaSources.firstWhere((s) => s['Id'] == val);
                        final newStreams =
                            newSource['MediaStreams'] as List? ?? [];
                        final newAudio = newStreams.firstWhere(
                          (s) => s['Type'] == 'Audio' && s['IsDefault'] == true,
                          orElse: () => newStreams.firstWhere(
                              (s) => s['Type'] == 'Audio',
                              orElse: () => null),
                        );
                        _selectedAudioStreamIndex = newAudio?['Index'];
                      });
                    }
                  },
                ),
              ),
              if (audioStreams.isNotEmpty) const SizedBox(width: 12),
              if (audioStreams.isNotEmpty)
                Expanded(
                  child: _buildDropdownSelector(
                    icon: Icons.audiotrack_outlined,
                    label: '音频格式',
                    value: _selectedAudioStreamIndex,
                    items: audioStreams,
                    valueKey: 'Index',
                    displayBuilder: (item) {
                      return item['DisplayTitle']?.toString() ?? '未知';
                    },
                    onChanged: (val) {
                      if (val != null)
                        setState(() => _selectedAudioStreamIndex = val);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSelector({
    required IconData icon,
    required String label,
    required dynamic value,
    required List<dynamic> items,
    required String valueKey,
    String? displayKey,
    String Function(dynamic)? displayBuilder,
    required Function(dynamic) onChanged,
  }) {
    if (items.isEmpty) return const SizedBox();

    String getDisplayText(dynamic item) {
      if (displayBuilder != null) return displayBuilder(item);
      if (displayKey != null) return item[displayKey]?.toString() ?? '未知';
      return '未知';
    }

    // 如果只有 1 个选项，展示为文本即可无需下拉交互
    if (items.length == 1) {
      final text = getDisplayText(items[0]);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.black54),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<dynamic>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFFF5F5F5), // 浅白色弹窗背景
              icon: const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: Colors.black54),
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              items: items.map((item) {
                return DropdownMenuItem<dynamic>(
                  value: item[valueKey],
                  child: Text(
                    getDisplayText(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStreamInfoCards() {
    if (_itemMediaSources.isEmpty || _selectedMediaSourceId == null) {
      return const SizedBox();
    }

    final currentSource = _itemMediaSources.firstWhere(
      (s) => s['Id'] == _selectedMediaSourceId,
      orElse: () => _itemMediaSources.first,
    );

    final streams = currentSource['MediaStreams'] as List? ?? [];

    // 我们找出 1 个视频流，选中的音频流，以及全部或选中的字幕流
    final videoStream =
        streams.firstWhere((s) => s['Type'] == 'Video', orElse: () => null);
    final audioStream = streams.firstWhere(
        (s) => s['Type'] == 'Audio' && s['Index'] == _selectedAudioStreamIndex,
        orElse: () {
      return streams.firstWhere((s) => s['Type'] == 'Audio',
          orElse: () => null);
    });

    // 字幕可能有很多，取默认或者第一个
    final subtitleStream = streams.firstWhere(
        (s) => s['Type'] == 'Subtitle' && s['IsDefault'] == true, orElse: () {
      return streams.firstWhere((s) => s['Type'] == 'Subtitle',
          orElse: () => null);
    });

    if (videoStream == null && audioStream == null && subtitleStream == null) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '音视频字幕信息',
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (videoStream != null)
                _buildStreamCard('视频', Icons.videocam_rounded, videoStream),
              if (audioStream != null)
                _buildStreamCard('音频', Icons.music_note_rounded, audioStream),
              if (subtitleStream != null)
                _buildStreamCard('字幕', Icons.subtitles_rounded, subtitleStream),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStreamCard(String title, IconData icon, dynamic stream) {
    if (stream == null || stream is! Map<String, dynamic>)
      return const SizedBox();

    // 提取通用和特定的流属性
    final type = stream['Type'];
    Map<String, String> properties = {};

    void addProp(String key, String? val) {
      if (val != null && val.isNotEmpty) {
        properties[key] = val;
      }
    }

    addProp('标题',
        stream['DisplayTitle']?.toString() ?? stream['Title']?.toString());
    addProp('语言', stream['Language']);
    addProp('编码', stream['Codec']?.toString().toUpperCase());

    if (type == 'Video') {
      addProp('配置文件', stream['Profile']);
      addProp('等级', stream['Level']?.toString());
      if (stream['Width'] != null && stream['Height'] != null) {
        addProp('分辨率', '${stream['Width']}x${stream['Height']}');
      }
      addProp('宽高比', stream['AspectRatio']);
      addProp('隔行扫描', stream['IsInterlaced'] == true ? '是' : '否');
      addProp(
          '帧率',
          stream['RealFrameRate']?.toString() ??
              stream['AverageFrameRate']?.toString());
      if (stream['BitRate'] != null) {
        addProp('比特率', '${(stream['BitRate'] / 1000).round()} kbps');
      }
      addProp('视频范围', stream['VideoRangeType'] ?? stream['VideoRange']);
      addProp('颜色基色', stream['ColorPrimaries']);
      addProp('色域', stream['ColorSpace']);
      addProp('色偏', stream['ColorTransfer']);
      if (stream['BitDepth'] != null) {
        addProp('位深度', '${stream['BitDepth']} bit');
      }
      addProp('像素格式', stream['PixelFormat']);
      addProp('参考帧', stream['RefFrames']?.toString());
    } else if (type == 'Audio') {
      addProp('声道布局', stream['ChannelLayout']);
      if (stream['Channels'] != null) {
        addProp('声道数', '${stream['Channels']} ch');
      }
      if (stream['SampleRate'] != null) {
        addProp('采样率', '${stream['SampleRate']} Hz');
      }
      addProp('隔行扫描', stream['IsInterlaced'] == true ? '是' : '否');
      if (stream['BitRate'] != null) {
        addProp('比特率', '${(stream['BitRate'] / 1000).round()} kbps');
      }
      addProp('默认', stream['IsDefault'] == true ? '是' : '否');
    } else if (type == 'Subtitle') {
      addProp('内嵌标题', stream['Title']);
      addProp('隔行扫描', stream['IsInterlaced'] == true ? '是' : '否');
      addProp('默认', stream['IsDefault'] == true ? '是' : '否');
      addProp('强制', stream['IsForced'] == true ? '是' : '否');
    }

    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...properties.entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${e.key}:',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== Series: Seasons + Episodes ==============

  Widget _buildSeasonSelector() {
    if (_seriesSeasons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '季',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            // 季选择下拉
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedSeasonIndex < _seriesSeasons.length
                      ? _selectedSeasonIndex
                      : 0,
                  dropdownColor: const Color(0xFFF5F5F5), // 浅白弹窗背景
                  iconEnabledColor: Colors.black54,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  items: List.generate(
                    _seriesSeasons.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(_seriesSeasons[i]['Name'] ?? '季 ${i + 1}'),
                    ),
                  ),
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
          ],
        ),
      ],
    );
  }

  Widget _buildEpisodeList() {
    if (_seriesSeasons.isEmpty ||
        _selectedSeasonIndex >= _seriesSeasons.length) {
      return const SizedBox();
    }
    final seasonId = _seriesSeasons[_selectedSeasonIndex]['Id'];
    final episodes = _seasonEpisodes[seasonId];

    if (episodes == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    final bool showScrollButtons = episodes.length > 4;

    return SizedBox(
      height: 180,
      child: Stack(
        children: [
          ListView.builder(
            controller: _episodeScrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(
              horizontal: showScrollButtons ? 56 : 20,
            ),
            itemCount: episodes.length,
            itemBuilder: (_, i) {
              final ep = episodes[i];
              final epName = ep['Name'] ?? '';
              final epNum = ep['IndexNumber'];
              final epId = ep['Id'] ?? '';
              final label = epNum != null ? 'Episode $epNum' : epName;

              return GestureDetector(
                onTap: () => _handleItemClick(ep),
                child: Container(
                  width: 240,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          _imageUrl(epId),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.primaryLight,
                            child: const Center(
                              child: Icon(
                                Icons.tv_rounded,
                                color: AppTheme.textTertiary,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                                stops: const [0.5, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (epName.isNotEmpty && epNum != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  epName,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withOpacity(0.9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (showScrollButtons)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: _buildEpisodeScrollButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _scrollEpisodes(-280),
              ),
            ),
          if (showScrollButtons)
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: _buildEpisodeScrollButton(
                icon: Icons.chevron_right_rounded,
                onTap: () => _scrollEpisodes(280),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _scrollEpisodes(double delta) async {
    if (!_episodeScrollController.hasClients) {
      return;
    }

    final position = _episodeScrollController.position;
    final target = (_episodeScrollController.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _episodeScrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildEpisodeScrollButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Center(
      child: Material(
        color: Colors.white,
        elevation: 6,
        shadowColor: Colors.black.withOpacity(0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              icon,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
