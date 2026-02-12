import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages the currently connected tenant (kitchen) state.
class TenantProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage;

  String? _tenantId;
  String? _tenantName;

  TenantProvider({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  String? get tenantId => _tenantId;
  String? get tenantName => _tenantName;
  bool get hasTenant => _tenantId != null;

  /// Restore tenant info from secure storage on app startup.
  Future<void> loadTenant() async {
    _tenantId = await _storage.read(key: 'tenantId');
    _tenantName = await _storage.read(key: 'tenantName');
    notifyListeners();
  }

  /// Set the current tenant after a successful discovery.
  Future<void> setTenant(String id, String name) async {
    _tenantId = id;
    _tenantName = name;
    await _storage.write(key: 'tenantId', value: id);
    await _storage.write(key: 'tenantName', value: name);
    notifyListeners();
  }

  /// Clear tenant data (used during logout).
  Future<void> clearTenant() async {
    _tenantId = null;
    _tenantName = null;
    await _storage.delete(key: 'tenantId');
    await _storage.delete(key: 'tenantName');
    await _storage.delete(key: 'tenantSlug');
    await _storage.delete(key: 'baseUrl');
    notifyListeners();
  }
}
