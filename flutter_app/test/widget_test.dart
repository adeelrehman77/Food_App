import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/features/dashboard/presentation/dashboard_shell.dart';
import 'package:flutter_app/features/menu/presentation/menu_screen.dart';
import 'package:flutter_app/features/menu/presentation/widgets/food_item_card.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'http_overrides.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  // Test 1: App starts at Login Screen
  testWidgets('App starts at Login Screen', (WidgetTester tester) async {
    // Set desktop size
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Kitchen Login'), findsOneWidget);
    expect(find.text('Kitchen Slug'), findsOneWidget);
    
    // Reset window size cleanup
    addTearDown(tester.view.resetPhysicalSize);
  });

  // Test 2: Dashboard renders correctly (using a test router)
  testWidgets('Dashboard Shell renders correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    final testRouter = GoRouter(
      initialLocation: '/dashboard',
      routes: [
         ShellRoute(
          builder: (context, state, child) => DashboardShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const Center(child: Text('Dashboard Overview')),
            ),
            GoRoute(
              path: '/menu',
              builder: (context, state) => const MenuScreen(),
            ),
             // Add empty valid routes for Sidebar navigation to prevent crashes
            GoRoute(path: '/orders', builder: (c, s) => Container()),
            GoRoute(path: '/inventory', builder: (c, s) => Container()),
            GoRoute(path: '/delivery', builder: (c, s) => Container()),
            GoRoute(path: '/customers', builder: (c, s) => Container()),
            GoRoute(path: '/finance', builder: (c, s) => Container()),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: testRouter,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
         textTheme: GoogleFonts.poppinsTextTheme(),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Kitchen: Downtown Branch'), findsOneWidget);
    
    // Verify Sidebar (Desktop)
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Menu'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
  });
}
