import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../features/dashboard/presentation/dashboard_shell.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/auth/presentation/tenant_login_screen.dart';
import '../../features/auth/presentation/user_login_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isLoggedIn = authProvider.isLoggedIn;
      final isOnLogin = state.matchedLocation == '/login' ||
          state.matchedLocation == '/user-login';

      // Not logged in and trying to access a protected route
      if (!isLoggedIn && !isOnLogin) {
        return '/login';
      }

      // Already logged in but on login page — redirect to dashboard
      if (isLoggedIn && isOnLogin) {
        return '/dashboard';
      }

      return null; // No redirect
    },
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
              child: Center(
                child: Text(
                  'Dashboard Overview',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Center(
                child: Text(
                  'Orders — Coming Soon',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
              ),
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
              child: Center(
                child: Text(
                  'Inventory — Coming Soon',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/delivery',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Center(
                child: Text(
                  'Delivery — Coming Soon',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/customers',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Center(
                child: Text(
                  'Customers — Coming Soon',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/finance',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: Center(
                child: Text(
                  'Finance — Coming Soon',
                  style: TextStyle(fontSize: 24, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
