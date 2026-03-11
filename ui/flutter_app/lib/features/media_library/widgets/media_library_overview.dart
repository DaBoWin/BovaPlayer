import 'package:flutter/material.dart';

import '../../../core/theme/bova_icons.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/widgets/bova_button.dart';
import '../../../core/widgets/bova_card.dart';
import '../media_library_ui.dart';
import '../models/media_source.dart';

class MediaLibraryOverview extends StatelessWidget {
  final List<MediaSource> sources;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddSource;
  final ValueChanged<MediaSource> onOpenSource;
  final ValueChanged<MediaSource> onOpenSourceOptions;

  const MediaLibraryOverview({
    super.key,
    required this.sources,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onAddSource,
    required this.onOpenSource,
    required this.onOpenSourceOptions,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = DesignSystem.isDesktop(context)
        ? DesignSystem.space6
        : DesignSystem.space4;

    return RefreshIndicator(
      color: DesignSystem.accent600,
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          DesignSystem.space3,
          horizontalPadding,
          DesignSystem.space8,
        ),
        children: [
          if (errorMessage != null) ...[
            _InlineErrorBanner(message: errorMessage!),
            const SizedBox(height: DesignSystem.space4),
          ],
          if (isLoading && sources.isEmpty)
            const _InitialLoadingState()
          else if (sources.isEmpty)
            _EmptyLibrary(onAddSource: onAddSource)
          else ...[
            _ListHeader(count: sources.length),
            const SizedBox(height: DesignSystem.space3),
            ...sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: DesignSystem.space3),
                child: _SourceListItem(
                  source: source,
                  onTap: () => onOpenSource(source),
                  onMoreTap: () => onOpenSourceOptions(source),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  final int count;

  const _ListHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: DesignSystem.space1,
        bottom: DesignSystem.space1,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '媒体源列表',
              style: TextStyle(
                fontSize: DesignSystem.textBase,
                fontWeight: DesignSystem.weightSemibold,
                color: DesignSystem.neutral900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSystem.space3,
              vertical: DesignSystem.space2,
            ),
            decoration: BoxDecoration(
              color: DesignSystem.neutral100,
              borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            ),
            child: Text(
              '$count 项',
              style: const TextStyle(
                fontSize: DesignSystem.textXs,
                fontWeight: DesignSystem.weightSemibold,
                color: DesignSystem.neutral700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceListItem extends StatelessWidget {
  final MediaSource source;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _SourceListItem({
    required this.source,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final visual = mediaSourceVisual(source.type);

    return BovaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DesignSystem.space4),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: DesignSystem.neutral200),
              boxShadow: [
                BoxShadow(
                  color: DesignSystem.neutral900.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: visual.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Icon(
                      visual.icon,
                      color: DesignSystem.neutral700,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignSystem.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: DesignSystem.textLg,
                    fontWeight: DesignSystem.weightSemibold,
                    color: DesignSystem.neutral900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: DesignSystem.space1),
                Text(
                  sourceEndpointLabel(source),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: DesignSystem.textBase,
                    color: DesignSystem.neutral600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sourceDetailLabel(source),
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
          const SizedBox(width: DesignSystem.space3),
          IconButton(
            onPressed: onMoreTap,
            tooltip: '更多操作',
            icon: const Icon(
              BovaIcons.moreOutline,
              color: DesignSystem.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  final String message;

  const _InlineErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignSystem.space4),
      decoration: BoxDecoration(
        color: DesignSystem.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        border: Border.all(
          color: DesignSystem.error.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: DesignSystem.error, size: 20),
          const SizedBox(width: DesignSystem.space3),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: DesignSystem.textSm,
                color: DesignSystem.neutral700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialLoadingState extends StatelessWidget {
  const _InitialLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: DesignSystem.space12),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: DesignSystem.accent600),
            SizedBox(height: DesignSystem.space4),
            Text(
              '正在加载媒体源…',
              style: TextStyle(
                fontSize: DesignSystem.textSm,
                color: DesignSystem.neutral600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final VoidCallback onAddSource;

  const _EmptyLibrary({required this.onAddSource});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DesignSystem.space10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: BovaCard(
            padding: const EdgeInsets.all(DesignSystem.space6),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: DesignSystem.accent100,
                    borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
                  ),
                  child: const Icon(
                    Icons.library_add_outlined,
                    size: 32,
                    color: DesignSystem.accent600,
                  ),
                ),
                const SizedBox(height: DesignSystem.space5),
                const Text(
                  '还没有媒体源',
                  style: TextStyle(
                    fontSize: DesignSystem.textXl,
                    fontWeight: DesignSystem.weightSemibold,
                    color: DesignSystem.neutral900,
                  ),
                ),
                const SizedBox(height: DesignSystem.space2),
                const Text(
                  '从右上角添加 Emby、SMB 或 FTP 后，这里会直接显示你的媒体源列表。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: DesignSystem.textBase,
                    color: DesignSystem.neutral600,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: DesignSystem.space5),
                BovaButton(
                  text: '添加媒体源',
                  icon: Icons.add,
                  onPressed: onAddSource,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
