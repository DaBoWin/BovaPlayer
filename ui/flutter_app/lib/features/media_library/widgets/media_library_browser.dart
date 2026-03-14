import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
import '../../../core/theme/bova_icons.dart';
import '../../../core/widgets/bova_card.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/network_file.dart';
import '../media_library_ui.dart';
import '../models/media_source.dart';

class MediaLibraryBrowserView extends StatelessWidget {
  final MediaSource source;
  final List<NetworkFile> items;
  final String currentPath;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onNavigateTo;
  final ValueChanged<NetworkFile> onItemTap;

  const MediaLibraryBrowserView({
    super.key,
    required this.source,
    required this.items,
    required this.currentPath,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onNavigateTo,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final sortedItems = [...items]..sort((a, b) {
        if (a.isDirectory != b.isDirectory) {
          return a.isDirectory ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return Padding(
      padding: const EdgeInsets.all(DesignSystem.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BrowserHero(
              source: source, currentPath: currentPath, onRefresh: onRefresh),
          const SizedBox(height: DesignSystem.space4),
          _BreadcrumbRow(currentPath: currentPath, onNavigateTo: onNavigateTo),
          const SizedBox(height: DesignSystem.space4),
          Expanded(
            child: AnimatedSwitcher(
              duration: DesignSystem.durationNormal,
              switchInCurve: DesignSystem.easeOutQuart,
              switchOutCurve: DesignSystem.easeOutQuart,
              child: isLoading
                  ? const _BrowserLoadingState()
                  : errorMessage != null
                      ? _BrowserErrorState(
                          message: errorMessage!, onRetry: onRefresh)
                      : sortedItems.isEmpty
                          ? const _BrowserEmptyState()
                          : ListView.separated(
                              key: ValueKey(currentPath),
                              itemCount: sortedItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: DesignSystem.space3),
                              itemBuilder: (context, index) {
                                final item = sortedItems[index];
                                return _FileItemCard(
                                  item: item,
                                  onTap: () => onItemTap(item),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserHero extends StatelessWidget {
  final MediaSource source;
  final String currentPath;
  final Future<void> Function() onRefresh;

  const _BrowserHero({
    required this.source,
    required this.currentPath,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final visual = mediaSourceVisual(source.type, context: context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
        border: Border.all(color: DesignSystem.neutral200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignSystem.space5),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [visual.primary, visual.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
              ),
              child: Icon(visual.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: DesignSystem.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    style: const TextStyle(
                      fontSize: DesignSystem.textLg,
                      fontWeight: DesignSystem.weightSemibold,
                      color: DesignSystem.neutral900,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.space1),
                  Text(
                    sourceEndpointLabel(source),
                    style: const TextStyle(
                      fontSize: DesignSystem.textSm,
                      color: DesignSystem.neutral600,
                    ),
                  ),
                  const SizedBox(height: DesignSystem.space2),
                  Text(
                    S.of(context).browserCurrentPath(currentPath),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: DesignSystem.textXs,
                      color: DesignSystem.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRefresh,
              tooltip: S.of(context).browserRefreshDir,
              icon: const Icon(BovaIcons.refreshOutline,
                  color: DesignSystem.neutral600),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbRow extends StatelessWidget {
  final String currentPath;
  final ValueChanged<String> onNavigateTo;

  const _BreadcrumbRow({
    required this.currentPath,
    required this.onNavigateTo,
  });

  @override
  Widget build(BuildContext context) {
    final segments =
        currentPath.split('/').where((item) => item.isNotEmpty).toList();
    final children = <Widget>[
      _BreadcrumbChip(
        label: S.of(context).browserRootDir,
        isActive: segments.isEmpty,
        onTap: currentPath == '/' ? null : () => onNavigateTo('/'),
      ),
    ];

    var accumulator = '';
    for (var index = 0; index < segments.length; index++) {
      accumulator += '/${segments[index]}';
      children.add(const Padding(
        padding: EdgeInsets.symmetric(horizontal: DesignSystem.space1),
        child: Icon(BovaIcons.chevronRight,
            size: 16, color: DesignSystem.neutral400),
      ));
      children.add(
        _BreadcrumbChip(
          label: segments[index],
          isActive: index == segments.length - 1,
          onTap: index == segments.length - 1
              ? null
              : () => onNavigateTo(accumulator),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _BreadcrumbChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? DesignSystem.accent100 : Colors.white,
      borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSystem.space3,
            vertical: DesignSystem.space2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            border: Border.all(
              color:
                  isActive ? DesignSystem.accent200 : DesignSystem.neutral200,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: DesignSystem.textXs,
              fontWeight: isActive
                  ? DesignSystem.weightSemibold
                  : DesignSystem.weightMedium,
              color:
                  isActive ? DesignSystem.accent700 : DesignSystem.neutral700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BrowserLoadingState extends StatelessWidget {
  const _BrowserLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: DesignSystem.accent600),
          const SizedBox(height: DesignSystem.space4),
          Text(
            S.of(context).browserLoadingDir,
            style: const TextStyle(
              fontSize: DesignSystem.textSm,
              color: DesignSystem.neutral600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _BrowserErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: BovaCard(
          padding: const EdgeInsets.all(DesignSystem.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: DesignSystem.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(DesignSystem.radiusXl),
                ),
                child: const Icon(
                  Icons.wifi_tethering_error_rounded,
                  color: DesignSystem.error,
                  size: 30,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Text(
                S.of(context).browserLoadFailed,
                style: const TextStyle(
                  fontSize: DesignSystem.textLg,
                  fontWeight: DesignSystem.weightSemibold,
                  color: DesignSystem.neutral900,
                ),
              ),
              const SizedBox(height: DesignSystem.space2),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignSystem.space5),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(BovaIcons.refreshOutline),
                label: Text(S.of(context).browserReload),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowserEmptyState extends StatelessWidget {
  const _BrowserEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: BovaCard(
          padding: const EdgeInsets.all(DesignSystem.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: DesignSystem.neutral100,
                  borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
                ),
                child: const Icon(
                  BovaIcons.folderOpen,
                  color: DesignSystem.neutral500,
                  size: 30,
                ),
              ),
              const SizedBox(height: DesignSystem.space4),
              Text(
                S.of(context).browserDirEmpty,
                style: const TextStyle(
                  fontSize: DesignSystem.textLg,
                  fontWeight: DesignSystem.weightSemibold,
                  color: DesignSystem.neutral900,
                ),
              ),
              const SizedBox(height: DesignSystem.space2),
              Text(
                S.of(context).browserDirEmptyHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: DesignSystem.textSm,
                  color: DesignSystem.neutral600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileItemCard extends StatelessWidget {
  final NetworkFile item;
  final VoidCallback onTap;

  const _FileItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final visual = mediaFileVisual(item, context: context);
    final meta = item.isDirectory
        ? '${S.of(context).browserFolder} · ${S.of(context).browserClickToEnter}'
        : '${item.sizeFormatted}${item.modified != null ? ' · ${formatMediaLibraryTime(item.modified!)}' : ''}';

    return BovaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DesignSystem.space4),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
            ),
            child: Icon(visual.icon, color: visual.color, size: 22),
          ),
          const SizedBox(width: DesignSystem.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: DesignSystem.textBase,
                    fontWeight: DesignSystem.weightSemibold,
                    color: DesignSystem.neutral900,
                  ),
                ),
                const SizedBox(height: DesignSystem.space1),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: DesignSystem.textXs,
                    color: DesignSystem.neutral600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignSystem.space3),
          Icon(
            item.isDirectory
                ? BovaIcons.chevronRight
                : Icons.play_arrow_rounded,
            color: DesignSystem.neutral500,
          ),
        ],
      ),
    );
  }
}
