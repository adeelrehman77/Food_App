import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

// Tenant admin screens
import '../../features/dashboard/presentation/dashboard_shell.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/auth/presentation/tenant_login_screen.dart';
import '../../features/auth/presentation/user_login_screen.dart';

// SaaS Owner screens
import '../../features/saas_admin/presentation/saas_shell.dart';
import '../../features/saas_admin/presentation/saas_overview_screen.dart';
import '../../features/saas_admin/presentation/tenants_screen.dart';
import '../../features/saas_admin/presentation/tenant_detail_screen.dart';
import '../../features/saas_admin/presentation/plans_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _saasShellKey = GlobalKey<NavigatorState>();

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
      // ─── Auth ───────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const TenantLoginScreen(),
      ),
      GoRoute(
        path: '/user-login',
        builder: (context, state) => const UserLoginScreen(),
      ),

      // ─── Tenant Admin Shell (Layer 2) ───────────────────────────────
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

      // ─── SaaS Owner Shell (Layer 1) ─────────────────────────────────
      ShellRoute(
        navigatorKey: _saasShellKey,
        builder: (context, state, child) {
          return SaasShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/saas',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SaasOverviewScreen(),
            ),
          ),
          GoRoute(
            path: '/saas/tenants',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TenantsScreen(),
            ),
          ),
          GoRoute(
            path: '/saas/tenants/:id',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return NoTransitionPage(
                child: TenantDetailScreen(tenantId: id),
              );
            },
          ),
          GoRoute(
            path: '/saas/plans',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: PlansScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}
