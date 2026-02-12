import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/api_client.dart';

class AuthService {
  final FlutterSecureStorage _storage;

  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Authenticate with username and password.
  ///
  /// Stores JWT tokens in secure storage on success.
  /// Throws [Exception] with a user-friendly message on failure.
  Future<void> login(String username, String password) async {
    final baseUrl = await _storage.read(key: 'baseUrl');
    if (baseUrl == null) {
      throw Exception("Please connect to a kitchen first.");
    }

    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final loginUrl = '${cleanBaseUrl}auth/login/';

    final tenantSlug = await _storage.read(key: 'tenantSlug');
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    if (tenantSlug != null) {
      headers['X-Tenant-Slug'] = tenantSlug;
    }

    try {
      final response = await Dio().post(
        loginUrl,
        data: {'username': username, 'password': password},
        options: Options(
          headers: headers,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _storage.write(key: 'accessToken', value: data['access']);
        await _storage.write(key: 'refreshToken', value: data['refresh']);
        await _storage.write(key: 'isLoggedIn', value: 'true');
        await _storage.write(key: 'username', value: username);
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        final detail = response.data is Map
            ? (response.data['detail'] ?? response.data['non_field_errors']?.first ?? 'Invalid credentials')
            : 'Invalid credentials';
        throw Exception(detail.toString());
      } else {
        throw Exception("Login failed. Please try again.");
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception("Connection timed out. Please check your internet.");
      }
      throw Exception("Network error. Please check your connection.");
    }
  }

  /// Clear all persisted auth data.
  Future<void> logout() async {
    await _storage.deleteAll();
    ApiClient.reset();
  }
}
