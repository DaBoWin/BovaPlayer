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
import '../../features/settings/pages/settings_page.dart';
import '../../services/emby_quick_play_service.dart';
import '../../emby_page.dart' hide AppTheme;
import '../../features/media_library/models/media_source.dart';
import '../../media_library_page.dart';
import '../../player_screen.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
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
  bool _showSettings = false;
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
    final l = S.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            ),
            title: Text(l.exitAppTitle),
            content: Text(l.exitAppMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.exit),
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
    final l = S.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.comingSoon(label))),
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
      _showWorkspaceSnackBar(S.of(context).quickPlayFailed, isError: true);
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
      final l = S.of(context);
      _showWorkspaceSnackBar(
        wasBookmarked ? l.bookmarkRemoved(item.title) : l.bookmarkAdded(item.title),
      );
    } catch (error) {
      if (!mounted) return;
      _showWorkspaceSnackBar(S.of(context).bookmarkSaveFailed, isError: true);
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
          title: Text(S.of(context).selectLibrary),
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
      _showWorkspaceSnackBar(S.of(context).discoverNotFoundInLibrary(item.title),
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
      _showSettings = false;
      _desktopOverlayTitle = null;
      _desktopOverlayIcon = null;
    });
  }

  Widget _buildAddButton() {
    return PopupMenuButton<String>(
      icon: const Icon(
        BovaIcons.addOutline,
        color: Color(0xFFE11D48),
        size: 21,
      ),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.white),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF0F1F4)),
          ),
        ),
        fixedSize: WidgetStateProperty.all(const Size(44, 44)),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
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
      itemBuilder: (ctx) {
        final l = S.of(ctx);
        return [
          PopupMenuItem(
            value: 'emby',
            child: Row(
              children: [
                Icon(BovaIcons.cloudOutline,
                    size: 18, color: Theme.of(ctx).iconTheme.color),
                const SizedBox(width: DesignSystem.space3),
                Text(l.addEmbyServer),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'smb',
            child: Row(
              children: [
                Icon(BovaIcons.folderOutline,
                    size: 18, color: Theme.of(ctx).iconTheme.color),
                const SizedBox(width: DesignSystem.space3),
                Text(l.addSmbShare),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'ftp',
            child: Row(
              children: [
                Icon(BovaIcons.uploadOutline,
                    size: 18, color: Theme.of(ctx).iconTheme.color),
                const SizedBox(width: DesignSystem.space3),
                Text(l.addFtpServer),
              ],
            ),
          ),
        ];
      },
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
    final l = S.of(context);
    switch (_currentSection) {
      case _AppSection.discover:
        return l.navHome;
      case _AppSection.movies:
        return l.navMovies;
      case _AppSection.shows:
        return l.navShows;
      case _AppSection.player:
        return l.navPlayer;
      case _AppSection.library:
        return l.navMediaLibrary;
      case _AppSection.account:
        return l.navAccount;
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
    final l = S.of(context);
    switch (_currentSection) {
      case _AppSection.discover:
      case _AppSection.movies:
      case _AppSection.shows:
        return l.profileDiscovering;
      case _AppSection.player:
        return l.profileWatching;
      case _AppSection.library:
        return l.profileBrowsing;
      case _AppSection.account:
        return l.profileManagingAccount;
    }
  }

  List<DesktopSidebarDestination> _buildDestinations() {
    final l = S.of(context);
    return [
      DesktopSidebarDestination(
        label: l.navHome,
        icon: BovaIcons.homeOutline,
        activeIcon: BovaIcons.homeFilled,
        isSelected: _currentSection == _AppSection.discover,
        onTap: () => _selectSection(_AppSection.discover),
      ),
      DesktopSidebarDestination(
        label: l.navMovies,
        icon: BovaIcons.movieOutline,
        activeIcon: BovaIcons.movieFilled,
        isSelected: _currentSection == _AppSection.movies,
        onTap: () => _selectSection(_AppSection.movies),
      ),
      DesktopSidebarDestination(
        label: l.navShows,
        icon: BovaIcons.tvOutline,
        activeIcon: BovaIcons.tvFilled,
        isSelected: _currentSection == _AppSection.shows,
        onTap: () => _selectSection(_AppSection.shows),
      ),
      DesktopSidebarDestination(
        label: l.navPlayer,
        icon: BovaIcons.playerOutline,
        activeIcon: BovaIcons.playerFilled,
        isSelected: _currentSection == _AppSection.player,
        onTap: () => _selectSection(_AppSection.player),
      ),
      DesktopSidebarDestination(
        label: l.navMediaLibrary,
        icon: BovaIcons.libraryOutline,
        activeIcon: BovaIcons.libraryFilled,
        isSelected: _currentSection == _AppSection.library,
        onTap: () => _selectSection(_AppSection.library),
      ),
      DesktopSidebarDestination(
        label: l.navAccount,
        icon: BovaIcons.personOutline,
        activeIcon: BovaIcons.personFilled,
        isSelected: _currentSection == _AppSection.account,
        onTap: () => _selectSection(_AppSection.account),
      ),
    ];
  }

  List<Widget> _buildTopActions() {
    final l = S.of(context);
    if (_currentSection == _AppSection.library) {
      return [
        _TopActionButton(
          icon: BovaIcons.refreshOutline,
          onTap: () => _mediaLibraryKey.currentState?.refreshAndSync(),
          tooltip: l.actionRefreshSync,
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
          tooltip: l.actionSearchMedia,
        ),
      ];
    }

    return [
      _TopActionButton(
        icon: BovaIcons.searchOutline,
        onTap: _openDiscoverSearch,
        tooltip: l.actionSearch,
      ),
      const SizedBox(width: 10),
      _TopActionButton(
        icon: BovaIcons.bookmarkOutline,
        onTap: _openDiscoverBookmarks,
        tooltip: l.actionBookmarks,
      ),
      const SizedBox(width: 10),
      _TopActionButton(
        icon: BovaIcons.bellOutline,
        onTap: () => _showComingSoon(l.actionNotifications),
        tooltip: l.actionNotifications,
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
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: theme.dividerTheme.color?.withValues(alpha: 0.92) ?? DesignSystem.neutral200,
            ),
            boxShadow: DesignSystem.shadowSm,
          ),
          child: Icon(
            _sectionIcon(),
            size: 17,
            color: accentColor,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _sectionTitle(),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: DesignSystem.textBase,
                fontWeight: DesignSystem.weightSemibold,
                letterSpacing: -0.3,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _profileName(user),
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    final l = S.of(context);
    final actions = <Widget>[];

    if (_currentSection == _AppSection.library) {
      actions.addAll([
        _TopActionButton(
          icon: BovaIcons.refreshOutline,
          onTap: () => _mediaLibraryKey.currentState?.refreshAndSync(),
          tooltip: l.actionRefreshSync,
          size: 40,
          iconSize: 19,
          radius: 14,
        ),
        const SizedBox(width: 8),
        _buildAddButton(),
      ]);
    } else if (_currentSection != _AppSection.player &&
        _currentSection != _AppSection.account) {
      actions.addAll([
        _TopActionButton(
          icon: BovaIcons.searchOutline,
          onTap: _openDiscoverSearch,
          tooltip: l.actionSearch,
          size: 40,
          iconSize: 19,
          radius: 14,
        ),
        const SizedBox(width: 8),
        _TopActionButton(
          icon: BovaIcons.bookmarkOutline,
          onTap: _openDiscoverBookmarks,
          tooltip: l.actionBookmarks,
          size: 40,
          iconSize: 19,
          radius: 14,
        ),
      ]);
    }

    if (actions.isNotEmpty) {
      actions.add(const SizedBox(width: 8));
    }
    actions.add(_buildMobileOverflowMenu());
    return actions;
  }

  Widget _buildMobileOverflowMenu() {
    final l = S.of(context);

    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(
        Icons.more_horiz_rounded,
        color: Color(0xFFE11D48),
        size: 20,
      ),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.white),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFF0F1F4)),
          ),
        ),
        fixedSize: WidgetStateProperty.all(const Size(40, 40)),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
      ),
      onSelected: (value) async {
        switch (value) {
          case 'account':
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountPage()),
            );
            break;
          case 'settings':
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'account',
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 18),
              const SizedBox(width: 10),
              Text(l.navAccount),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              const Icon(Icons.settings_outlined, size: 18),
              const SizedBox(width: 10),
              Text(l.settingsTitle),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<auth_provider.AuthProvider>(context);
    final user = authProvider.user;
    final isDesktop = DesignSystem.isDesktop(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetie = themeMode == AppThemeMode.sweetiePro;
    final isSpecial = isCyberpunk || isSweetie;
    final specialNeon = isSweetie ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;
    final specialBg = isSweetie ? AppTheme.sweetieBg : AppTheme.cyberBg;
    final specialCard = isSweetie ? AppTheme.sweetieCard : AppTheme.cyberCard;

    if (!isDesktop) {
      return _buildMobileScaffold();
    }

    // 桌面主背景色
    final desktopBg = isSpecial
        ? (isSweetie ? const Color(0xFFFAE8F0) : const Color(0xFF08080F))
        : isDark
            ? const Color(0xFF0C0C0E)
            : const Color(0xFFF1F3F6);
    // 工作区面板色
    final panelColor = isSpecial
        ? specialCard
        : isDark
            ? const Color(0xFF1A1A1F)
            : Colors.white;
    // 工作区内容底色
    final contentBg = isSpecial
        ? specialBg
        : isDark
            ? const Color(0xFF111114)
            : const Color(0xFFF9FAFB);

    return Scaffold(
      backgroundColor: desktopBg,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          debugPrint(
            '[MainNavigation] pointer down x=${event.position.dx} y=${event.position.dy}',
          );
        },
        child: SafeArea(
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
                  onSettingsTap: () {
                    setState(() => _showSettings = true);
                  },
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: BorderRadius.circular(34),
                      border: isSpecial
                          ? Border.all(
                              color: specialNeon.withValues(alpha: 0.1),
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: isSpecial
                              ? specialNeon.withValues(alpha: 0.04)
                              : const Color(0xFF111827).withValues(alpha: isDark ? 0.2 : 0.06),
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
                            title: _showSettings
                                ? S.of(context).settingsTitle
                                : _sectionTitle(),
                            sectionIcon: _showSettings
                                ? Icons.settings_outlined
                                : _sectionIcon(),
                            onBack: _showSettings
                                ? () => setState(() => _showSettings = false)
                                : _shouldShowTopBarBackButton()
                                    ? _handleTopBarBack
                                    : null,
                            actions: _showSettings
                                ? const []
                                : _buildTopActions(),
                          ),
                          Expanded(
                            child: ColoredBox(
                              color: contentBg,
                              child: _showSettings
                                  ? const SettingsPage(embedded: true)
                                  : _buildDesktopContent(),
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
      ),
    );
  }

  Widget _buildMobileScaffold() {
    final authProvider = Provider.of<auth_provider.AuthProvider>(context);
    final user = authProvider.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = context.watch<ThemeProvider>().themeMode;
    final isCyberpunk = themeMode == AppThemeMode.cyberpunk;
    final isSweetieMobile = themeMode == AppThemeMode.sweetiePro;
    final isSpecialMobile = isCyberpunk || isSweetieMobile;
    final specialNeonMobile = isSweetieMobile ? AppTheme.sweetieHotPink : AppTheme.cyberNeon;
    final specialBgMobile = isSweetieMobile ? AppTheme.sweetieBg : AppTheme.cyberBg;
    final specialCardMobile = isSweetieMobile ? AppTheme.sweetieCard : AppTheme.cyberCard;    final mobileTopActions = _buildMobileTopActions();
    final currentPage = AnimatedSwitcher(
      duration: DesignSystem.durationNormal,
      switchInCurve: DesignSystem.easeOutQuart,
      switchOutCurve: DesignSystem.easeOutQuart,
      child: _buildMobileCurrentPage(),
    );

    final mobileBg = isSpecialMobile
        ? specialBgMobile
        : isDark
            ? const Color(0xFF0C0C0E)
            : const Color(0xFFF1F3F6);
    final appBarBg = isSpecialMobile
        ? specialCardMobile
        : isDark
            ? const Color(0xFF1A1A1F)
            : Colors.white;
    final appBarBorder = isSpecialMobile
        ? specialNeonMobile.withValues(alpha: 0.1)
        : isDark
            ? const Color(0xFF2A2A30)
            : DesignSystem.neutral200;

    return Scaffold(
      backgroundColor: mobileBg,
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: appBarBg,
            border: Border(
              bottom: BorderSide(
                color: appBarBorder,
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
        decoration: BoxDecoration(
          color: isSpecialMobile
              ? specialBgMobile
              : isDark
                  ? const Color(0xFF111114)
                  : const Color(0xFFF9FAFB),
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
        items: [
          BovaBottomNavItem(
            icon: BovaIcons.homeOutline,
            activeIcon: BovaIcons.homeFilled,
            label: S.of(context).mobileNavDiscover,
          ),
          BovaBottomNavItem(
            icon: BovaIcons.playerOutline,
            activeIcon: BovaIcons.playerFilled,
            label: S.of(context).mobileNavPlayer,
          ),
          BovaBottomNavItem(
            icon: BovaIcons.libraryOutline,
            activeIcon: BovaIcons.libraryFilled,
            label: S.of(context).mobileNavLibrary,
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
