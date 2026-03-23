import '../../domain/entities/payment_status.dart';
import '../../domain/entities/payment_status_snapshot.dart';

class PaymentStatusModel extends PaymentStatusSnapshot {
  const PaymentStatusModel({
    required super.orderId,
    required super.state,
    super.subscriptionId,
    super.merchantOrderId,
    super.transactionId,
    super.message,
    super.paidAt,
    super.expiresAt,
    super.raw,
  });

  factory PaymentStatusModel.fromJson(Map<String, dynamic> json) {
    final normalized = _normalizeMap(json);
    final rawStatus = _firstString(normalized, const [
      'status',
      'order_status',
      'payment_status',
    ]);
    final paid = _firstBool(normalized, const ['paid', 'is_paid']);

    return PaymentStatusModel(
      orderId: _firstString(normalized, const ['order_id', 'id']) ?? '',
      state: PaymentOrderState.fromValue(
        paid == true && (rawStatus == null || rawStatus.isEmpty) ? 'paid' : rawStatus,
      ),
      subscriptionId: _firstString(normalized, const [
        'subscription_id',
        'subscriptionId',
      ]),
      merchantOrderId: _firstString(
        normalized,
        const ['merchant_order_id', 'out_trade_no'],
      ),
      transactionId: _firstString(normalized, const [
        'transaction_id',
        'trade_no',
      ]),
      message: _firstString(normalized, const [
        'message',
        'msg',
        'detail',
      ]),
      paidAt: _firstDateTime(normalized, const [
        'paid_at',
        'success_at',
        'pay_time',
      ]),
      expiresAt: _firstDateTime(normalized, const [
        'expires_at',
        'expire_at',
        'deadline_at',
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
