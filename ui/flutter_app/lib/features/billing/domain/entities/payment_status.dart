enum PaymentOrderState {
  pending,
  paid,
  failed,
  cancelled,
  expired,
  unknown;

  bool get isTerminal => switch (this) {
        paid || failed || cancelled || expired => true,
        pending || unknown => false,
      };

  bool get isPaid => this == PaymentOrderState.paid;

  static PaymentOrderState fromValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'pending':
      case 'created':
      case 'waiting':
      case 'unpaid':
      case 'wait_buyer_pay':
      case 'processing':
        return PaymentOrderState.pending;
      case 'paid':
      case 'success':
      case 'succeeded':
      case 'completed':
      case 'complete':
      case 'trade_success':
      case 'trade_finished':
        return PaymentOrderState.paid;
      case 'failed':
      case 'error':
        return PaymentOrderState.failed;
      case 'cancelled':
      case 'canceled':
      case 'closed':
      case 'trade_closed':
        return PaymentOrderState.cancelled;
      case 'expired':
      case 'timeout':
      case 'timeout_closed':
        return PaymentOrderState.expired;
      default:
        return PaymentOrderState.unknown;
    }
  }
}
