import 'package:flutter/material.dart';

import '../../../core/theme/design_system.dart';
import '../models/discover_section.dart';
import '../models/tmdb_media_item.dart';
import 'discover_poster_card.dart';

class DiscoverSectionRow extends StatefulWidget {
  const DiscoverSectionRow({
    super.key,
    required this.section,
    required this.imageBuilder,
    this.onItemTap,
    this.quickPlayBuilder,
    this.overlayActionBuilder,
  });

  final DiscoverSection section;
  final String Function(String? path, {String size}) imageBuilder;
  final void Function(TmdbMediaItem item)? onItemTap;
  final List<Widget> Function(TmdbMediaItem item)? quickPlayBuilder;
  final Widget? Function(TmdbMediaItem item)? overlayActionBuilder;

  @override
  State<DiscoverSectionRow> createState() => _DiscoverSectionRowState();
}

class _DiscoverSectionRowState extends State<DiscoverSectionRow> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollState());
  }

  @override
  void didUpdateWidget(covariant DiscoverSectionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.items.length != widget.section.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncScrollState());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() => _syncScrollState();

  void _syncScrollState() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScroll = position.maxScrollExtent > 0;
    final canLeft = canScroll && position.pixels > 4;
    final canRight =
        canScroll && position.pixels < position.maxScrollExtent - 4;

    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  Future<void> _scrollBy(double offset) async {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final cardWidth = constraints.maxWidth >= 1500
            ? 188.0
            : constraints.maxWidth >= 1260
                ? 176.0
                : constraints.maxWidth >= 1024
                    ? 164.0
                    : isMobile
                        ? 172.0
                        : 156.0;
        const gap = DesignSystem.space5;
        final rowHeight = cardWidth / 0.704 + (isMobile ? 138 : 114);
        final scrollStep = (cardWidth + gap) * 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.section.title,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: DesignSystem.weightMedium,
                          color: DesignSystem.neutral700,
                          letterSpacing: -0.9,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.section.subtitle,
                        style: const TextStyle(
                          fontSize: 15,
                          color: DesignSystem.neutral500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  _ScrollArrowGroup(
                    canScrollLeft: _canScrollLeft,
                    canScrollRight: _canScrollRight,
                    onScrollLeft: () => _scrollBy(-scrollStep),
                    onScrollRight: () => _scrollBy(scrollStep),
                  ),
              ],
            ),
            const SizedBox(height: DesignSystem.space5),
            SizedBox(
              height: rowHeight,
              child: ListView.separated(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: widget.section.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: gap),
                itemBuilder: (context, index) {
                  final item = widget.section.items[index];
                  return SizedBox(
                    width: cardWidth,
                    child: DiscoverPosterCard(
                      item: item,
                      posterUrl:
                          widget.imageBuilder(item.posterPath, size: 'w500'),
                      width: cardWidth,
                      onTap: widget.onItemTap == null
                          ? null
                          : () => widget.onItemTap!(item),
                      quickPlayButtons:
                          widget.quickPlayBuilder?.call(item) ?? const [],
                      overlayAction: widget.overlayActionBuilder?.call(item),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScrollArrowGroup extends StatelessWidget {
  const _ScrollArrowGroup({
    required this.canScrollLeft,
    required this.canScrollRight,
    required this.onScrollLeft,
    required this.onScrollRight,
  });

  final bool canScrollLeft;
  final bool canScrollRight;
  final VoidCallback onScrollLeft;
  final VoidCallback onScrollRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
        border: Border.all(color: DesignSystem.neutral200),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: DesignSystem.space2,
        vertical: 6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            enabled: canScrollLeft,
            onTap: onScrollLeft,
          ),
          const SizedBox(width: 2),
          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            enabled: canScrollRight,
            onTap: onScrollRight,
          ),
        ],
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
      child: AnimatedContainer(
        duration: DesignSystem.durationFast,
        curve: DesignSystem.easeOutQuart,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? Colors.transparent : Colors.transparent,
          borderRadius: BorderRadius.circular(DesignSystem.radiusFull),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? DesignSystem.neutral500 : DesignSystem.neutral300,
        ),
      ),
    );
  }
}
