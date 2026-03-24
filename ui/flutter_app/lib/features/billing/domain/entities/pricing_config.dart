class PricingConfig {
  const PricingConfig({
    required this.planId,
    required this.displayName,
    required this.description,
    required this.priceCny,
    required this.currency,
    required this.billingPeriod,
    required this.subject,
    required this.body,
    required this.subscriptionType,
    required this.accountType,
    this.durationDays,
    required this.maxServers,
    required this.maxDevices,
    required this.storageQuotaMb,
    required this.isActive,
    required this.sortOrder,
    this.metadata = const <String, dynamic>{},
  });

  final String planId;
  final String displayName;
  final String description;
  final double priceCny;
  final String currency;
  final String billingPeriod;
  final String subject;
  final String body;
  final String subscriptionType;
  final String accountType;
  final int? durationDays;
  final int maxServers;
  final int maxDevices;
  final int storageQuotaMb;
  final bool isActive;
  final int sortOrder;
  final Map<String, dynamic> metadata;

  bool get isLifetime => accountType == 'lifetime';
  bool get isPro => accountType == 'pro';

  PricingConfig copyWith({
    String? planId,
    String? displayName,
    String? description,
    double? priceCny,
    String? currency,
    String? billingPeriod,
    String? subject,
    String? body,
    String? subscriptionType,
    String? accountType,
    int? durationDays,
    int? maxServers,
    int? maxDevices,
    int? storageQuotaMb,
    bool? isActive,
    int? sortOrder,
    Map<String, dynamic>? metadata,
  }) {
    return PricingConfig(
      planId: planId ?? this.planId,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      priceCny: priceCny ?? this.priceCny,
      currency: currency ?? this.currency,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      accountType: accountType ?? this.accountType,
      durationDays: durationDays ?? this.durationDays,
      maxServers: maxServers ?? this.maxServers,
      maxDevices: maxDevices ?? this.maxDevices,
      storageQuotaMb: storageQuotaMb ?? this.storageQuotaMb,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      metadata: metadata ?? this.metadata,
    );
  }
}
