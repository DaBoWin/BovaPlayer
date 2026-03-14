enum DiscoverLatencyTier {
  offline,
  red,
  yellow,
  green,
}

class DiscoverLatencyTierResolver {
  static DiscoverLatencyTier fromMs(int? latencyMs) {
    if (latencyMs == null) return DiscoverLatencyTier.offline;
    if (latencyMs <= 80) return DiscoverLatencyTier.green;
    if (latencyMs <= 180) return DiscoverLatencyTier.yellow;
    return DiscoverLatencyTier.red;
  }

  static int sortRank(int? latencyMs) {
    switch (fromMs(latencyMs)) {
      case DiscoverLatencyTier.green:
        return 0;
      case DiscoverLatencyTier.yellow:
        return 1;
      case DiscoverLatencyTier.red:
        return 2;
      case DiscoverLatencyTier.offline:
        return 3;
    }
  }

  /// Returns a localized tooltip string.
  /// Requires [good], [medium], [slow], [unreachable] labels from the caller
  /// (typically from S.of(context)).
  static String tooltip(
    int? latencyMs, {
    required String good,
    required String medium,
    required String slow,
    required String unreachable,
  }) {
    final tier = fromMs(latencyMs);
    switch (tier) {
      case DiscoverLatencyTier.green:
        return '$latencyMs ms · $good';
      case DiscoverLatencyTier.yellow:
        return '$latencyMs ms · $medium';
      case DiscoverLatencyTier.red:
        return '$latencyMs ms · $slow';
      case DiscoverLatencyTier.offline:
        return unreachable;
    }
  }
}
