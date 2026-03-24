import 'package:flutter/foundation.dart';

import '../../domain/entities/billing_plan.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/entities/payment_status_snapshot.dart';
import '../../domain/entities/pricing_config.dart';
import '../../domain/services/billing_service.dart';

class BillingProvider with ChangeNotifier {
  BillingProvider(this._billingService);

  final BillingService _billingService;

  PaymentOrder? _currentOrder;
  PaymentStatusSnapshot? _currentStatus;
  BillingPlan? _activePlan;
  String? _errorMessage;
  bool _isCreatingOrder = false;
  bool _isCheckingStatus = false;
  bool _isWaitingForPayment = false;
  bool _isLoadingPricingConfigs = false;
  bool _isUpdatingPricingConfig = false;
  List<PricingConfig> _pricingConfigs = const <PricingConfig>[];

  PaymentOrder? get currentOrder => _currentOrder;
  PaymentStatusSnapshot? get currentStatus => _currentStatus;
  BillingPlan? get activePlan => _activePlan;
  String? get errorMessage => _errorMessage;
  bool get isCreatingOrder => _isCreatingOrder;
  bool get isCheckingStatus => _isCheckingStatus;
  bool get isWaitingForPayment => _isWaitingForPayment;
  bool get isLoadingPricingConfigs => _isLoadingPricingConfigs;
  bool get isUpdatingPricingConfig => _isUpdatingPricingConfig;
  List<PricingConfig> get pricingConfigs => List<PricingConfig>.unmodifiable(_pricingConfigs);
  bool get isBusy =>
      _isCreatingOrder ||
      _isCheckingStatus ||
      _isWaitingForPayment ||
      _isLoadingPricingConfigs ||
      _isUpdatingPricingConfig;

  PricingConfig? findPricingConfig(String planId) {
    final normalizedPlanId = planId.trim();
    if (normalizedPlanId.isEmpty) return null;

    for (final config in _pricingConfigs) {
      if (config.planId == normalizedPlanId) {
        return config;
      }
    }
    return null;
  }

  Future<PaymentOrder> createOrder({
    required BillingPlan plan,
  }) async {
    debugPrint('[BillingProvider] createOrder start: plan=${plan.id}');
    try {
      _errorMessage = null;
      _activePlan = plan;
      _isCreatingOrder = true;
      notifyListeners();

      final order = await _billingService.createOrder(plan: plan);
      _currentOrder = order;
      debugPrint('[BillingProvider] createOrder success: orderId=${order.id}');
      return order;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[BillingProvider] createOrder error: $e');
      rethrow;
    } finally {
      _isCreatingOrder = false;
      notifyListeners();
    }
  }

  Future<PaymentStatusSnapshot> getOrderStatus({
    required String orderId,
  }) async {
    debugPrint('[BillingProvider] getOrderStatus start: orderId=$orderId');
    try {
      _errorMessage = null;
      _isCheckingStatus = true;
      notifyListeners();

      final status = await _billingService.getOrderStatus(orderId: orderId);
      _currentStatus = status;
      debugPrint('[BillingProvider] getOrderStatus success: orderId=$orderId state=${status.state.name} isPaid=${status.isPaid}');
      return status;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[BillingProvider] getOrderStatus error: $e');
      rethrow;
    } finally {
      _isCheckingStatus = false;
      notifyListeners();
    }
  }

  Future<List<PricingConfig>> loadPricingConfigs({
    bool includeInactive = false,
  }) async {
    debugPrint('[BillingProvider] loadPricingConfigs start: includeInactive=$includeInactive');
    try {
      _errorMessage = null;
      _isLoadingPricingConfigs = true;
      notifyListeners();

      final configs = await _billingService.listPricingConfigs(
        includeInactive: includeInactive,
      );
      _pricingConfigs = configs;
      debugPrint('[BillingProvider] loadPricingConfigs success: count=${configs.length}');
      return configs;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[BillingProvider] loadPricingConfigs error: $e');
      rethrow;
    } finally {
      _isLoadingPricingConfigs = false;
      notifyListeners();
    }
  }

  Future<PricingConfig> updatePricingConfig({
    required PricingConfig config,
  }) async {
    debugPrint('[BillingProvider] updatePricingConfig start: planId=${config.planId}');
    try {
      _errorMessage = null;
      _isUpdatingPricingConfig = true;
      notifyListeners();

      final updated = await _billingService.updatePricingConfig(config: config);
      final nextConfigs = [..._pricingConfigs];
      final existingIndex = nextConfigs.indexWhere(
        (item) => item.planId == updated.planId,
      );
      if (existingIndex >= 0) {
        nextConfigs[existingIndex] = updated;
      } else {
        nextConfigs.add(updated);
      }
      nextConfigs.sort((a, b) {
        final sortCompare = a.sortOrder.compareTo(b.sortOrder);
        if (sortCompare != 0) return sortCompare;
        return a.planId.compareTo(b.planId);
      });
      _pricingConfigs = nextConfigs;
      debugPrint('[BillingProvider] updatePricingConfig success: planId=${updated.planId}');
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[BillingProvider] updatePricingConfig error: $e');
      rethrow;
    } finally {
      _isUpdatingPricingConfig = false;
      notifyListeners();
    }
  }

  Future<PaymentStatusSnapshot> waitForPayment({
    required String orderId,
    int maxAttempts = 30,
    Duration interval = const Duration(seconds: 2),
  }) async {
    debugPrint('[BillingProvider] waitForPayment start: orderId=$orderId maxAttempts=$maxAttempts intervalMs=${interval.inMilliseconds}');
    _errorMessage = null;
    _isWaitingForPayment = true;
    notifyListeners();

    try {
      PaymentStatusSnapshot? lastStatus;
      for (var i = 0; i < maxAttempts; i++) {
        debugPrint('[BillingProvider] waitForPayment polling: orderId=$orderId attempt=${i + 1}/$maxAttempts');
        if (i > 0) {
          await Future<void>.delayed(interval);
        }

        lastStatus = await getOrderStatus(orderId: orderId);
        debugPrint('[BillingProvider] waitForPayment polled status: orderId=$orderId attempt=${i + 1}/$maxAttempts state=${lastStatus.state.name} isPaid=${lastStatus.isPaid} isTerminal=${lastStatus.isTerminal}');
        if (lastStatus.isPaid || lastStatus.isTerminal) {
          debugPrint('[BillingProvider] waitForPayment reached terminal state: orderId=$orderId state=${lastStatus.state.name}');
          return lastStatus;
        }
      }

      if (lastStatus != null) {
        debugPrint('[BillingProvider] waitForPayment exhausted attempts, returning last status: orderId=$orderId state=${lastStatus.state.name}');
        return lastStatus;
      }

      throw Exception('支付状态查询超时');
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('[BillingProvider] waitForPayment error: $e');
      rethrow;
    } finally {
      _isWaitingForPayment = false;
      notifyListeners();
    }
  }

  void clearState() {
    _currentOrder = null;
    _currentStatus = null;
    _activePlan = null;
    _errorMessage = null;
    _isCreatingOrder = false;
    _isCheckingStatus = false;
    _isWaitingForPayment = false;
    _isLoadingPricingConfigs = false;
    _isUpdatingPricingConfig = false;
    notifyListeners();
  }
}
