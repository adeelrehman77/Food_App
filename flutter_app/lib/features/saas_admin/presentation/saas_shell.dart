import 'package:flutter/material.dart';
import 'widgets/saas_sidebar.dart';
import 'widgets/saas_header.dart';

/// Shell layout for the SaaS Owner dashboard.
/// Mirrors the tenant DashboardShell but with a distinct color scheme
/// and SaaS-specific navigation.
class SaasShell extends StatelessWidget {
  final Widget child;

  const SaasShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      drawer: !isDesktop ? const Drawer(child: SaasSidebar()) : null,
      body: Row(
        children: [
          if (isDesktop) const SaasSidebar(),
          Expanded(
            child: Column(
              children: [
                const SaasHeader(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
