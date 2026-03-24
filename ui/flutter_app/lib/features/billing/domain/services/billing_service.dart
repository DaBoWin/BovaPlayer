import '../entities/billing_plan.dart';
import '../entities/payment_order.dart';
import '../entities/payment_status_snapshot.dart';
import '../entities/pricing_config.dart';
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

  Future<List<PricingConfig>> listPricingConfigs({
    bool includeInactive = false,
  }) {
    return _repository.listPricingConfigs(includeInactive: includeInactive);
  }

  Future<PricingConfig> updatePricingConfig({
    required PricingConfig config,
  }) async {
    if (config.planId.trim().isEmpty) {
      throw Exception('套餐标识不能为空');
    }
    if (config.displayName.trim().isEmpty) {
      throw Exception('套餐名称不能为空');
    }
    if (config.priceCny < 0) {
      throw Exception('套餐价格不能为负数');
    }

    return _repository.updatePricingConfig(config: config);
  }
}
