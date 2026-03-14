import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../models/discover_latency_tier.dart';

class DiscoverLatencyIndicator extends StatelessWidget {
  const DiscoverLatencyIndicator({
    super.key,
    required this.latencyMs,
    this.compact = false,
  });

  final int? latencyMs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tier = DiscoverLatencyTierResolver.fromMs(latencyMs);
    final l = S.of(context);
    final tooltip = latencyMs == null
        ? l.discoverLatencyUnreachable
        : '$latencyMs ms';
    final width = compact ? 12.0 : 14.0;
    final height = compact ? 12.0 : 14.0;
    final color = switch (tier) {
      DiscoverLatencyTier.offline => const Color(0xFF9CA3AF),
      DiscoverLatencyTier.red => const Color(0xFFFF5F57),
      DiscoverLatencyTier.yellow => const Color(0xFFF4C430),
      DiscoverLatencyTier.green => const Color(0xFF34C759),
    };

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 180),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(compact ? 4.5 : 5.5),
        ),
      ),
    );
  }
}
