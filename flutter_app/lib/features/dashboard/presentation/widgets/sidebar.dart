import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();

    return Container(
      width: 250,
      color: Colors.white,
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
                const Text(
                  'FoodApp',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SidebarItem(
                  icon: Icons.dashboard,
                  label: 'Dashboard',
                  route: '/dashboard',
                  isSelected: currentRoute == '/dashboard',
                ),
                _SidebarItem(
                  icon: Icons.receipt_long,
                  label: 'Orders',
                  route: '/orders',
                  isSelected: currentRoute == '/orders',
                ),
                _SidebarItem(
                  icon: Icons.menu_book,
                  label: 'Menu',
                  route: '/menu',
                  isSelected: currentRoute == '/menu',
                ),
                _SidebarItem(
                  icon: Icons.inventory,
                  label: 'Inventory',
                  route: '/inventory',
                  isSelected: currentRoute == '/inventory',
                ),
                _SidebarItem(
                  icon: Icons.local_shipping,
                  label: 'Delivery',
                  route: '/delivery',
                  isSelected: currentRoute == '/delivery',
                ),
                _SidebarItem(
                  icon: Icons.people,
                  label: 'Customers',
                  route: '/customers',
                  isSelected: currentRoute == '/customers',
                ),
                _SidebarItem(
                  icon: Icons.attach_money,
                  label: 'Finance',
                  route: '/finance',
                  isSelected: currentRoute == '/finance',
                ),
              ],
            ),
          ),
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
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      onTap: () => context.go(route),
      selected: isSelected,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    );
  }
}
