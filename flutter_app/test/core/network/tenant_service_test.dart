import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_app/core/network/tenant_service.dart';
import 'package:flutter/foundation.dart'; // For ValueChanged



// Fake Storage
class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _storage = {};
  
  // Missing methods implementations
  @override
  Map<String, List<ValueChanged<String?>>> get getListeners => {};

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() async => true;

  @override
  void unregisterAllListenersForKey({required String key}) {}

  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    return _storage[key];
  }
  
  @override
  Future<bool> containsKey({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => _storage.containsKey(key);

  @override
  Future<void> delete({required String key, AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => _storage.remove(key);

  @override
  Future<void> deleteAll({AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => _storage.clear();

  @override
  Future<Map<String, String>> readAll({AppleOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions, WindowsOptions? wOptions}) async => _storage;
  
  @override
  Stream<bool>? get onCupertinoProtectedDataAvailabilityChanged => null;
  
  @override
  AndroidOptions get aOptions => AndroidOptions();
  
  @override
  IOSOptions get iOptions => IOSOptions();
  
  @override
  LinuxOptions get lOptions => LinuxOptions();
  
  @override
  MacOsOptions get mOptions => MacOsOptions();
  
  @override
  WindowsOptions get wOptions => WindowsOptions();
  
  @override
  WebOptions get webOptions => WebOptions();

  @override
  void registerListener({required String key, required ValueChanged<String?> listener}) {}

  @override
  void unregisterListener({required String key, required ValueChanged<String?> listener}) {}
  
  @override
  void unregisterAllListeners() {}
}

void main() {
  group('TenantService', () {
    late TenantService content;
    late Dio mockDio;
    late FakeSecureStorage mockStorage;

    setUp(() {
      mockDio = Dio();
      mockStorage = FakeSecureStorage();
    });

    // Since we can't easily inject HttpClientAdapter into a Default Dio without
    // using a mocking library or a custom adapter, and I am creating a manual mock class,
    // let's try to simulate the response by intercepting the request.
    
    test('discoverTenant success stores baseUrl and tenantId', () async {
      mockDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.resolve(Response(
            requestOptions: options,
            data: {'api_endpoint': 'https://test.api.com', 'tenant_id': 'tenant_123'},
            statusCode: 200,
          ));
        },
      ));

      final service = TenantService(dio: mockDio, storage: mockStorage);
      await service.discoverTenant('test-kitchen');

      expect(await mockStorage.read(key: 'baseUrl'), 'https://test.api.com');
      expect(await mockStorage.read(key: 'tenantId'), 'tenant_123');
    });

    test('discoverTenant throws on 404', () async {
      mockDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
           return handler.resolve(Response(
            requestOptions: options,
            statusCode: 404,
          ));
        },
      ));

      final service = TenantService(dio: mockDio, storage: mockStorage);
      
      expect(
        () => service.discoverTenant('unknown-kitchen'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('Kitchen not found'))),
      );
    });

    test('discoverTenant throws on 403', () async {
       mockDio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
           return handler.resolve(Response(
            requestOptions: options,
            statusCode: 403,
          ));
        },
      ));

      final service = TenantService(dio: mockDio, storage: mockStorage);
      
      expect(
        () => service.discoverTenant('inactive-kitchen'),
        throwsA(isA<Exception>().having((e) => e.toString(), 'message', contains('inactive'))),
      );
    });
  });
}
