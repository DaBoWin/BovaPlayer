import '../entities/billing_plan.dart';
import '../entities/payment_order.dart';
import '../entities/payment_status_snapshot.dart';

abstract class BillingRepository {
  Future<PaymentOrder> createOrder({
    required BillingPlan plan,
  });

  Future<PaymentStatusSnapshot> getOrderStatus({
    required String orderId,
  });
}
