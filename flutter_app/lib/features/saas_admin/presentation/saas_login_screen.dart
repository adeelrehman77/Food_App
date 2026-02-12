import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/auth_provider.dart';

/// Login screen for the SaaS Platform Owner (superuser).
///
/// This screen authenticates directly against the main API — no tenant
/// discovery or X-Tenant-Slug header is needed.
class SaasLoginScreen extends StatefulWidget {
  const SaasLoginScreen({super.key});

  @override
  State<SaasLoginScreen> createState() => _SaasLoginScreenState();
}

class _SaasLoginScreenState extends State<SaasLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // Authenticate directly against the main API (no tenant header)
      final baseUrl = AppConfig.current.apiBaseUrl;
      final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      final loginUrl = '${cleanBase}auth/login/';

      final response = await Dio().post(
        loginUrl,
        data: {
          'username': _usernameCtrl.text.trim(),
          'password': _passwordCtrl.text.trim(),
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (s) => s! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _storage.write(key: 'accessToken', value: data['access']);
        await _storage.write(key: 'refreshToken', value: data['refresh']);
        await _storage.write(key: 'isLoggedIn', value: 'true');
        await _storage.write(
            key: 'username', value: _usernameCtrl.text.trim());
        // Store baseUrl so ApiClient can use it (no tenant slug)
        await _storage.write(key: 'baseUrl', value: cleanBase);
        // Mark as SaaS admin session
        await _storage.write(key: 'isSaasAdmin', value: 'true');

        if (!mounted) return;
        await context
            .read<AuthProvider>()
            .onLoginSuccess(username: _usernameCtrl.text.trim());

        // Navigate to SaaS dashboard
        if (mounted) context.go('/saas');
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        final detail = response.data is Map
            ? (response.data['detail'] ??
                response.data['non_field_errors']?.first ??
                'Invalid credentials')
            : 'Invalid credentials';
        _showError(detail.toString());
      } else {
        _showError('Login failed. Please try again.');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        _showError('Connection timed out. Check your network.');
      } else {
        _showError('Network error. Please check your connection.');
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F51B5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      size: 48, color: Color(0xFF3F51B5)),
                ),
                const SizedBox(height: 20),

                Text(
                  'Platform Admin',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1D2E),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in with your superuser account',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 32),

                // Username
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  textInputAction: TextInputAction.go,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Required' : null,
                  onFieldSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 28),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sign In',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),

                // Back to tenant login
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text(
                    'Back to Kitchen Login',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
