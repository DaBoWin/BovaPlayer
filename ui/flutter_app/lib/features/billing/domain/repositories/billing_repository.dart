import '../entities/billing_plan.dart';
import '../entities/payment_order.dart';
import '../entities/payment_status_snapshot.dart';
import '../entities/pricing_config.dart';

abstract class BillingRepository {
  Future<PaymentOrder> createOrder({
    required BillingPlan plan,
  });

  Future<PaymentStatusSnapshot> getOrderStatus({
    required String orderId,
  });

  Future<List<PricingConfig>> listPricingConfigs({
    bool includeInactive = false,
  });

  Future<PricingConfig> updatePricingConfig({
    required PricingConfig config,
  });
}
