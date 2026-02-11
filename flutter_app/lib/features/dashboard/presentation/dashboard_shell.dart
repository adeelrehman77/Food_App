import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/header.dart';

class DashboardShell extends StatelessWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for content area
      drawer: !isDesktop ? const Drawer(child: Sidebar()) : null,
      body: Row(
        children: [
          if (isDesktop) const Sidebar(),
          Expanded(
            child: Column(
              children: [
                 const Header(),
                 Expanded(
                   child: child,
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
