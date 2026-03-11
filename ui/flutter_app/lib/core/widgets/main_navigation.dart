import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/domain/entities/user.dart' as auth_entities;
import '../../features/auth/presentation/pages/account_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart'
    as auth_provider;
import '../../features/discover/models/discover_feed.dart';
import '../../features/discover/models/tmdb_media_item.dart';
import '../../features/discover/pages/discover_bookmarks_page.dart';
import '../../features/discover/pages/discover_page.dart';
import '../../features/discover/pages/discover_search_page.dart';
import '../../features/discover/services/discover_bookmark_service.dart';
import '../../features/discover/services/discover_library_resolver_service.dart';
import '../../features/discover/services/tmdb_service.dart';
import '../../services/emby_quick_play_service.dart';
import '../../emby_page.dart';
import '../../features/media_library/models/media_source.dart';
import '../../media_library_page.dart';
import '../../player_screen.dart';
import '../theme/bova_icons.dart';
import '../theme/design_system.dart';
import 'bova_bottom_nav.dart';
import 'desktop_sidebar.dart';
import 'shell_top_bar.dart';

enum _AppSection {
  discover,
  movies,
  shows,
  player,
  library,
  account,
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final GlobalKey<MediaLibraryPageState> _mediaLibraryKey =
      GlobalKey<MediaLibraryPageState>();
  final GlobalKey<NavigatorState> _libraryNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _accountNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _discoverNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _moviesNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _showsNavigatorKey =
      GlobalKey<NavigatorState>();
  final DiscoverLibraryResolverService _discoverLibraryResolver =
      DiscoverLibraryResolverService();
  final DiscoverBookmarkService _discoverBookmarkService =
      DiscoverBookmarkService();
  final EmbyQuickPlayService _embyQuickPlayService = EmbyQuickPlayService();
  final TmdbService _tmdbService = TmdbService();

  final Map<String, Future<List<DiscoverLibraryMatch>>>
      _discoverMatchFutureCache = {};
  final Map<String, TmdbMediaItem> _discoverBookmarksByKey = {};
  final ValueNotifier<List<TmdbMediaItem>> _discoverBookmarksNotifier =
      ValueNotifier<List<TmdbMediaItem>>(const []);

  _AppSection _currentSection = _AppSection.discover;
  bool _isSidebarExpanded = true;
  String? _localAvatarPath;
  String? _desktopOverlayTitle;
  IconData? _desktopOverlayIcon;

  @override
  void initState() {
    super.initState();
    _loadLocalAvatar();
    _loadDiscoverBookmarks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider =
          Provider.of<auth_provider.AuthProvider>(context, listen: false);
      authProvider.addListener(_onAuthStateChanged);
    });
  }

  Future<void> _loadLocalAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('local_avatar_path');
    if (path != null && File(path).existsSync()) {
      setState(() => _localAvatarPath = path);
    }
  }

  Future<void> _loadDiscoverBookmarks() async {
    final bookmarks = await _discoverBookmarkService.loadBookmarks();
    if (!mounted) return;
    setState(() {
      _discoverBookmarksByKey
        ..clear()
        ..addEntries(
          bookmarks.map((item) => MapEntry(_discoverItemKey(item), item)),
        );
      _discoverBookmarksNotifier.value = List.unmodifiable(bookmarks);
    });
  }

  @override
  void dispose() {
    final authProvider =
        Provider.of<auth_provider.AuthProvider>(context, listen: false);
    authProvider.removeListener(_onAuthStateChanged);
    _discoverLibraryResolver.dispose();
    _discoverBookmarksNotifier.dispose();
    super.dispose();
  }

  void _onAuthStateChanged() {
    final authProvider =
        Provider.of<auth_provider.AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      debugPrint('[MainNavigation] 检测到登出，AuthWrapper 将显示登录页');
    }
  }

  Future<bool> _showExitConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            ),
            title: const Text('退出应用'),
            content: const Text('确定要退出 BovaPlayer 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('退出'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _logout() async {
    final authProvider =
        Provider.of<auth_provider.AuthProvider>(context, listen: false);
    await authProvider.logout();
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming next.')),
    );
  }

  void _showWorkspaceSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? DesignSystem.error : const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        ),
      ),
    );
  }

  EmbyServer _embyServerFromSource(MediaSource source) {
    return EmbyServer(
      name: source.name,
      url: source.url,
      username: source.username,
      password: source.password,
      accessToken: source.accessToken,
      userId: source.userId,
    );
  }

  Future<void> _openResolvedDiscoverMatch(
    DiscoverLibraryMatch match, {
    bool autoplay = false,
  }) async {
    final page = EmbyPage(
      initialServer: _embyServerFromSource(match.source),
      embedded: DesignSystem.isDesktop(context),
      initialItemId: match.itemId,
      initialItemName: match.itemName,
      initialAutoplay: autoplay,
    );

    if (DesignSystem.isDesktop(context)) {
      setState(() => _currentSection = _AppSection.library);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = _libraryNavigatorKey.currentState;
        if (navigator == null) return;
        navigator.popUntil((route) => route.isFirst);
        navigator.push(
          MaterialPageRoute(builder: (_) => page),
        );
      });
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  String _discoverItemKey(TmdbMediaItem item) => '${item.mediaType}-${item.id}';

  Future<List<DiscoverLibraryMatch>> _resolveDiscoverMatches(
    TmdbMediaItem item,
  ) {
    return _discoverMatchFutureCache.putIfAbsent(
      _discoverItemKey(item),
      () => _discoverLibraryResolver.resolveItem(item),
    );
  }

  Future<void> _handleDiscoverQuickPlay(
    TmdbMediaItem item,
    DiscoverLibraryMatch match,
  ) async {
    try {
      await _embyQuickPlayService.play(
        context: context,
        source: match.source,
        itemId: match.itemId,
        fallbackTitle: match.itemName.isNotEmpty ? match.itemName : item.title,
      );
    } on EmbyQuickPlayException catch (error) {
      if (!mounted) return;
      _showWorkspaceSnackBar(error.message, isError: true);
    } catch (error) {
      if (!mounted) return;
      _showWorkspaceSnackBar('快速播放失败，请重试', isError: true);
    }
  }

  bool _isBookmarked(TmdbMediaItem item) {
    return _discoverBookmarksByKey.containsKey(_discoverItemKey(item));
  }

  Future<void> _toggleDiscoverBookmark(TmdbMediaItem item) async {
    try {
      final wasBookmarked = _isBookmarked(item);
      final updated = await _discoverBookmarkService.toggleBookmark(item);
      if (!mounted) return;
      setState(() {
        _discoverBookmarksByKey
          ..clear()
          ..addEntries(
            updated.map((entry) => MapEntry(_discoverItemKey(entry), entry)),
          );
        _discoverBookmarksNotifier.value = List.unmodifiable(updated);
      });
      _showWorkspaceSnackBar(
        wasBookmarked ? '已移除书签：${item.title}' : '已加入书签：${item.title}',
      );
    } catch (error) {
      if (!mounted) return;
      _showWorkspaceSnackBar('书签保存失败，请重试', isError: true);
    }
  }

  GlobalKey<NavigatorState>? _currentDiscoverNavigatorKey() {
    switch (_currentSection) {
      case _AppSection.discover:
        return _discoverNavigatorKey;
      case _AppSection.movies:
        return _moviesNavigatorKey;
      case _AppSection.shows:
        return _showsNavigatorKey;
      case _AppSection.player:
      case _AppSection.library:
      case _AppSection.account:
        return null;
    }
  }

  GlobalKey<NavigatorState>? _currentEmbeddedNavigatorKey() {
    switch (_currentSection) {
      case _AppSection.discover:
        return _discoverNavigatorKey;
      case _AppSection.movies:
        return _moviesNavigatorKey;
      case _AppSection.shows:
        return _showsNavigatorKey;
      case _AppSection.library:
        return _libraryNavigatorKey;
      case _AppSection.account:
        return _accountNavigatorKey;
      case _AppSection.player:
        return null;
    }
  }

  bool _shouldShowTopBarBackButton() {
    if (!DesignSystem.isDesktop(context)) return false;
    return _currentEmbeddedNavigatorKey()?.currentState?.canPop() ?? false;
  }

  Future<void> _handleTopBarBack() async {
    final navigator = _currentEmbeddedNavigatorKey()?.currentState;
    if (navigator == null) return;
    await navigator.maybePop();
    if (!mounted) return;
    setState(() {
      if (!(navigator.canPop())) {
        _desktopOverlayTitle = null;
        _desktopOverlayIcon = null;
      }
    });
  }

  Future<void> _openDiscoverWorkspacePage(
    Widget page, {
    String? desktopTitle,
    IconData? desktopIcon,
  }) async {
    if (DesignSystem.isDesktop(context)) {
      final navigator = _currentDiscoverNavigatorKey()?.currentState;
      if (navigator != null) {
        if (mounted) {
          setState(() {
            _desktopOverlayTitle = desktopTitle;
            _desktopOverlayIcon = desktopIcon;
          });
        }
        await navigator.push(MaterialPageRoute(builder: (_) => page));
        if (!mounted) return;
        setState(() {
          if (!navigator.canPop()) {
            _desktopOverlayTitle = null;
            _desktopOverlayIcon = null;
          }
        });
        return;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Future<void> _openDiscoverSearch() async {
    await _openDiscoverWorkspacePage(
      DiscoverSearchPage(
        embedded: DesignSystem.isDesktop(context),
        onExploreItem: _handleDiscoverExplore,
        resolveLibraryMatches: _resolveDiscoverMatches,
        onQuickPlayMatch: _handleDiscoverQuickPlay,
        onToggleBookmark: _toggleDiscoverBookmark,
        isBookmarked: _isBookmarked,
        bookmarkListenable: _discoverBookmarksNotifier,
      ),
      desktopTitle: 'Search',
      desktopIcon: BovaIcons.searchOutline,
    );
  }

  Future<void> _openDiscoverBookmarks() async {
    await _openDiscoverWorkspacePage(
      DiscoverBookmarksPage(
        embedded: DesignSystem.isDesktop(context),
        bookmarksListenable: _discoverBookmarksNotifier,
        imageBuilder: _tmdbService.imageUrl,
        onExploreItem: _handleDiscoverExplore,
        resolveLibraryMatches: _resolveDiscoverMatches,
        onQuickPlayMatch: _handleDiscoverQuickPlay,
        onToggleBookmark: _toggleDiscoverBookmark,
        isBookmarked: _isBookmarked,
      ),
      desktopTitle: 'Bookmarks',
      desktopIcon: BovaIcons.bookmarkOutline,
    );
  }

  Future<void> _handleDiscoverSave(TmdbMediaItem item) async {
    await _toggleDiscoverBookmark(item);
  }

  Future<DiscoverLibraryMatch?> _pickDiscoverLibraryMatch(
    TmdbMediaItem item,
    List<DiscoverLibraryMatch> matches,
  ) async {
    if (matches.isEmpty) return null;
    if (matches.length == 1) return matches.first;

    return showDialog<DiscoverLibraryMatch>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
          ),
          title: const Text('选择进入的媒体库'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: DesignSystem.neutral500,
                      fontSize: DesignSystem.textSm,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...matches.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius:
                          BorderRadius.circular(DesignSystem.radiusLg),
                      onTap: () => Navigator.of(dialogContext).pop(match),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(DesignSystem.radiusLg),
                          border: Border.all(color: DesignSystem.neutral200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                BovaIcons.cloudOutline,
                                color: DesignSystem.neutral700,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    match.source.name,
                                    style: const TextStyle(
                                      fontSize: DesignSystem.textBase,
                                      fontWeight: DesignSystem.weightSemibold,
                                      color: DesignSystem.neutral900,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    match.itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: DesignSystem.textSm,
                                      color: DesignSystem.neutral500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: DesignSystem.neutral400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleDiscoverExplore(TmdbMediaItem item) async {
    final matches = await _discoverLibraryResolver.resolveItem(item);

    if (!mounted) return;

    if (matches.isEmpty) {
      _showWorkspaceSnackBar('没有在已连接的 Emby 媒体库中找到《${item.title}》',
          isError: true);
      return;
    }

    final selectedMatch = await _pickDiscoverLibraryMatch(item, matches);
    if (selectedMatch == null || !mounted) return;

    await _openResolvedDiscoverMatch(selectedMatch);
  }

  void _selectSection(_AppSection section) {
    setState(() {
      _currentSection = section;
      _desktopOverlayTitle = null;
      _desktopOverlayIcon = null;
    });
  }

  Widget _buildAddButton() {
    return PopupMenuButton<String>(
      icon: const Icon(
        BovaIcons.addOutline,
        color: DesignSystem.neutral700,
        size: 22,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignSystem.radiusMd),
      ),
      offset: const Offset(0, 40),
      onSelected: (type) {
        if (type == 'emby') {
          _mediaLibraryKey.currentState?.showAddSourceDialog(SourceType.emby);
        } else if (type == 'smb') {
          _mediaLibraryKey.currentState?.showAddSourceDialog(SourceType.smb);
        } else if (type == 'ftp') {
          _mediaLibraryKey.currentState?.showAddSourceDialog(SourceType.ftp);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'emby',
          child: Row(
            children: [
              Icon(BovaIcons.cloudOutline,
                  size: 18, color: DesignSystem.neutral700),
              SizedBox(width: DesignSystem.space3),
              Text('Emby 服务器'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'smb',
          child: Row(
            children: [
              Icon(BovaIcons.folderOutline,
                  size: 18, color: DesignSystem.neutral700),
              SizedBox(width: DesignSystem.space3),
              Text('SMB 共享'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'ftp',
          child: Row(
            children: [
              Icon(BovaIcons.uploadOutline,
                  size: 18, color: DesignSystem.neutral700),
              SizedBox(width: DesignSystem.space3),
              Text('FTP 服务器'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar(auth_entities.User? user, {double size = 38}) {
    final initial = user?.username?.substring(0, 1).toUpperCase() ??
        user?.email.substring(0, 1).toUpperCase() ??
        '?';

    Color bgColor;
    switch (user?.accountType) {
      case auth_entities.AccountType.pro:
        bgColor = DesignSystem.proGradientStart;
        break;
      case auth_entities.AccountType.lifetime:
        bgColor = DesignSystem.lifetimeGradientStart;
        break;
      default:
        bgColor = DesignSystem.neutral600;
    }

    Widget avatarContent;
    if (_localAvatarPath != null) {
      avatarContent = ClipOval(
        child: Image.file(
          File(_localAvatarPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildDefaultAvatar(initial, bgColor, size),
        ),
      );
    } else {
      avatarContent = _buildDefaultAvatar(initial, bgColor, size);
    }

    if (user?.accountType == auth_entities.AccountType.pro ||
        user?.accountType == auth_entities.AccountType.lifetime) {
      return Container(
        width: size + 4,
        height: size + 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: user?.accountType == auth_entities.AccountType.pro
              ? DesignSystem.proGradient
              : DesignSystem.lifetimeGradient,
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: avatarContent,
        ),
      );
    }

    return avatarContent;
  }

  Widget _buildDefaultAvatar(String initial, Color bgColor, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: DesignSystem.weightSemibold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  DiscoverFeed get _discoverFeed {
    switch (_currentSection) {
      case _AppSection.movies:
        return DiscoverFeed.movies;
      case _AppSection.shows:
        return DiscoverFeed.shows;
      case _AppSection.discover:
      case _AppSection.player:
      case _AppSection.library:
      case _AppSection.account:
        return DiscoverFeed.home;
    }
  }

  String _sectionTitle() {
    if (_desktopOverlayTitle != null) return _desktopOverlayTitle!;
    switch (_currentSection) {
      case _AppSection.discover:
        return 'Home';
      case _AppSection.movies:
        return 'Movies';
      case _AppSection.shows:
        return 'Shows';
      case _AppSection.player:
        return 'Player';
      case _AppSection.library:
        return 'Media Library';
      case _AppSection.account:
        return 'Account';
    }
  }

  IconData _sectionIcon() {
    if (_desktopOverlayIcon != null) return _desktopOverlayIcon!;
    switch (_currentSection) {
      case _AppSection.discover:
        return BovaIcons.homeFilled;
      case _AppSection.movies:
        return BovaIcons.movieFilled;
      case _AppSection.shows:
        return BovaIcons.tvFilled;
      case _AppSection.player:
        return BovaIcons.playerFilled;
      case _AppSection.library:
        return BovaIcons.libraryFilled;
      case _AppSection.account:
        return BovaIcons.personFilled;
    }
  }

  String _profileName(auth_entities.User? user) {
    final raw = user?.username?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final email = user?.email.trim();
    if (email == null || email.isEmpty) return 'Guest';
    return email.split('@').first;
  }

  String _profileSubtitle() {
    switch (_currentSection) {
      case _AppSection.discover:
      case _AppSection.movies:
      case _AppSection.shows:
        return 'Discovering';
      case _AppSection.player:
        return 'Watching';
      case _AppSection.library:
        return 'Browsing';
      case _AppSection.account:
        return 'Managing account';
    }
  }

  List<DesktopSidebarDestination> _buildDestinations() {
    return [
      DesktopSidebarDestination(
        label: 'Home',
        icon: BovaIcons.homeOutline,
        activeIcon: BovaIcons.homeFilled,
        isSelected: _currentSection == _AppSection.discover,
        onTap: () => _selectSection(_AppSection.discover),
      ),
      DesktopSidebarDestination(
        label: 'Movies',
        icon: BovaIcons.movieOutline,
        activeIcon: BovaIcons.movieFilled,
        isSelected: _currentSection == _AppSection.movies,
        onTap: () => _selectSection(_AppSection.movies),
      ),
      DesktopSidebarDestination(
        label: 'Shows',
        icon: BovaIcons.tvOutline,
        activeIcon: BovaIcons.tvFilled,
        isSelected: _currentSection == _AppSection.shows,
        onTap: () => _selectSection(_AppSection.shows),
      ),
      DesktopSidebarDestination(
        label: 'Player',
        icon: BovaIcons.playerOutline,
        activeIcon: BovaIcons.playerFilled,
        isSelected: _currentSection == _AppSection.player,
        onTap: () => _selectSection(_AppSection.player),
      ),
      DesktopSidebarDestination(
        label: 'Media Library',
        icon: BovaIcons.libraryOutline,
        activeIcon: BovaIcons.libraryFilled,
        isSelected: _currentSection == _AppSection.library,
        onTap: () => _selectSection(_AppSection.library),
      ),
      DesktopSidebarDestination(
        label: 'Account',
        icon: BovaIcons.personOutline,
        activeIcon: BovaIcons.personFilled,
        isSelected: _currentSection == _AppSection.account,
        onTap: () => _selectSection(_AppSection.account),
      ),
    ];
  }

  List<Widget> _buildTopActions() {
    if (_currentSection == _AppSection.library) {
      return [
        _TopActionButton(
          icon: BovaIcons.refreshOutline,
          onTap: () => _mediaLibraryKey.currentState?.refreshAndSync(),
          tooltip: '刷新并同步',
        ),
        _buildAddButton(),
      ];
    }

    if (_currentSection == _AppSection.account) {
      return const [];
    }

    if (_currentSection == _AppSection.player) {
      return [
        _TopActionButton(
          icon: BovaIcons.searchOutline,
          onTap: _openDiscoverSearch,
          tooltip: '搜索媒体',
        ),
      ];
    }

    return [
      _TopActionButton(
        icon: BovaIcons.searchOutline,
        onTap: _openDiscoverSearch,
        tooltip: 'Search',
      ),
      const SizedBox(width: 10),
      _TopActionButton(
        icon: BovaIcons.bookmarkOutline,
        onTap: _openDiscoverBookmarks,
        tooltip: 'Bookmarks',
      ),
      const SizedBox(width: 10),
      _TopActionButton(
        icon: BovaIcons.bellOutline,
        onTap: () => _showComingSoon('Notifications'),
        tooltip: 'Notifications',
      ),
    ];
  }

  Widget _buildEmbeddedNavigator({
    required GlobalKey<NavigatorState> navigatorKey,
    required Widget child,
  }) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => child),
    );
  }

  int get _desktopIndex {
    switch (_currentSection) {
      case _AppSection.discover:
        return 0;
      case _AppSection.movies:
        return 1;
      case _AppSection.shows:
        return 2;
      case _AppSection.player:
        return 3;
      case _AppSection.library:
        return 4;
      case _AppSection.account:
        return 5;
    }
  }

  Widget _buildDesktopContent() {
    return IndexedStack(
      index: _desktopIndex,
      children: [
        _buildEmbeddedNavigator(
          navigatorKey: _discoverNavigatorKey,
          child: DiscoverPage(
            feed: DiscoverFeed.home,
            onExploreItem: _handleDiscoverExplore,
            resolveLibraryMatches: _resolveDiscoverMatches,
            onQuickPlayMatch: _handleDiscoverQuickPlay,
            onSaveItem: _handleDiscoverSave,
            isBookmarked: _isBookmarked,
            bookmarkListenable: _discoverBookmarksNotifier,
          ),
        ),
        _buildEmbeddedNavigator(
          navigatorKey: _moviesNavigatorKey,
          child: DiscoverPage(
            feed: DiscoverFeed.movies,
            onExploreItem: _handleDiscoverExplore,
            resolveLibraryMatches: _resolveDiscoverMatches,
            onQuickPlayMatch: _handleDiscoverQuickPlay,
            onSaveItem: _handleDiscoverSave,
            isBookmarked: _isBookmarked,
            bookmarkListenable: _discoverBookmarksNotifier,
          ),
        ),
        _buildEmbeddedNavigator(
          navigatorKey: _showsNavigatorKey,
          child: DiscoverPage(
            feed: DiscoverFeed.shows,
            onExploreItem: _handleDiscoverExplore,
            resolveLibraryMatches: _resolveDiscoverMatches,
            onQuickPlayMatch: _handleDiscoverQuickPlay,
            onSaveItem: _handleDiscoverSave,
            isBookmarked: _isBookmarked,
            bookmarkListenable: _discoverBookmarksNotifier,
          ),
        ),
        PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final shouldExit = await _showExitConfirmDialog();
            if (shouldExit && mounted) {
              Navigator.of(context).maybePop();
            }
          },
          child: const PlayerScreen(),
        ),
        _buildEmbeddedNavigator(
          navigatorKey: _libraryNavigatorKey,
          child: MediaLibraryPage(
            key: _mediaLibraryKey,
            embedded: true,
          ),
        ),
        _buildEmbeddedNavigator(
          navigatorKey: _accountNavigatorKey,
          child: const AccountPage(embedded: true),
        ),
      ],
    );
  }

  Widget _buildMobileCurrentPage() {
    switch (_currentSection) {
      case _AppSection.discover:
      case _AppSection.movies:
      case _AppSection.shows:
        return DiscoverPage(
          key: ValueKey(_discoverFeed),
          feed: _discoverFeed,
          onExploreItem: _handleDiscoverExplore,
          resolveLibraryMatches: _resolveDiscoverMatches,
          onQuickPlayMatch: _handleDiscoverQuickPlay,
          onSaveItem: _handleDiscoverSave,
          isBookmarked: _isBookmarked,
          bookmarkListenable: _discoverBookmarksNotifier,
        );
      case _AppSection.player:
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final shouldExit = await _showExitConfirmDialog();
            if (shouldExit && mounted) {
              Navigator.of(context).maybePop();
            }
          },
          child: const PlayerScreen(),
        );
      case _AppSection.library:
        return MediaLibraryPage(key: _mediaLibraryKey);
      case _AppSection.account:
        return const AccountPage(embedded: true);
    }
  }

  Widget _buildMobileTitleWidget(auth_entities.User? user) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: DesignSystem.neutral200.withValues(alpha: 0.92),
            ),
            boxShadow: DesignSystem.shadowSm,
          ),
          child: Icon(
            _sectionIcon(),
            size: 17,
            color: const Color(0xFFE11D48),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sectionTitle(),
              style: const TextStyle(
                color: DesignSystem.neutral900,
                fontSize: DesignSystem.textBase,
                fontWeight: DesignSystem.weightSemibold,
                letterSpacing: -0.3,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _profileName(user),
              style: const TextStyle(
                color: DesignSystem.neutral500,
                fontSize: DesignSystem.textXs,
                fontWeight: DesignSystem.weightMedium,
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildMobileTopActions() {
    if (_currentSection == _AppSection.library) {
      return [
        _TopActionButton(
          icon: BovaIcons.refreshOutline,
          onTap: () => _mediaLibraryKey.currentState?.refreshAndSync(),
          tooltip: '刷新并同步',
          size: 40,
          iconSize: 19,
          radius: 14,
        ),
        const SizedBox(width: 8),
        _buildAddButton(),
      ];
    }

    if (_currentSection == _AppSection.player ||
        _currentSection == _AppSection.account) {
      return const [];
    }

    return [
      _TopActionButton(
        icon: BovaIcons.searchOutline,
        onTap: _openDiscoverSearch,
        tooltip: '搜索',
        size: 40,
        iconSize: 19,
        radius: 14,
      ),
      const SizedBox(width: 8),
      _TopActionButton(
        icon: BovaIcons.bookmarkOutline,
        onTap: _openDiscoverBookmarks,
        tooltip: '书签',
        size: 40,
        iconSize: 19,
        radius: 14,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<auth_provider.AuthProvider>(context);
    final user = authProvider.user;
    final isDesktop = DesignSystem.isDesktop(context);

    if (!isDesktop) {
      return _buildMobileScaffold();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              DesktopSidebar(
                isExpanded: _isSidebarExpanded,
                profileName: _profileName(user),
                profileSubtitle: _profileSubtitle(),
                avatar: _buildAvatar(user, size: 52),
                destinations: _buildDestinations(),
                onToggle: () {
                  setState(() => _isSidebarExpanded = !_isSidebarExpanded);
                },
                onLogoutTap: _logout,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF111827).withValues(alpha: 0.06),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: Column(
                      children: [
                        ShellTopBar(
                          title: _sectionTitle(),
                          sectionIcon: _sectionIcon(),
                          onBack: _shouldShowTopBarBackButton()
                              ? _handleTopBarBack
                              : null,
                          actions: _buildTopActions(),
                        ),
                        Expanded(
                          child: ColoredBox(
                            color: const Color(0xFFF9FAFB),
                            child: _buildDesktopContent(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileScaffold() {
    final authProvider = Provider.of<auth_provider.AuthProvider>(context);
    final user = authProvider.user;
    final mobileTopActions = _buildMobileTopActions();
    final currentPage = AnimatedSwitcher(
      duration: DesignSystem.durationNormal,
      switchInCurve: DesignSystem.easeOutQuart,
      switchOutCurve: DesignSystem.easeOutQuart,
      child: _buildMobileCurrentPage(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: DesignSystem.neutral200,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                child: Row(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _buildMobileTitleWidget(user),
                    ),
                    const Spacer(),
                    if (mobileTopActions.isNotEmpty) ...[
                      ...mobileTopActions,
                    ] else ...[
                      const SizedBox.shrink(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
        ),
        child: currentPage,
      ),
      bottomNavigationBar: BovaBottomNav(
        currentIndex: switch (_currentSection) {
          _AppSection.player => 1,
          _AppSection.library => 2,
          _ => 0,
        },
        onTap: (index) {
          setState(() {
            _currentSection = switch (index) {
              1 => _AppSection.player,
              2 => _AppSection.library,
              _ => _AppSection.discover,
            };
          });
        },
        items: const [
          BovaBottomNavItem(
            icon: BovaIcons.homeOutline,
            activeIcon: BovaIcons.homeFilled,
            label: '发现',
          ),
          BovaBottomNavItem(
            icon: BovaIcons.playerOutline,
            activeIcon: BovaIcons.playerFilled,
            label: '播放',
          ),
          BovaBottomNavItem(
            icon: BovaIcons.libraryOutline,
            activeIcon: BovaIcons.libraryFilled,
            label: '媒体库',
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.size = 44,
    this.iconSize = 21,
    this.radius = 16,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: Color(0xFFF0F1F4)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: const Color(0xFFE11D48)),
          ),
        ),
      ),
    );
  }
}
