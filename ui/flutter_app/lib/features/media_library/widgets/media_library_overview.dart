import 'package:flutter/material.dart';

import '../../../core/theme/bova_icons.dart';
import '../../../core/theme/design_system.dart';
import '../../../core/widgets/bova_button.dart';
import '../../../core/widgets/bova_card.dart';
import '../../../l10n/generated/app_localizations.dart';
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
      color: Theme.of(context).colorScheme.primary,
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
            _SourceGrid(
              sources: sources,
              onOpenSource: onOpenSource,
              onOpenSourceOptions: onOpenSourceOptions,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: DesignSystem.space1,
        bottom: DesignSystem.space1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              S.of(context).mediaSourceList,
              style: TextStyle(
                fontSize: DesignSystem.textBase,
                fontWeight: DesignSystem.weightSemibold,
                color: scheme.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignSystem.space3,
              vertical: DesignSystem.space2,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
            ),
            child: Text(
              S.of(context).mediaSourceCount(count),
              style: TextStyle(
                fontSize: DesignSystem.textXs,
                fontWeight: DesignSystem.weightSemibold,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceGrid extends StatelessWidget {
  final List<MediaSource> sources;
  final ValueChanged<MediaSource> onOpenSource;
  final ValueChanged<MediaSource> onOpenSourceOptions;

  const _SourceGrid({
    required this.sources,
    required this.onOpenSource,
    required this.onOpenSourceOptions,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = DesignSystem.isDesktop(context) ? 2 : 1;
    final rows = <Widget>[];

    for (int i = 0; i < sources.length; i += crossAxisCount) {
      final rowChildren = <Widget>[];
      for (int j = 0; j < crossAxisCount; j++) {
        final index = i + j;
        if (index < sources.length) {
          rowChildren.add(
            Expanded(
              child: _SourceGridItem(
                source: sources[index],
                onTap: () => onOpenSource(sources[index]),
                onMoreTap: () => onOpenSourceOptions(sources[index]),
              ),
            ),
          );
        } else {
          rowChildren.add(const Expanded(child: SizedBox()));
        }
        if (j < crossAxisCount - 1) {
          rowChildren.add(const SizedBox(width: DesignSystem.space3));
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: DesignSystem.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowChildren,
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

class _SourceGridItem extends StatelessWidget {
  final MediaSource source;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _SourceGridItem({
    required this.source,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = mediaSourceVisual(source.type, context: context);

    return BovaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DesignSystem.space4),
      child: Row(
        children: [
          // Icon container - theme aware
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 22,
                  margin: const EdgeInsets.only(left: 7),
                  decoration: BoxDecoration(
                    color: visual.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Icon(
                      visual.icon,
                      color: scheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignSystem.space3),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignSystem.textBase,
                    fontWeight: DesignSystem.weightSemibold,
                    color: scheme.onSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sourceEndpointLabel(source),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignSystem.textSm,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sourceDetailLabel(source, context: context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: DesignSystem.textXs,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DesignSystem.space2),
          // More button
          IconButton(
            onPressed: onMoreTap,
            tooltip: S.of(context).mediaSourceEdit,
            icon: Icon(
              BovaIcons.moreOutline,
              color: scheme.onSurfaceVariant,
              size: 20,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(DesignSystem.space4),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DesignSystem.radiusLg),
        border: Border.all(
          color: scheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: scheme.error, size: 20),
          const SizedBox(width: DesignSystem.space3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: DesignSystem.textSm,
                color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: DesignSystem.space12),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: DesignSystem.space4),
            Text(
              S.of(context).mediaSourceLoading,
              style: TextStyle(
                fontSize: DesignSystem.textSm,
                color: scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
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
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(DesignSystem.radius2xl),
                  ),
                  child: Icon(
                    Icons.library_add_outlined,
                    size: 32,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: DesignSystem.space5),
                Text(
                  S.of(context).mediaSourceEmpty,
                  style: TextStyle(
                    fontSize: DesignSystem.textXl,
                    fontWeight: DesignSystem.weightSemibold,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: DesignSystem.space2),
                Text(
                  S.of(context).mediaSourceEmptyHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: DesignSystem.textBase,
                    color: scheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: DesignSystem.space5),
                BovaButton(
                  text: S.of(context).mediaSourceAdd,
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
