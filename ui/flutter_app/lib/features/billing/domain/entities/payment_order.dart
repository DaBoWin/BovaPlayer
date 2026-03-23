import 'billing_plan.dart';

class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.plan,
    required this.paymentUrl,
    required this.amountCny,
    required this.status,
    this.merchantOrderId,
    this.channel,
    this.expiresAt,
    this.qrCodeUrl,
    this.raw = const {},
  });

  final String id;
  final BillingPlan? plan;
  final String paymentUrl;
  final double amountCny;
  final String status;
  final String? merchantOrderId;
  final String? channel;
  final DateTime? expiresAt;
  final String? qrCodeUrl;
  final Map<String, dynamic> raw;
}
