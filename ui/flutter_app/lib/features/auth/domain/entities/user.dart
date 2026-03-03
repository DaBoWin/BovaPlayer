/// 用户实体
/// 
/// 表示应用中的用户信息
class User {
  final String id;
  final String email;
  final String? username;
  final String? avatarUrl;
  final AccountType accountType;
  final DateTime? proExpiresAt;
  final AccountLimits limits;
  final AccountUsage usage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isAdmin;

  const User({
    required this.id,
    required this.email,
    this.username,
    this.avatarUrl,
    required this.accountType,
    this.proExpiresAt,
    required this.limits,
    required this.usage,
    required this.createdAt,
    required this.updatedAt,
    this.isAdmin = false,
  });

  /// 是否为 Pro 用户
  bool get isPro => accountType == AccountType.pro || accountType == AccountType.lifetime;

  /// 是否为永久版用户
  bool get isLifetime => accountType == AccountType.lifetime;

  /// Pro 是否已过期
  bool get isProExpired {
    if (accountType != AccountType.pro) return false;
    if (proExpiresAt == null) return true;
    return DateTime.now().isAfter(proExpiresAt!);
  }

  /// 是否可以添加服务器
  bool canAddServer() {
    if (limits.maxServers == -1) return true; // 无限制
    return usage.serverCount < limits.maxServers;
  }

  /// 是否可以添加设备
  bool canAddDevice() {
    if (limits.maxDevices == -1) return true; // 无限制
    return usage.deviceCount < limits.maxDevices;
  }

  /// 是否有足够的存储空间
  bool hasEnoughStorage(int requiredMb) {
    final availableMb = limits.storageQuotaMb - usage.storageUsedMb;
    return availableMb >= requiredMb;
  }

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? avatarUrl,
    AccountType? accountType,
    DateTime? proExpiresAt,
    AccountLimits? limits,
    AccountUsage? usage,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdmin,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      accountType: accountType ?? this.accountType,
      proExpiresAt: proExpiresAt ?? this.proExpiresAt,
      limits: limits ?? this.limits,
      usage: usage ?? this.usage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}

/// 账号类型
enum AccountType {
  free,     // 免费版
  pro,      // Pro 版
  lifetime, // 永久版
}

extension AccountTypeExtension on AccountType {
  String get displayName {
    switch (this) {
      case AccountType.free:
        return '社区免费版';
      case AccountType.pro:
        return 'Pro 版';
      case AccountType.lifetime:
        return '永久版';
    }
  }

  String get description {
    switch (this) {
      case AccountType.free:
        return '基础播放 + 有限同步';
      case AccountType.pro:
        return '完整同步 + 高级功能';
      case AccountType.lifetime:
        return '终身 Pro 权益';
    }
  }
}

/// 账号限额
class AccountLimits {
  final int maxServers;      // -1 表示无限制
  final int maxDevices;      // -1 表示无限制
  final int storageQuotaMb;

  const AccountLimits({
    required this.maxServers,
    required this.maxDevices,
    required this.storageQuotaMb,
  });

  /// 获取账号类型的默认限额
  factory AccountLimits.forAccountType(AccountType type) {
    switch (type) {
      case AccountType.free:
        return const AccountLimits(
          maxServers: 10,
          maxDevices: 2,
          storageQuotaMb: 100,
        );
      case AccountType.pro:
        return const AccountLimits(
          maxServers: -1, // 无限
          maxDevices: 5,
          storageQuotaMb: 1024,
        );
      case AccountType.lifetime:
        return const AccountLimits(
          maxServers: -1, // 无限
          maxDevices: -1, // 无限
          storageQuotaMb: 5120,
        );
    }
  }
}

/// 账号使用量
class AccountUsage {
  final int serverCount;
  final int deviceCount;
  final int storageUsedMb;

  const AccountUsage({
    required this.serverCount,
    required this.deviceCount,
    required this.storageUsedMb,
  });

  /// 空使用量
  const AccountUsage.empty()
      : serverCount = 0,
        deviceCount = 0,
        storageUsedMb = 0;

  AccountUsage copyWith({
    int? serverCount,
    int? deviceCount,
    int? storageUsedMb,
  }) {
    return AccountUsage(
      serverCount: serverCount ?? this.serverCount,
      deviceCount: deviceCount ?? this.deviceCount,
      storageUsedMb: storageUsedMb ?? this.storageUsedMb,
    );
  }
}
