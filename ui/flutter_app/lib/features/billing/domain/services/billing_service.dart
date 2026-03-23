import '../entities/billing_plan.dart';
import '../entities/payment_order.dart';
import '../entities/payment_status_snapshot.dart';
import '../repositories/billing_repository.dart';

class BillingService {
  BillingService(this._repository);

  final BillingRepository _repository;

  Future<PaymentOrder> createOrder({
    required BillingPlan plan,
  }) async {
    if (plan == BillingPlan.free) {
      throw Exception('免费方案无需创建支付订单');
    }

    return _repository.createOrder(plan: plan);
  }

  Future<PaymentStatusSnapshot> getOrderStatus({
    required String orderId,
  }) async {
    if (orderId.trim().isEmpty) {
      throw Exception('订单号不能为空');
    }

    return _repository.getOrderStatus(orderId: orderId.trim());
  }
}
