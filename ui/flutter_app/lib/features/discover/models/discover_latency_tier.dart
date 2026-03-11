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

  static String tooltip(int? latencyMs) {
    final tier = fromMs(latencyMs);
    switch (tier) {
      case DiscoverLatencyTier.green:
        return '$latencyMs ms · 优';
      case DiscoverLatencyTier.yellow:
        return '$latencyMs ms · 中';
      case DiscoverLatencyTier.red:
        return '$latencyMs ms · 慢';
      case DiscoverLatencyTier.offline:
        return '连接不可达';
    }
  }
}
