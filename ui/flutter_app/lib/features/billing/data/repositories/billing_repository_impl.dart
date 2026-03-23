import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env_config.dart';
import '../../domain/entities/billing_plan.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/entities/payment_status_snapshot.dart';
import '../../domain/repositories/billing_repository.dart';
import '../models/payment_order_model.dart';
import '../models/payment_status_model.dart';

class BillingRepositoryImpl implements BillingRepository {
  BillingRepositoryImpl({
    http.Client? client,
    SupabaseClient? supabase,
  })  : _client = client ?? http.Client(),
        _supabase = supabase ?? Supabase.instance.client;

  final http.Client _client;
  final SupabaseClient _supabase;

  @override
  Future<PaymentOrder> createOrder({
    required BillingPlan plan,
  }) async {
    final response = await _client
        .post(
          _buildUri('/api/payment/create'),
          headers: _buildHeaders(),
          body: jsonEncode({
            'plan': plan.id,
            'payment_method': 'alipay',
          }),
        )
        .timeout(const Duration(seconds: 15));

    final payload = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(payload, fallback: '创建支付订单失败'));
    }

    final data = _unwrapPayload(payload);
    final order = PaymentOrderModel.fromJson(data);
    if (order.id.trim().isEmpty || order.paymentUrl.trim().isEmpty) {
      throw Exception('支付订单响应不完整');
    }

    return order;
  }

  @override
  Future<PaymentStatusSnapshot> getOrderStatus({
    required String orderId,
  }) async {
    final response = await _client
        .get(
          _buildUri('/api/payment/status/${Uri.encodeComponent(orderId)}'),
          headers: _buildHeaders(),
        )
        .timeout(const Duration(seconds: 12));

    final payload = _decodeJsonMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(payload, fallback: '查询支付状态失败'));
    }

    final data = _unwrapPayload(payload);
    final snapshot = PaymentStatusModel.fromJson({
      ...data,
      if (!_hasOrderId(data)) 'order_id': orderId,
    });

    return snapshot;
  }

  Uri _buildUri(String path) {
    final normalizedBase = EnvConfig.apiBaseUrl.endsWith('/')
        ? EnvConfig.apiBaseUrl
        : '${EnvConfig.apiBaseUrl}/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse(normalizedBase).resolve(normalizedPath);
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'User-Agent': 'BovaPlayer/1.0',
    };

    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    return <String, dynamic>{
      'data': decoded,
    };
  }

  Map<String, dynamic> _unwrapPayload(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return payload;
  }

  bool _hasOrderId(Map<String, dynamic> payload) {
    final orderId = payload['order_id'] ?? payload['id'];
    return orderId != null && orderId.toString().trim().isNotEmpty;
  }

  String _extractErrorMessage(
    Map<String, dynamic> payload, {
    required String fallback,
  }) {
    for (final key in const ['message', 'error', 'detail']) {
      final value = payload[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    final data = payload['data'];
    if (data is Map) {
      for (final key in const ['message', 'error', 'detail']) {
        final value = data[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    return fallback;
  }
}
