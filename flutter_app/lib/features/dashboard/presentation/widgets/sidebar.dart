import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.restaurant_menu, color: Theme.of(context).primaryColor, size: 30),
                const SizedBox(width: 10),
                Text(
                  'Fun Adventure',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Navigation Items
          Expanded(
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final isDriver = auth.isDriver;
                
                final items = [
                  if (!isDriver)
                    _SidebarItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      route: '/dashboard',
                      isSelected: currentRoute == '/dashboard',
                    ),
                  if (!isDriver)
                    _SidebarItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Orders',
                      route: '/orders',
                      isSelected: currentRoute == '/orders',
                    ),
                  if (!isDriver)
                    _SidebarItem(
                      icon: Icons.card_membership_rounded,
                      label: 'Subscriptions',
                      route: '/subscriptions',
                      isSelected: currentRoute == '/subscriptions',
                    ),
                  if (!isDriver)
                    _SidebarItem(
                      icon: Icons.menu_book_rounded,
                      label: 'Menu',
                      route: '/menu',
                      isSelected: currentRoute == '/menu',
                    ),
                  if (!isDriver)
                    _SidebarItem(
                      icon: Icons.inventory_2_rounded,
                      label: 'Inventory',
                      route: '/inventory',
                      isSelected: currentRoute == '/inventory',
                    ),
                  _SidebarItem(
                    icon: Icons.local_shipping_rounded,
                    label: 'Delivery',
                    route: '/delivery',
                    isSelected: currentRoute == '/delivery',
                  ),
                  if (!isDriver)
                    _SidebarItem(
                      icon: Icons.people_rounded,
                      label: 'Customers',
                      route: '/customers',
                      isSelected: currentRoute == '/customers',
                    ),
                  if (!isDriver)
                    _SidebarItem(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Finance',
                      route: '/finance',
                      isSelected: currentRoute == '/finance',
                    ),
                  if (!isDriver)
                    _SidebarItem(
                      icon: Icons.badge_rounded,
                      label: 'Staff',
                      route: '/staff',
                      isSelected: currentRoute == '/staff',
                    ),
                ];

                return ListView(
                  padding: EdgeInsets.zero,
                  children: items,
                );
              },
            ),
          ),
          // Platform Admin link (visible to all for now — backend enforces superuser)
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              if (auth.isDriver) return const SizedBox.shrink();
              return Column(
                children: [
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.admin_panel_settings_rounded,
                        color: Theme.of(context).primaryColor, size: 22),
                    title: Text(
                      'Platform Admin',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    dense: true,
                    onTap: () => context.go('/saas'),
                  ),
                ],
              );
            },
          ),
          // Logout button at the bottom
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isSelected;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        onTap: () {
          context.go(route);
          // Close drawer on mobile if open
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold != null && scaffold.isDrawerOpen) {
            Navigator.of(context).pop();
          }
        },
        selected: isSelected,
        selectedTileColor: Theme.of(context).primaryColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        dense: true,
      ),
    );
  }
}
