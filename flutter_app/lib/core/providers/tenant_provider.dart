import 'package:flutter/material.dart';
import '../network/tenant_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TenantProvider extends ChangeNotifier {
  final TenantService _tenantService;
  final FlutterSecureStorage _storage;

  String? _tenantId;
  String? _tenantName;

  TenantProvider({TenantService? tenantService, FlutterSecureStorage? storage})
      : _tenantService = tenantService ?? TenantService(),
        _storage = storage ?? const FlutterSecureStorage();

  String? get tenantId => _tenantId;
  String? get tenantName => _tenantName;

  Future<void> loadTenant() async {
    _tenantId = await _storage.read(key: 'tenantId');
    _tenantName = await _storage.read(key: 'tenantName'); // Assuming we save this
    notifyListeners();
  }

  Future<void> setTenant(String id, String name) async {
    _tenantId = id;
    _tenantName = name;
    await _storage.write(key: 'tenantId', value: id);
    await _storage.write(key: 'tenantName', value: name);
    
    // Check for test_kitchen slug
    if (id == 'test_kitchen') {
       await _storage.write(key: 'baseUrl', value: 'http://127.0.0.1:8000/api/v1/');
       await _storage.write(key: 'tenantSlug', value: 'test_kitchen');
    } else {
       await _storage.delete(key: 'tenantSlug');
    }
    
    notifyListeners();
  }

  Future<void> clearTenant() async {
    _tenantId = null;
    _tenantName = null;
    await _storage.delete(key: 'tenantId');
    await _storage.delete(key: 'tenantName');
    notifyListeners();
  }
}
