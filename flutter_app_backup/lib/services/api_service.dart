import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  late Dio _dio;
  final _storage = const FlutterSecureStorage();
  
  // Default fallback or global base URL
  final String _defaultBaseUrl = "https://api.funadventure.ae/api/v1/";

  ApiService() {
    _dio = Dio(BaseOptions(baseUrl: _defaultBaseUrl));
    _initializeInterceptors();
  }

  /// Refreshes the base URL from secure storage. 
  /// Called after successful tenant discovery.
  Future<void> refreshBaseUrl() async {
    String? tenantUrl = await _storage.read(key: 'baseUrl');
    if (tenantUrl != null) {
      _dio.options.baseUrl = tenantUrl;
    }
  }

  void _initializeInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 1. Fetch Tenant ID from secure storage
          String? tenantId = await _storage.read(key: 'tenantId');
          String? authToken = await _storage.read(key: 'authToken');

          // 2. Inject into headers
          if (tenantId != null) {
            options.headers['X-Tenant-ID'] = tenantId;
          }
          
          if (authToken != null) {
            options.headers['Authorization'] = 'Bearer $authToken';
          }

          print("Request to: ${options.uri}");
          return handler.next(options);
        },
        onError: (DioError e, handler) {
          // Handle 403 Forbidden (Inactive tenant) here
          if (e.response?.statusCode == 403) {
            print("Access denied: Tenant might be inactive.");
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Example API call
  Future<Response> getOrders() async {
    await refreshBaseUrl(); // Ensure we use the latest discovered URL
    return _dio.get('orders/');
  }
}
