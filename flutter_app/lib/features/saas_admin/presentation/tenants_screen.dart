import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/saas_repository.dart';
import '../domain/models.dart';

/// Lists all tenants with search, status badges, and quick actions.
class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  final _repo = SaasRepository();
  final _searchController = TextEditingController();
  List<Tenant> _tenants = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tenants = await _repo.getTenants(search: search);
      setState(() {
        _tenants = tenants;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tenants',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Manage all kitchen businesses on the platform',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Tenant'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search bar
          SizedBox(
            width: 400,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search tenants...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
                      )
                    : null,
              ),
              onSubmitted: (v) => _load(search: v),
            ),
          ),
          const SizedBox(height: 20),

          // Table
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 8),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _tenants.isEmpty
                        ? const Center(
                            child: Text('No tenants found.',
                                style: TextStyle(color: Colors.grey)))
                        : _buildTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor:
                WidgetStateProperty.all(const Color(0xFFF5F6FA)),
            columnSpacing: 32,
            columns: const [
              DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Subdomain', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Plan', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Subscription', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Created', style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.w600))),
            ],
            rows: _tenants.map((t) {
              return DataRow(cells: [
                DataCell(Text(t.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Text(t.subdomain, style: const TextStyle(color: Colors.grey))),
                DataCell(Text(t.planName)),
                DataCell(_StatusBadge(
                  label: t.isActive ? 'Active' : 'Inactive',
                  color: t.isActive ? Colors.green : Colors.red,
                )),
                DataCell(_StatusBadge(
                  label: t.subscriptionStatus,
                  color: _subStatusColor(t.subscriptionStatus),
                )),
                DataCell(Text(t.createdOn)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 18),
                      tooltip: 'View details',
                      onPressed: () =>
                          context.go('/saas/tenants/${t.id}'),
                    ),
                    if (t.isActive)
                      IconButton(
                        icon: const Icon(Icons.pause_circle_outline,
                            size: 18, color: Colors.orange),
                        tooltip: 'Suspend',
                        onPressed: () => _confirmSuspend(t),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline,
                            size: 18, color: Colors.green),
                        tooltip: 'Activate',
                        onPressed: () => _confirmActivate(t),
                      ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Color _subStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'trial':
        return Colors.orange;
      case 'past due':
        return Colors.red;
      case 'suspended':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Future<void> _confirmSuspend(Tenant t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Suspend Tenant'),
        content: Text('Suspend "${t.name}"? They will lose access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.suspendTenant(t.id);
      _load();
    }
  }

  Future<void> _confirmActivate(Tenant t) async {
    await _repo.activateTenant(t.id);
    _load();
  }

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final subdomainCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create New Tenant'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kitchen Name',
                  hintText: 'e.g. Al Noor Kitchen',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subdomainCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subdomain',
                  hintText: 'e.g. alnoor',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Admin Email',
                  hintText: 'admin@alnoor.com',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || subdomainCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
              Navigator.pop(context);
              try {
                await _repo.createTenant(
                  name: nameCtrl.text,
                  subdomain: subdomainCtrl.text,
                  adminEmail: emailCtrl.text,
                );
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Tenant created successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
