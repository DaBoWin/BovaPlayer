import '../../domain/entities/billing_plan.dart';
import '../../domain/entities/payment_order.dart';

class PaymentOrderModel extends PaymentOrder {
  const PaymentOrderModel({
    required super.id,
    required super.plan,
    required super.paymentUrl,
    required super.amountCny,
    required super.status,
    super.merchantOrderId,
    super.channel,
    super.expiresAt,
    super.qrCodeUrl,
    super.raw,
  });

  factory PaymentOrderModel.fromJson(Map<String, dynamic> json) {
    final normalized = _normalizeMap(json);
    final rawPlanId = _firstString(normalized, const [
      'plan_id',
      'plan',
      'subscription_type',
      'plan_type',
    ]);

    return PaymentOrderModel(
      id: _firstString(normalized, const ['order_id', 'id']) ?? '',
      plan: rawPlanId == null ? null : BillingPlan.tryParse(rawPlanId),
      paymentUrl: _firstString(normalized, const [
            'payment_url',
            'pay_url',
            'checkout_url',
            'alipay_url',
            'cashier_url',
          ]) ??
          '',
      amountCny: _firstDouble(normalized, const [
            'amount_cny',
            'amount',
            'total_amount',
            'money',
            'price',
          ]) ??
          0,
      status: _firstString(normalized, const [
            'status',
            'order_status',
            'payment_status',
          ]) ??
          'pending',
      merchantOrderId: _firstString(
        normalized,
        const ['merchant_order_id', 'out_trade_no'],
      ),
      channel: _firstString(normalized, const [
        'payment_method',
        'channel',
        'type',
      ]),
      expiresAt: _firstDateTime(normalized, const [
        'expires_at',
        'expire_at',
        'deadline_at',
      ]),
      qrCodeUrl: _firstString(normalized, const [
        'qr_code_url',
        'qrcode',
        'qr',
        'code_url',
      ]),
      raw: normalized,
    );
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
    for (final key in const ['data', 'result', 'order']) {
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
        final normalized = value.trim().replaceAll(',', '');
        final parsed = double.tryParse(normalized);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? _firstDateTime(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _parseDateTime(value);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) {
      final milliseconds = value > 1000000000000 ? value.toInt() : (value * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
          .toLocal();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final numeric = num.tryParse(raw);
    if (numeric != null) {
      final milliseconds = numeric > 1000000000000 ? numeric.toInt() : (numeric * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true)
          .toLocal();
    }
    return DateTime.tryParse(raw);
  }
}
