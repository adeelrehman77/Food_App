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

  // ─── Analytics ────────────────────────────────────────────────────────

  Future<PlatformAnalytics> getAnalytics() async {
    final response = await _client.dio.get('${_baseUrl}analytics/');
    return PlatformAnalytics.fromJson(response.data);
  }

  // ─── Tenants ──────────────────────────────────────────────────────────

  Future<List<Tenant>> getTenants({String? search}) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _client.dio.get('${_baseUrl}tenants/', queryParameters: params);
    final results = response.data['results'] ?? response.data;
    return (results as List).map((e) => Tenant.fromJson(e)).toList();
  }

  Future<TenantDetail> getTenantDetail(int id) async {
    final response = await _client.dio.get('${_baseUrl}tenants/$id/');
    return TenantDetail.fromJson(response.data);
  }

  Future<TenantDetail> createTenant({
    required String name,
    required String subdomain,
    required String adminEmail,
    int? planId,
  }) async {
    final response = await _client.dio.post('${_baseUrl}tenants/', data: {
      'name': name,
      'subdomain': subdomain,
      'admin_email': adminEmail,
      if (planId != null) 'plan_id': planId,
    });
    return TenantDetail.fromJson(response.data);
  }

  Future<void> suspendTenant(int id) async {
    await _client.dio.post('${_baseUrl}tenants/$id/suspend/');
  }

  Future<void> activateTenant(int id) async {
    await _client.dio.post('${_baseUrl}tenants/$id/activate/');
  }

  Future<TenantDetail> updateTenant(int id, Map<String, dynamic> data) async {
    final response = await _client.dio.patch('${_baseUrl}tenants/$id/', data: data);
    return TenantDetail.fromJson(response.data);
  }

  Future<List<TenantUsage>> getTenantUsage(int tenantId) async {
    final response = await _client.dio.get('${_baseUrl}tenants/$tenantId/usage/');
    final results = response.data is List ? response.data : (response.data['results'] ?? []);
    return (results as List).map((e) => TenantUsage.fromJson(e)).toList();
  }

  // ─── Plans ────────────────────────────────────────────────────────────

  Future<List<ServicePlan>> getPlans() async {
    final response = await _client.dio.get('${_baseUrl}plans/');
    final results = response.data['results'] ?? response.data;
    return (results as List).map((e) => ServicePlan.fromJson(e)).toList();
  }

  Future<ServicePlan> createPlan(Map<String, dynamic> data) async {
    final response = await _client.dio.post('${_baseUrl}plans/', data: data);
    return ServicePlan.fromJson(response.data);
  }

  Future<ServicePlan> updatePlan(int id, Map<String, dynamic> data) async {
    final response = await _client.dio.patch('${_baseUrl}plans/$id/', data: data);
    return ServicePlan.fromJson(response.data);
  }

  Future<void> deletePlan(int id) async {
    await _client.dio.delete('${_baseUrl}plans/$id/');
  }

  // ─── Invoices ─────────────────────────────────────────────────────────

  Future<void> markInvoicePaid(int id) async {
    await _client.dio.post('${_baseUrl}invoices/$id/mark_paid/');
  }
}
