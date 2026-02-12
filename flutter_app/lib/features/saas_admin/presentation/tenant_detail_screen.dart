import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/saas_repository.dart';
import '../domain/models.dart';

/// Detail view for a single tenant — shows subscription, plan info, and usage.
class TenantDetailScreen extends StatefulWidget {
  final int tenantId;
  const TenantDetailScreen({super.key, required this.tenantId});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  final _repo = SaasRepository();
  TenantDetail? _tenant;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _repo.getTenantDetail(widget.tenantId);
      setState(() {
        _tenant = detail;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _confirmSuspend(TenantDetail t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Suspend Tenant'),
        content:
            Text('Suspend "${t.name}"? They will lose access to their dashboard.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _repo.suspendTenant(t.id);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tenant suspended')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _confirmActivate(TenantDetail t) async {
    try {
      await _repo.activateTenant(t.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant activated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditDialog(TenantDetail t) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: t.name);
    int? selectedPlanId = t.servicePlan?.id;
    bool isActive = t.isActive;
    String? dialogError;
    List<ServicePlan> plans = [];
    bool plansLoaded = false;

    // Pre-load plans
    _repo.getPlans().then((result) {
      plans = result;
      plansLoaded = true;
    }).catchError((_) {
      plansLoaded = true;
    });

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          // Trigger rebuild once plans finish loading
          if (!plansLoaded) {
            _repo.getPlans().then((result) {
              if (dialogCtx.mounted) {
                setDialogState(() {
                  plans = result;
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
            title: const Text('Edit Tenant'),
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
                    _load(); // Refresh detail view
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final t = _tenant!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + Title + Actions
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/saas/tenants'),
              ),
              const SizedBox(width: 8),
              Text(t.name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              _Badge(
                label: t.isActive ? 'Active' : 'Inactive',
                color: t.isActive ? Colors.green : Colors.red,
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _showEditDialog(t),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Tenant'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3F51B5),
                  side: const BorderSide(color: Color(0xFF3F51B5)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              if (t.isActive)
                OutlinedButton.icon(
                  onPressed: () => _confirmSuspend(t),
                  icon: const Icon(Icons.pause_circle_outline, size: 18),
                  label: const Text('Suspend'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () => _confirmActivate(t),
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('Activate'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Info cards row
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              final children = [
                _InfoCard(
                  title: 'Tenant Info',
                  icon: Icons.store_rounded,
                  children: [
                    _InfoRow('Subdomain', t.subdomain),
                    _InfoRow('Created', t.createdOn),
                    _InfoRow('Database', 'tenant_${t.subdomain}'),
                  ],
                ),
                _InfoCard(
                  title: 'Subscription',
                  icon: Icons.card_membership_rounded,
                  children: t.subscription != null
                      ? [
                          _InfoRow('Plan', t.subscription!.planName),
                          _InfoRow('Status', t.subscription!.statusLabel),
                          _InfoRow('Billing', t.subscription!.billingCycle),
                          _InfoRow('Period',
                              '${t.subscription!.currentPeriodStart} — ${t.subscription!.currentPeriodEnd}'),
                          _InfoRow('Price',
                              'AED ${t.subscription!.currentPrice.toStringAsFixed(2)}/mo'),
                        ]
                      : [
                          const Text('No subscription assigned',
                              style: TextStyle(color: Colors.grey)),
                        ],
                ),
                _InfoCard(
                  title: 'Plan Limits',
                  icon: Icons.tune_rounded,
                  children: t.servicePlan != null
                      ? [
                          _InfoRow('Tier', t.servicePlan!.tierLabel),
                          _InfoRow('Menu Items', '${t.servicePlan!.maxMenuItems}'),
                          _InfoRow('Staff', '${t.servicePlan!.maxStaffUsers}'),
                          _InfoRow('Customers', '${t.servicePlan!.maxCustomers}'),
                          _InfoRow('Orders/mo', '${t.servicePlan!.maxOrdersPerMonth}'),
                        ]
                      : [
                          const Text('No plan assigned',
                              style: TextStyle(color: Colors.grey)),
                        ],
                ),
              ];

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children
                      .map((c) => Expanded(child: Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: c,
                          )))
                      .toList(),
                );
              }
              return Column(
                children: children
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: c,
                        ))
                    .toList(),
              );
            },
          ),

          // Usage
          if (t.latestUsage != null) ...[
            const SizedBox(height: 24),
            const Text('Latest Usage',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _UsageChip(
                    label: 'Orders', value: t.latestUsage!.orderCount, icon: Icons.receipt),
                _UsageChip(
                    label: 'Customers',
                    value: t.latestUsage!.customerCount,
                    icon: Icons.people),
                _UsageChip(
                    label: 'Staff', value: t.latestUsage!.staffCount, icon: Icons.badge),
                _UsageChip(
                    label: 'Menu Items',
                    value: t.latestUsage!.menuItemCount,
                    icon: Icons.menu_book),
                _UsageChip(
                    label: 'Revenue',
                    value: t.latestUsage!.revenue.toInt(),
                    icon: Icons.attach_money,
                    prefix: 'AED '),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF3F51B5)),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}

class _UsageChip extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final String prefix;
  const _UsageChip({
    required this.label,
    required this.value,
    required this.icon,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3F51B5)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$prefix$value',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
