import 'package:flutter/foundation.dart';

import '../../domain/entities/billing_plan.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/entities/payment_status_snapshot.dart';
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

  PaymentOrder? get currentOrder => _currentOrder;
  PaymentStatusSnapshot? get currentStatus => _currentStatus;
  BillingPlan? get activePlan => _activePlan;
  String? get errorMessage => _errorMessage;
  bool get isCreatingOrder => _isCreatingOrder;
  bool get isCheckingStatus => _isCheckingStatus;
  bool get isWaitingForPayment => _isWaitingForPayment;
  bool get isBusy =>
      _isCreatingOrder || _isCheckingStatus || _isWaitingForPayment;

  Future<PaymentOrder> createOrder({
    required BillingPlan plan,
  }) async {
    try {
      _errorMessage = null;
      _activePlan = plan;
      _isCreatingOrder = true;
      notifyListeners();

      final order = await _billingService.createOrder(plan: plan);
      _currentOrder = order;
      return order;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isCreatingOrder = false;
      notifyListeners();
    }
  }

  Future<PaymentStatusSnapshot> getOrderStatus({
    required String orderId,
  }) async {
    try {
      _errorMessage = null;
      _isCheckingStatus = true;
      notifyListeners();

      final status = await _billingService.getOrderStatus(orderId: orderId);
      _currentStatus = status;
      return status;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isCheckingStatus = false;
      notifyListeners();
    }
  }

  Future<PaymentStatusSnapshot> waitForPayment({
    required String orderId,
    int maxAttempts = 30,
    Duration interval = const Duration(seconds: 2),
  }) async {
    _errorMessage = null;
    _isWaitingForPayment = true;
    notifyListeners();

    try {
      PaymentStatusSnapshot? lastStatus;
      for (var i = 0; i < maxAttempts; i++) {
        if (i > 0) {
          await Future<void>.delayed(interval);
        }

        lastStatus = await getOrderStatus(orderId: orderId);
        if (lastStatus.isPaid || lastStatus.isTerminal) {
          return lastStatus;
        }
      }

      if (lastStatus != null) {
        return lastStatus;
      }

      throw Exception('支付状态查询超时');
    } catch (e) {
      _errorMessage = e.toString();
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
    notifyListeners();
  }
}
