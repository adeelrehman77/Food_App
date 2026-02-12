import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  AuthService({FlutterSecureStorage? storage, Dio? dio})
      : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ?? Dio();

  Future<void> login(String username, String password) async {
    try {
      final baseUrl = await _storage.read(key: 'baseUrl');
      if (baseUrl == null) {
        throw Exception("Base URL not found. Please connect to a kitchen first.");
      }

      // Ensure trailing slash for URL construction
      final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final loginUrl = '${cleanBaseUrl}auth/login/';

      final tenantSlug = await _storage.read(key: 'tenantSlug');
      final Map<String, dynamic> headers = {'Content-Type': 'application/json'};
      
      if (tenantSlug != null) {
        headers['X-Tenant-Slug'] = tenantSlug;
      }

      final response = await _dio.post(
        loginUrl,
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          headers: headers,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final token = data['access']; // Access Token
        final refresh = data['refresh']; // Refresh Token
        
        await _storage.write(key: 'accessToken', value: token);
        await _storage.write(key: 'refreshToken', value: refresh);
        await _storage.write(key: 'isLoggedIn', value: 'true');
      } else {
        throw Exception("Login failed: ${response.data['detail'] ?? 'Unknown error'}");
      }
    } on DioException catch (e) {
      throw Exception("Network error: ${e.message}");
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
