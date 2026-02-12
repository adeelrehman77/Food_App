import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';

/// Sidebar for the SaaS Owner dashboard.
/// Uses an indigo/dark color scheme to visually distinguish from tenant admin.
class SaasSidebar extends StatelessWidget {
  const SaasSidebar({super.key});

  static const _accentColor = Color(0xFF3F51B5); // Indigo

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D2E),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Brand
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fun Adventure',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Platform Admin',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Navigation
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _NavItem(
                  icon: Icons.space_dashboard_rounded,
                  label: 'Overview',
                  route: '/saas',
                  isSelected: currentRoute == '/saas',
                ),
                _NavItem(
                  icon: Icons.store_rounded,
                  label: 'Tenants',
                  route: '/saas/tenants',
                  isSelected: currentRoute.startsWith('/saas/tenants'),
                ),
                _NavItem(
                  icon: Icons.card_membership_rounded,
                  label: 'Plans',
                  route: '/saas/plans',
                  isSelected: currentRoute == '/saas/plans',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                _NavItem(
                  icon: Icons.arrow_back_rounded,
                  label: 'Back to Tenant',
                  route: '/dashboard',
                  isSelected: false,
                ),
              ],
            ),
          ),

          // Logout
          const Divider(color: Colors.white12, height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded,
                color: Colors.redAccent, size: 20),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isSelected;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isSelected
            ? SaasSidebar._accentColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            context.go(route);
            final scaffold = Scaffold.maybeOf(context);
            if (scaffold != null && scaffold.isDrawerOpen) {
              Navigator.of(context).pop();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.white : Colors.white54,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.white54,
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
