import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../domain/models.dart';

/// Repository for all SaaS Owner (/api/saas/) API calls.
/// No tenant header is sent — these operate on the shared database.
class SaasRepository {
  final ApiClient _client;

  SaasRepository({ApiClient? client}) : _client = client ?? ApiClient();

  String get _baseUrl {
    // SaaS endpoints are at /api/saas/, not /api/v1/
    final base = AppConfig.current.apiBaseUrl; // e.g. http://127.0.0.1:8000/api/v1/
    // Go up one level from /api/v1/ to /api/ then add saas/
    final apiRoot = base.replaceAll(RegExp(r'v1/?$'), '');
    return '${apiRoot}saas/';
  }

  /// Extracts a user-friendly error message from a DioException.
  /// DRF returns errors like {"field": ["message"]} on 400.
  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final messages = <String>[];
      data.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          messages.add('$key: ${value.join(', ')}');
        } else {
          messages.add('$key: $value');
        }
      });
      if (messages.isNotEmpty) return messages.join('\n');
    }
    if (data is String && data.isNotEmpty) return data;
    return e.message ?? 'Request failed';
  }

  /// Wraps a Dio call, converting DioExceptions to readable exceptions.
  Future<T> _call<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ─── Analytics ────────────────────────────────────────────────────────

  Future<PlatformAnalytics> getAnalytics() => _call(() async {
        final response = await _client.dio.get('${_baseUrl}analytics/');
        return PlatformAnalytics.fromJson(response.data);
      });

  // ─── Tenants ──────────────────────────────────────────────────────────

  Future<List<Tenant>> getTenants({String? search}) => _call(() async {
        final params = <String, dynamic>{};
        if (search != null && search.isNotEmpty) params['search'] = search;
        final response = await _client.dio
            .get('${_baseUrl}tenants/', queryParameters: params);
        final results = response.data['results'] ?? response.data;
        return (results as List).map((e) => Tenant.fromJson(e)).toList();
      });

  Future<TenantDetail> getTenantDetail(int id) => _call(() async {
        final response = await _client.dio.get('${_baseUrl}tenants/$id/');
        return TenantDetail.fromJson(response.data);
      });

  Future<TenantDetail> createTenant({
    required String name,
    required String subdomain,
    required String adminEmail,
    String? adminPassword,
    int? planId,
  }) =>
      _call(() async {
        final response = await _client.dio.post('${_baseUrl}tenants/', data: {
          'name': name,
          'subdomain': subdomain,
          'admin_email': adminEmail,
          if (adminPassword?.isNotEmpty ?? false) 'admin_password': adminPassword!,
          if (planId != null) 'plan_id': planId,
        });
        return TenantDetail.fromJson(response.data);
      });

  Future<void> suspendTenant(int id) => _call(() async {
        await _client.dio.post('${_baseUrl}tenants/$id/suspend/');
      });

  Future<void> activateTenant(int id) => _call(() async {
        await _client.dio.post('${_baseUrl}tenants/$id/activate/');
      });

  Future<TenantDetail> updateTenant(int id, Map<String, dynamic> data) =>
      _call(() async {
        final response =
            await _client.dio.patch('${_baseUrl}tenants/$id/', data: data);
        return TenantDetail.fromJson(response.data);
      });

  Future<List<TenantUsage>> getTenantUsage(int tenantId) => _call(() async {
        final response =
            await _client.dio.get('${_baseUrl}tenants/$tenantId/usage/');
        final results =
            response.data is List ? response.data : (response.data['results'] ?? []);
        return (results as List).map((e) => TenantUsage.fromJson(e)).toList();
      });

  // ─── Plans ────────────────────────────────────────────────────────────

  Future<List<ServicePlan>> getPlans() => _call(() async {
        final response = await _client.dio.get('${_baseUrl}plans/');
        final results = response.data['results'] ?? response.data;
        return (results as List).map((e) => ServicePlan.fromJson(e)).toList();
      });

  Future<ServicePlan> createPlan(Map<String, dynamic> data) =>
      _call(() async {
        final response =
            await _client.dio.post('${_baseUrl}plans/', data: data);
        return ServicePlan.fromJson(response.data);
      });

  Future<ServicePlan> updatePlan(int id, Map<String, dynamic> data) =>
      _call(() async {
        final response =
            await _client.dio.patch('${_baseUrl}plans/$id/', data: data);
        return ServicePlan.fromJson(response.data);
      });

  Future<void> deletePlan(int id) => _call(() async {
        await _client.dio.delete('${_baseUrl}plans/$id/');
      });

  // ─── Invoices ─────────────────────────────────────────────────────────

  Future<void> markInvoicePaid(int id) => _call(() async {
        await _client.dio.post('${_baseUrl}invoices/$id/mark_paid/');
      });
}
