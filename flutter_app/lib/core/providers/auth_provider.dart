import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized authentication state management.
///
/// Tracks whether the user is logged in and provides login / logout helpers.
/// The router reads [isLoggedIn] to enforce route guards.
class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage;

  bool _isLoggedIn = false;
  bool _isInitialized = false;
  String? _username;
  List<String> _groups = [];

  AuthProvider({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String? get username => _username;
  List<String> get groups => _groups;

  bool get isDriver => _groups.contains('Driver');

  /// Call once at app startup to restore persisted session.
  Future<void> initialize() async {
    final token = await _storage.read(key: 'accessToken');
    final loggedIn = await _storage.read(key: 'isLoggedIn');
    _isLoggedIn = token != null && loggedIn == 'true';
    _username = await _storage.read(key: 'username');
    
    final groupsStr = await _storage.read(key: 'userGroups');
    _groups = groupsStr?.split(',') ?? [];
    
    _isInitialized = true;
    notifyListeners();
  }

  /// Mark the user as authenticated after a successful login.
  Future<void> onLoginSuccess({String? username}) async {
    _isLoggedIn = true;
    _username = username;
    await _storage.write(key: 'isLoggedIn', value: 'true');
    if (username != null) {
      await _storage.write(key: 'username', value: username);
    }
    
    // Refresh groups from storage as AuthService just wrote them
    final groupsStr = await _storage.read(key: 'userGroups');
    _groups = groupsStr?.split(',') ?? [];
    
    notifyListeners();
  }

  /// Clear all persisted tokens and reset state.
  Future<void> logout() async {
    _isLoggedIn = false;
    _username = null;
    _groups = [];
    await _storage.deleteAll();
    notifyListeners();
  }
}
