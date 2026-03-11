import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'emby_page.dart';
import 'core/theme/design_system.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/media_library/controllers/media_library_controller.dart';
import 'features/media_library/models/media_source.dart';
import 'features/media_library/widgets/media_library_browser.dart';
import 'features/media_library/widgets/media_library_dialogs.dart';
import 'features/media_library/widgets/media_library_overview.dart';
import 'models/network_file.dart';
import 'player_window/desktop_player_window.dart';
import 'widgets/custom_app_bar.dart';

const Color _libraryWorkspaceCanvas = Color(0xFFF1F3F6);
const Color _librarySurface = Colors.white;

class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<MediaLibraryPage> createState() => MediaLibraryPageState();
}

class MediaLibraryPageState extends State<MediaLibraryPage> {
  late final MediaLibraryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MediaLibraryController();
    _controller.initialize();
  }

  @override
  void dispose() {
    unawaited(_controller.disposeController());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final activeSource = _controller.activeSource;
        final content = AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          child: activeSource == null
              ? MediaLibraryOverview(
                  key: const ValueKey('library-overview'),
                  sources: _controller.sources,
                  isLoading: _controller.isLoading,
                  errorMessage: _controller.errorMessage,
                  onRefresh: _controller.loadSources,
                  onAddSource: () => _showAddSourcePicker(context),
                  onOpenSource: _handleOpenSource,
                  onOpenSourceOptions: _showSourceOptions,
                )
              : MediaLibraryBrowserView(
                  key: ValueKey('library-browser-${activeSource.id}'),
                  source: activeSource,
                  items: _controller.currentItems,
                  currentPath: _controller.currentPath,
                  isLoading: _controller.isLoading,
                  errorMessage: _controller.errorMessage,
                  onRefresh: () =>
                      _controller.loadDirectory(_controller.currentPath),
                  onNavigateTo: _controller.loadDirectory,
                  onItemTap: _handleFileTap,
                ),
        );

        if (widget.embedded) {
          return ColoredBox(
            color: _libraryWorkspaceCanvas,
            child: Column(
              children: [
                if (activeSource != null)
                  _EmbeddedLibraryHeader(
                    title: activeSource.name,
                    onBackPressed: _controller.leaveFileBrowser,
                  ),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: _libraryWorkspaceCanvas,
          appBar: activeSource != null
              ? CustomAppBar(
                  showBackButton: true,
                  title: activeSource.name,
                  onBackPressed: _controller.leaveFileBrowser,
                )
              : null,
          body: content,
        );
      },
    );
  }

  void showAddSourceDialog(SourceType type) {
    if (type == SourceType.emby) {
      _showAddEmbyDialog();
    } else {
      _showAddNetworkDialog(type);
    }
  }

  Future<void> refreshAndSync() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final message = await _controller.refreshAndSync(authProvider);
      if (!mounted) return;
      _showSuccess(message);
    } catch (error) {
      if (!mounted) return;
      _showError(_normalizeError(error));
    }
  }

  Future<void> _handleOpenSource(MediaSource source) async {
    if (source.type == SourceType.emby) {
      final embyServer = EmbyServer(
        name: source.name,
        url: source.url,
        username: source.username,
        password: source.password,
        accessToken: source.accessToken,
        userId: source.userId,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmbyPage(
            initialServer: embyServer,
            embedded: widget.embedded,
          ),
        ),
      );
      return;
    }

    try {
      await _controller.connectToSource(source);
    } catch (error) {
      if (!mounted) return;
      _showError(_normalizeError(error));
    }
  }

  void _handleFileTap(NetworkFile file) {
    if (file.isDirectory) {
      _controller.loadDirectory(file.path);
      return;
    }

    if (file.isVideo || file.isAudio) {
      _openPlayer(file);
      return;
    }

    _showError('暂不支持打开此文件类型');
  }

  Future<void> _openPlayer(NetworkFile file) async {
    try {
      final proxyUrl = _controller.createProxyUrl(file);
      if (!mounted) return;
      await DesktopPlayerLauncher.openPlayer(
        context: context,
        url: proxyUrl,
        title: file.name,
        httpHeaders: const {},
      );
    } catch (error) {
      if (!mounted) return;
      _showError('播放失败: ${_normalizeError(error)}');
    }
  }

  void _showAddSourcePicker(BuildContext context) {
    showAddSourcePickerSheet(
      context,
      onSelected: showAddSourceDialog,
    );
  }

  void _showSourceOptions(MediaSource source) {
    showSourceOptionsSheet(
      context,
      source: source,
      onEdit: () => _editSource(source),
      onDelete: () => _deleteSource(source),
    );
  }

  Future<void> _showAddEmbyDialog({MediaSource? editSource}) async {
    final formData = await showEmbySourceDialog(
      context,
      initialSource: editSource,
    );
    if (formData == null) return;

    try {
      final message = await _controller.saveEmbySource(
        existingSource: editSource,
        name: formData.name,
        url: formData.url,
        username: formData.username,
        password: formData.password,
      );
      if (!mounted) return;
      _showSuccess(message);
    } catch (error) {
      if (!mounted) return;
      _showError(_normalizeError(error));
    }
  }

  Future<void> _showAddNetworkDialog(
    SourceType type, {
    MediaSource? editSource,
  }) async {
    final formData = await showNetworkSourceDialog(
      context,
      type: type,
      initialSource: editSource,
    );
    if (formData == null) return;

    try {
      final message = await _controller.saveNetworkSource(
        existingSource: editSource,
        type: type,
        name: formData.name,
        host: formData.host,
        port: formData.port,
        username: formData.username,
        password: formData.password,
        shareName: formData.shareName,
        workgroup: formData.workgroup,
        savePassword: formData.savePassword,
      );
      if (!mounted) return;
      _showSuccess(message);
    } catch (error) {
      if (!mounted) return;
      _showError(_normalizeError(error));
    }
  }

  Future<void> _deleteSource(MediaSource source) async {
    final shouldDelete = await showDeleteSourceDialog(context, source);
    if (!shouldDelete) return;

    try {
      final message = await _controller.deleteSource(source);
      if (!mounted) return;
      _showSuccess(message);
    } catch (error) {
      if (!mounted) return;
      _showError(_normalizeError(error));
    }
  }

  Future<void> _editSource(MediaSource source) async {
    if (source.type == SourceType.emby) {
      await _showAddEmbyDialog(editSource: source);
    } else {
      await _showAddNetworkDialog(source.type, editSource: source);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF047857),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: DesignSystem.error,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        ),
      ),
    );
  }

  String _normalizeError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}

class _EmbeddedLibraryHeader extends StatelessWidget {
  const _EmbeddedLibraryHeader({
    required this.title,
    required this.onBackPressed,
  });

  final String title;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: BoxDecoration(
        color: _librarySurface.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _librarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DesignSystem.neutral900.withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: DesignSystem.neutral900.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: Color(0xFF1C1917),
              ),
              onPressed: onBackPressed,
              splashRadius: 20,
              tooltip: '返回媒体库',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: DesignSystem.weightBold,
                color: DesignSystem.neutral900,
                letterSpacing: -0.6,
                height: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
