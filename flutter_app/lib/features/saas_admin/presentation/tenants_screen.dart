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
            color: Colors.black.withValues(alpha: 0.04),
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
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18,
                          color: Color(0xFF3F51B5)),
                      tooltip: 'Edit tenant',
                      onPressed: () => _showEditDialog(context, t),
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
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final subdomainCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String? dialogError;
    int? selectedPlanId;
    List<ServicePlan> plans = [];
    bool plansLoading = true;
    bool showPassword = false;

    // Load plans for the dropdown
    _repo.getPlans().then((result) {
      plans = result.where((p) => p.isActive).toList();
      plansLoading = false;
    }).catchError((_) {
      plansLoading = false;
    });

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          // Trigger a rebuild once plans load
          if (plansLoading) {
            _repo.getPlans().then((result) {
              if (dialogCtx.mounted) {
                setDialogState(() {
                  plans = result.where((p) => p.isActive).toList();
                  plansLoading = false;
                });
              }
            }).catchError((_) {
              if (dialogCtx.mounted) {
                setDialogState(() => plansLoading = false);
              }
            });
          }

          return AlertDialog(
            title: const Text('Create New Tenant'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(dialogError!,
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13)),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Kitchen Info ──
                      Text('Kitchen Details',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kitchen Name *',
                          hintText: 'e.g. Al Noor Kitchen',
                          prefixIcon: Icon(Icons.restaurant, size: 20),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: subdomainCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Subdomain *',
                          hintText: 'e.g. alnoor',
                          prefixIcon: Icon(Icons.link, size: 20),
                          helperText: 'Used for tenant URL and database isolation',
                          helperMaxLines: 1,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Subdomain is required';
                          }
                          if (!RegExp(r'^[a-z0-9_]+$')
                              .hasMatch(v.trim().toLowerCase())) {
                            return 'Only lowercase letters, numbers, and underscores';
                          }
                          return null;
                        },
                      ),

                      // ── Service Plan ──
                      const SizedBox(height: 20),
                      Text('Subscription',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      plansLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            )
                          : DropdownButtonFormField<int?>(
                              initialValue: selectedPlanId,
                              decoration: const InputDecoration(
                                labelText: 'Service Plan',
                                prefixIcon: Icon(Icons.card_membership, size: 20),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('No Plan (assign later)',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                                ...plans.map((p) => DropdownMenuItem<int?>(
                                      value: p.id,
                                      child: Text(
                                          '${p.name} (${p.tierLabel}) — AED ${p.priceMonthly.toStringAsFixed(0)}/mo'),
                                    )),
                              ],
                              onChanged: (v) =>
                                  setDialogState(() => selectedPlanId = v),
                            ),

                      // ── Admin Account ──
                      const SizedBox(height: 20),
                      Text('Tenant Admin Account',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Admin Email *',
                          hintText: 'admin@alnoor.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        obscureText: !showPassword,
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          hintText: 'Leave blank to auto-generate',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            onPressed: () => setDialogState(
                                () => showPassword = !showPassword),
                          ),
                        ),
                        validator: (v) {
                          if (v != null && v.isNotEmpty && v.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await _repo.createTenant(
                      name: nameCtrl.text.trim(),
                      subdomain: subdomainCtrl.text.trim().toLowerCase(),
                      adminEmail: emailCtrl.text.trim(),
                      adminPassword: passwordCtrl.text.isNotEmpty
                          ? passwordCtrl.text
                          : null,
                      planId: selectedPlanId,
                    );
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    _load();
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                            content: Text('Tenant created successfully')),
                      );
                    }
                  } catch (e) {
                    setDialogState(() {
                      dialogError =
                          e.toString().replaceAll('Exception: ', '');
                    });
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, Tenant t) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: t.name);
    int? selectedPlanId;
    bool isActive = t.isActive;
    String? dialogError;
    List<ServicePlan> plans = [];
    bool plansLoaded = false;

    // Pre-load plans + tenant detail to get current plan ID
    Future.wait([
      _repo.getPlans(),
      _repo.getTenantDetail(t.id),
    ]).then((results) {
      plans = results[0] as List<ServicePlan>;
      final detail = results[1] as TenantDetail;
      selectedPlanId = detail.servicePlan?.id;
      plansLoaded = true;
    }).catchError((_) {
      plansLoaded = true;
    });

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          if (!plansLoaded) {
            Future.wait([
              _repo.getPlans(),
              _repo.getTenantDetail(t.id),
            ]).then((results) {
              if (dialogCtx.mounted) {
                setDialogState(() {
                  plans = results[0] as List<ServicePlan>;
                  final detail = results[1] as TenantDetail;
                  selectedPlanId = detail.servicePlan?.id;
                  plansLoaded = true;
                });
              }
            }).catchError((_) {
              if (dialogCtx.mounted) {
                setDialogState(() => plansLoaded = true);
              }
            });
          }

          return AlertDialog(
            title: Text('Edit: ${t.name}'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(dialogError!,
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13)),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Kitchen name
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kitchen Name *',
                          prefixIcon: Icon(Icons.restaurant, size: 20),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Subdomain (read-only)
                      TextFormField(
                        initialValue: t.subdomain,
                        decoration: const InputDecoration(
                          labelText: 'Subdomain',
                          prefixIcon: Icon(Icons.link, size: 20),
                          helperText: 'Cannot be changed after creation',
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 20),

                      // Service Plan
                      Text('Subscription',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 8),
                      !plansLoaded
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            )
                          : DropdownButtonFormField<int?>(
                              initialValue: selectedPlanId,
                              decoration: const InputDecoration(
                                labelText: 'Service Plan',
                                prefixIcon:
                                    Icon(Icons.card_membership, size: 20),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('No Plan',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                                ...plans.map((p) => DropdownMenuItem<int?>(
                                      value: p.id,
                                      child: Text(
                                          '${p.name} (${p.tierLabel}) — AED ${p.priceMonthly.toStringAsFixed(0)}/mo'),
                                    )),
                              ],
                              onChanged: (v) =>
                                  setDialogState(() => selectedPlanId = v),
                            ),
                      const SizedBox(height: 20),

                      // Active toggle
                      Text('Status',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (v) =>
                            setDialogState(() => isActive = v),
                        title: Text(isActive ? 'Active' : 'Inactive'),
                        subtitle: Text(
                          isActive
                              ? 'Tenant can access their dashboard'
                              : 'Tenant access is suspended',
                          style: const TextStyle(fontSize: 12),
                        ),
                        activeThumbColor: Colors.green,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final data = <String, dynamic>{
                    'name': nameCtrl.text.trim(),
                    'is_active': isActive,
                  };
                  if (selectedPlanId != null) {
                    data['plan_id'] = selectedPlanId;
                  }

                  try {
                    await _repo.updateTenant(t.id, data);
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    _load(); // Refresh the list
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                            content: Text('Tenant updated successfully')),
                      );
                    }
                  } catch (e) {
                    setDialogState(() {
                      dialogError =
                          e.toString().replaceAll('Exception: ', '');
                    });
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
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
        color: color.withValues(alpha: 0.1),
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
