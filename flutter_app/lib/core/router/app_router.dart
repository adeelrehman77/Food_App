import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/dashboard_shell.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/auth/presentation/tenant_login_screen.dart';
import '../../features/auth/presentation/user_login_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const TenantLoginScreen(),
    ),
    GoRoute(
      path: '/user-login',
      builder: (context, state) => const UserLoginScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return DashboardShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Center(child: Text('Dashboard Overview')),
          ),
        ),
        GoRoute(
          path: '/orders',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Center(child: Text('Orders Screen')),
          ),
        ),
        GoRoute(
          path: '/menu',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MenuScreen(),
          ),
        ),
        GoRoute(
          path: '/inventory',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Center(child: Text('Inventory Screen')),
          ),
        ),
        GoRoute(
          path: '/delivery',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Center(child: Text('Delivery Screen')),
          ),
        ),
        GoRoute(
          path: '/customers',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Center(child: Text('Customers Screen')),
          ),
        ),
        GoRoute(
          path: '/finance',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Center(child: Text('Finance Screen')),
          ),
        ),
      ],
    ),
  ],
);
