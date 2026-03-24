import '../../domain/entities/pricing_config.dart';

class PricingConfigModel extends PricingConfig {
  const PricingConfigModel({
    required super.planId,
    required super.displayName,
    required super.description,
    required super.priceCny,
    required super.currency,
    required super.billingPeriod,
    required super.subject,
    required super.body,
    required super.subscriptionType,
    required super.accountType,
    super.durationDays,
    required super.maxServers,
    required super.maxDevices,
    required super.storageQuotaMb,
    required super.isActive,
    required super.sortOrder,
    super.metadata,
  });

  factory PricingConfigModel.fromJson(Map<String, dynamic> json) {
    final normalized = _normalizeMap(json);

    return PricingConfigModel(
      planId: _firstString(normalized, const ['plan_id', 'planId']) ?? '',
      displayName: _firstString(normalized, const [
            'display_name',
            'displayName',
            'name',
          ]) ??
          '',
      description: _firstString(normalized, const ['description']) ?? '',
      priceCny: _firstDouble(normalized, const [
            'price_cny',
            'priceCny',
            'amount_cny',
            'amount',
          ]) ??
          0,
      currency: _firstString(normalized, const ['currency']) ?? 'CNY',
      billingPeriod: _firstString(normalized, const [
            'billing_period',
            'billingPeriod',
            'period',
          ]) ??
          '',
      subject: _firstString(normalized, const ['subject']) ?? '',
      body: _firstString(normalized, const ['body']) ?? '',
      subscriptionType: _firstString(normalized, const [
            'subscription_type',
            'subscriptionType',
          ]) ??
          '',
      accountType: _firstString(normalized, const [
            'account_type',
            'accountType',
          ]) ??
          '',
      durationDays: _firstInt(normalized, const [
        'duration_days',
        'durationDays',
      ]),
      maxServers: _firstInt(normalized, const [
            'max_servers',
            'maxServers',
          ]) ??
          0,
      maxDevices: _firstInt(normalized, const [
            'max_devices',
            'maxDevices',
          ]) ??
          0,
      storageQuotaMb: _firstInt(normalized, const [
            'storage_quota_mb',
            'storageQuotaMb',
          ]) ??
          0,
      isActive: _firstBool(normalized, const [
            'is_active',
            'isActive',
          ]) ??
          false,
      sortOrder: _firstInt(normalized, const ['sort_order', 'sortOrder']) ?? 0,
      metadata: _firstMap(normalized, const ['metadata']) ?? const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toRpcParams() {
    return <String, dynamic>{
      'p_plan_id': planId,
      'p_price_cny': priceCny,
      'p_display_name': displayName,
      'p_description': description,
      'p_billing_period': billingPeriod,
      'p_subject': subject,
      'p_body': body,
      'p_duration_days': durationDays,
      'p_max_servers': maxServers,
      'p_max_devices': maxDevices,
      'p_storage_quota_mb': storageQuotaMb,
      'p_is_active': isActive,
      'p_sort_order': sortOrder,
      'p_metadata': metadata,
    };
  }

  static Map<String, dynamic> _normalizeMap(Map<String, dynamic> json) {
    final normalized = <String, dynamic>{};

    void mergeMap(Map value) {
      for (final entry in value.entries) {
        final key = entry.key?.toString();
        if (key == null || key.isEmpty) continue;
        normalized.putIfAbsent(key, () => entry.value);
      }
    }

    mergeMap(json);
    for (final key in const ['data', 'result', 'plan']) {
      final nested = json[key];
      if (nested is Map<String, dynamic>) {
        mergeMap(nested);
      } else if (nested is Map) {
        mergeMap(Map<String, dynamic>.from(nested));
      }
    }

    return normalized;
  }

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static double? _firstDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim().replaceAll(',', ''));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static bool? _firstBool(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
    }
    return null;
  }

  static Map<String, dynamic>? _firstMap(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    }
    return null;
  }
}
