import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TenantService {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  
  // Endpoint for tenant discovery
  // static const String _discoveryUrl = "https://api.funadventure.ae/discover/";
  static const String _discoveryUrl = "http://127.0.0.1:8000/api/discover/"; // Local for testing

  TenantService({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<void> discoverTenant(String slug) async {
    try {
      final response = await _dio.post(
        _discoveryUrl,
        data: {'kitchen_code': slug}, // Assuming 'slug' maps to 'kitchen_code'
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500, // Handle 4xx manually
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final String apiEndpoint = data['api_endpoint'];
        final String tenantId = data['tenant_id'];

        await _storage.write(key: 'baseUrl', value: apiEndpoint);
        await _storage.write(key: 'tenantId', value: tenantId);
      } else if (response.statusCode == 404) {
        throw Exception("Kitchen not found. Please check the code and try again.");
      } else if (response.statusCode == 403) {
        throw Exception("This kitchen is currently inactive.");
      } else {
        throw Exception("Failed to discover tenant. Error: ${response.statusCode}");
      }
    } on DioException catch (e) {
      throw Exception("Network error: ${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
