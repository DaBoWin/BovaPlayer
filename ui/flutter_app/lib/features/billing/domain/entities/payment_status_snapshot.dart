import 'payment_status.dart';

class PaymentStatusSnapshot {
  const PaymentStatusSnapshot({
    required this.orderId,
    required this.state,
    this.subscriptionId,
    this.merchantOrderId,
    this.transactionId,
    this.message,
    this.paidAt,
    this.expiresAt,
    this.raw = const {},
  });

  final String orderId;
  final PaymentOrderState state;
  final String? subscriptionId;
  final String? merchantOrderId;
  final String? transactionId;
  final String? message;
  final DateTime? paidAt;
  final DateTime? expiresAt;
  final Map<String, dynamic> raw;

  bool get isPaid => state.isPaid;
  bool get isTerminal => state.isTerminal;
}
