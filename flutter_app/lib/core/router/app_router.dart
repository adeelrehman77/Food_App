import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

// Tenant admin screens
import '../../features/dashboard/presentation/dashboard_shell.dart';
import '../../features/admin/presentation/dashboard_screen.dart';
import '../../features/admin/presentation/orders_screen.dart';
import '../../features/admin/presentation/inventory_screen.dart';
import '../../features/admin/presentation/delivery_screen.dart';
import '../../features/admin/presentation/customers_screen.dart';
import '../../features/admin/presentation/finance_screen.dart';
import '../../features/admin/presentation/staff_screen.dart';
import '../../features/admin/presentation/subscriptions_screen.dart';
import '../../features/menu/presentation/menu_screen.dart';
import '../../features/auth/presentation/tenant_login_screen.dart';
import '../../features/auth/presentation/user_login_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';

// SaaS Owner screens
import '../../features/saas_admin/presentation/saas_login_screen.dart';
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
      final loc = state.matchedLocation;
      final isOnLogin = loc == '/login' ||
          loc == '/user-login' ||
          loc == '/saas-login';

      // Not logged in and trying to access a protected route
      if (!isLoggedIn && !isOnLogin) {
        return '/login';
      }

      // Already logged in but on a login page — redirect to dashboard
      // (don't redirect SaaS login to tenant dashboard)
      if (isLoggedIn && isOnLogin) {
        if (authProvider.isDriver) {
          return '/delivery';
        }
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
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/user-login',
        builder: (context, state) => const UserLoginScreen(),
      ),
      GoRoute(
        path: '/saas-login',
        builder: (context, state) => const SaasLoginScreen(),
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
              child: DashboardScreen(),
            ),
          ),
          GoRoute(
            path: '/orders',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrdersScreen(),
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
              child: InventoryScreen(),
            ),
          ),
          GoRoute(
            path: '/delivery',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DeliveryScreen(),
            ),
          ),
          GoRoute(
            path: '/customers',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CustomersScreen(),
            ),
          ),
          GoRoute(
            path: '/finance',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: FinanceScreen(),
            ),
          ),
          GoRoute(
            path: '/subscriptions',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SubscriptionsScreen(),
            ),
          ),
          GoRoute(
            path: '/staff',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StaffScreen(),
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
