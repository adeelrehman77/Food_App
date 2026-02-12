import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class TenantService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  TenantService({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  /// Discovers a tenant by its slug/kitchen code.
  ///
  /// Returns the tenant display name on success.
  /// Throws [Exception] with a user-friendly message on failure.
  Future<String> discoverTenant(String slug) async {
    final discoveryUrl = AppConfig.current.discoveryUrl;

    try {
      final response = await _dio.post(
        discoveryUrl,
        data: {'kitchen_code': slug},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final String apiEndpoint = data['api_endpoint'];
        final String tenantId = data['tenant_id'];
        final String? name = data['name'];

        await _storage.write(key: 'baseUrl', value: apiEndpoint);
        await _storage.write(key: 'tenantId', value: tenantId);
        await _storage.write(key: 'tenantSlug', value: tenantId);
        if (name != null) {
          await _storage.write(key: 'tenantName', value: name);
        }

        return name ?? slug;
      } else if (response.statusCode == 404) {
        throw Exception("Kitchen not found. Please check the code and try again.");
      } else if (response.statusCode == 403) {
        throw Exception("This kitchen is currently inactive.");
      } else {
        throw Exception("Something went wrong. Please try again later.");
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception("Connection timed out. Please check your internet.");
      }
      throw Exception("Network error. Please check your connection.");
    }
  }
}
