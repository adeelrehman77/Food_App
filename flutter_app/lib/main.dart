import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart'; // Add this to pubspec.yaml
import 'core/router/app_router.dart';
import 'core/providers/tenant_provider.dart'; // We'll create this next
import 'core/theme/app_theme.dart';          // We'll create this next

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Here we would eventually initialize local storage/secure storage
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TenantProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fun Adventure Admin',
      // High-end enterprise theme
      theme: AppTheme.lightTheme, 
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}