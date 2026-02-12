import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

/// Singleton API client that handles:
/// - Auth token injection
/// - Tenant header injection
/// - Token refresh on 401
/// - Centralized error handling & logging
class ApiClient {
  static ApiClient? _instance;
  late final Dio dio;
  final FlutterSecureStorage _storage;

  ApiClient._internal({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(_AuthInterceptor(_storage));

    if (AppConfig.current.enableLogging) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  factory ApiClient({FlutterSecureStorage? storage}) {
    _instance ??= ApiClient._internal(storage: storage);
    return _instance!;
  }

  /// Reset singleton (useful for logout).
  static void reset() {
    _instance = null;
  }

  /// Get the resolved base URL for the current tenant.
  /// Falls back to the configured default if no tenant base URL is stored.
  Future<String> getBaseUrl() async {
    final storedUrl = await _storage.read(key: 'baseUrl');
    return storedUrl ?? AppConfig.current.apiBaseUrl;
  }
}

/// Interceptor that attaches auth tokens and tenant headers to every request,
/// and attempts a token refresh on 401.
class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  bool _isRefreshing = false;

  _AuthInterceptor(this._storage);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'accessToken');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    final tenantSlug = await _storage.read(key: 'tenantSlug');
    if (tenantSlug != null) {
      options.headers['X-Tenant-Slug'] = tenantSlug;
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          // Retry the original request with new token
          final token = await _storage.read(key: 'accessToken');
          err.requestOptions.headers['Authorization'] = 'Bearer $token';
          final response = await Dio().fetch(err.requestOptions);
          _isRefreshing = false;
          return handler.resolve(response);
        }
      } catch (_) {
        // Refresh failed — clear session
        await _storage.deleteAll();
      }
      _isRefreshing = false;
    }
    handler.next(err);
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _storage.read(key: 'refreshToken');
    if (refreshToken == null) return false;

    try {
      final baseUrl = await _storage.read(key: 'baseUrl');
      if (baseUrl == null) return false;

      final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final response = await Dio().post(
        '${cleanBase}auth/token/refresh/',
        data: {'refresh': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        await _storage.write(
            key: 'accessToken', value: response.data['access']);
        if (response.data['refresh'] != null) {
          await _storage.write(
              key: 'refreshToken', value: response.data['refresh']);
        }
        return true;
      }
    } catch (_) {
      // Refresh call itself failed
    }
    return false;
  }
}
