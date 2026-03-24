import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/env_config.dart';
import '../../domain/entities/billing_plan.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/entities/payment_status_snapshot.dart';
import '../../domain/entities/pricing_config.dart';
import '../../domain/repositories/billing_repository.dart';
import '../models/payment_order_model.dart';
import '../models/payment_status_model.dart';
import '../models/pricing_config_model.dart';

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
    final uri = _buildUri('/api/payment/create');
    final headers = _buildHeaders();
    final requestBody = jsonEncode({
      'plan': plan.id,
      'payment_method': 'alipay',
    });
    debugPrint('[BillingRepo] createOrder request: uri=$uri plan=${plan.id} hasAuth=${headers.containsKey('Authorization')}');

    final response = await _client
        .post(
          uri,
          headers: headers,
          body: requestBody,
        )
        .timeout(const Duration(seconds: 15));

    debugPrint('[BillingRepo] createOrder response: status=${response.statusCode} contentType=${response.headers['content-type']} bodyPreview=${_bodyPreview(response)}');

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
    final uri = _buildUri('/api/payment/status/${Uri.encodeComponent(orderId)}');
    final headers = _buildHeaders();
    debugPrint('[BillingRepo] getOrderStatus request: uri=$uri orderId=$orderId hasAuth=${headers.containsKey('Authorization')}');

    final response = await _client
        .get(
          uri,
          headers: headers,
        )
        .timeout(const Duration(seconds: 12));

    debugPrint('[BillingRepo] getOrderStatus response: status=${response.statusCode} contentType=${response.headers['content-type']} bodyPreview=${_bodyPreview(response)}');

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

  @override
  Future<List<PricingConfig>> listPricingConfigs({
    bool includeInactive = false,
  }) async {
    debugPrint('[BillingRepo] listPricingConfigs request: includeInactive=$includeInactive');
    final response = await _supabase.rpc(
      'list_pricing_configs',
      params: <String, dynamic>{
        'p_include_inactive': includeInactive,
      },
    );

    final payload = _asMap(response);
    final rawPlans = payload['plans'] ?? payload['data'] ?? payload['result'];
    final planList = _asList(rawPlans);

    return planList
        .map((item) => PricingConfigModel.fromJson(_asMap(item)))
        .where((item) => item.planId.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<PricingConfig> updatePricingConfig({
    required PricingConfig config,
  }) async {
    final model = config is PricingConfigModel
        ? config
        : PricingConfigModel(
            planId: config.planId,
            displayName: config.displayName,
            description: config.description,
            priceCny: config.priceCny,
            currency: config.currency,
            billingPeriod: config.billingPeriod,
            subject: config.subject,
            body: config.body,
            subscriptionType: config.subscriptionType,
            accountType: config.accountType,
            durationDays: config.durationDays,
            maxServers: config.maxServers,
            maxDevices: config.maxDevices,
            storageQuotaMb: config.storageQuotaMb,
            isActive: config.isActive,
            sortOrder: config.sortOrder,
            metadata: config.metadata,
          );

    debugPrint('[BillingRepo] updatePricingConfig request: planId=${config.planId} price=${config.priceCny} isActive=${config.isActive}');
    final response = await _supabase.rpc(
      'update_pricing_config',
      params: model.toRpcParams(),
    );

    final payload = _asMap(response);
    final data = _unwrapPayload(payload);
    final updated = PricingConfigModel.fromJson(data);
    if (updated.planId.trim().isEmpty) {
      throw Exception('更新价格配置失败');
    }
    return updated;
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
    debugPrint('[BillingRepo] _buildHeaders session state: hasSession=${_supabase.auth.currentSession != null} hasAccessToken=${accessToken != null && accessToken.isNotEmpty} userId=${_supabase.auth.currentUser?.id}');
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return const <String, dynamic>{};
    }

    final body = utf8.decode(response.bodyBytes);
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      return <String, dynamic>{
        'data': decoded,
      };
    } on FormatException catch (error) {
      debugPrint('[BillingRepo] _decodeJsonMap format error: $error bodyPreview=${_stringPreview(body)}');
      rethrow;
    }
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

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) {
      return value;
    }
    return const <dynamic>[];
  }

  String _bodyPreview(http.Response response) =>
      _stringPreview(utf8.decode(response.bodyBytes));

  String _stringPreview(String value, {int maxLength = 240}) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxLength) {
      return normalized;
    }
    return '${normalized.substring(0, maxLength)}...';
  }
}
