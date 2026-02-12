import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/router/app_router.dart';
import 'core/providers/tenant_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize auth provider and restore persisted session
  final authProvider = AuthProvider();
  await authProvider.initialize();

  // Wire the API client's auth failure callback to the auth provider.
  // When token refresh fails, the interceptor calls this to force logout,
  // which triggers the router redirect to /login.
  ApiClient.onAuthFailure = () => authProvider.logout();

  // Restore tenant info
  final tenantProvider = TenantProvider();
  await tenantProvider.loadTenant();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: tenantProvider),
      ],
      child: MyApp(authProvider: authProvider),
    ),
  );
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;

  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fun Adventure Admin',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: buildRouter(authProvider),
      debugShowCheckedModeBanner: false,
    );
  }
}
