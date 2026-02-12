import 'package:flutter/material.dart';
import '../data/saas_repository.dart';
import '../domain/models.dart';

/// Service plan management — CRUD for pricing tiers.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _repo = SaasRepository();
  List<ServicePlan> _plans = [];
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
      final plans = await _repo.getPlans();
      setState(() {
        _plans = plans;
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
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Service Plans',
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Configure pricing tiers and feature limits',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showPlanDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Plan'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3F51B5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                                onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _plans.isEmpty
                        ? const Center(
                            child: Text('No plans configured.',
                                style: TextStyle(color: Colors.grey)))
                        : _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 1000
            ? 3
            : constraints.maxWidth > 600
                ? 2
                : 1;
        return GridView.builder(
          itemCount: _plans.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemBuilder: (_, i) => _PlanCard(
            plan: _plans[i],
            onEdit: () => _showPlanDialog(context, plan: _plans[i]),
            onToggle: () => _toggleActive(_plans[i]),
          ),
        );
      },
    );
  }

  Future<void> _toggleActive(ServicePlan plan) async {
    try {
      await _repo.updatePlan(plan.id, {'is_active': !plan.isActive});
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Tier-based recommended defaults for quick fill.
  static const _tierDefaults = {
    'free': {
      'max_menu_items': 30,
      'max_staff_users': 3,
      'max_customers': 200,
      'max_orders_per_month': 5000,
    },
    'basic': {
      'max_menu_items': 100,
      'max_staff_users': 15,
      'max_customers': 1000,
      'max_orders_per_month': 50000,
    },
    'pro': {
      'max_menu_items': 300,
      'max_staff_users': 50,
      'max_customers': 5000,
      'max_orders_per_month': 150000,
    },
    'enterprise': {
      'max_menu_items': 0,
      'max_staff_users': 0,
      'max_customers': 0,
      'max_orders_per_month': 0,
    },
  };

  void _showPlanDialog(BuildContext context, {ServicePlan? plan}) {
    final isEdit = plan != null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: plan?.name ?? '');
    final descCtrl = TextEditingController(text: plan?.description ?? '');
    final monthlyCtrl = TextEditingController(
        text: plan != null ? plan.priceMonthly.toStringAsFixed(2) : '0.00');
    final yearlyCtrl = TextEditingController(
        text: plan != null ? plan.priceYearly.toStringAsFixed(2) : '0.00');
    final trialDaysCtrl = TextEditingController(
        text: plan != null ? plan.trialDays.toString() : '14');

    // Limit controllers
    final menuItemsCtrl = TextEditingController(
        text: plan != null ? plan.maxMenuItems.toString() : '100');
    final staffCtrl = TextEditingController(
        text: plan != null ? plan.maxStaffUsers.toString() : '15');
    final customersCtrl = TextEditingController(
        text: plan != null ? plan.maxCustomers.toString() : '1000');
    final ordersCtrl = TextEditingController(
        text: plan != null ? plan.maxOrdersPerMonth.toString() : '50000');

    String tier = plan?.tier ?? 'basic';
    String? dialogError;

    // Feature flags
    bool hasInventory = plan?.hasInventoryManagement ?? false;
    bool hasDeliveryTracking = plan?.hasDeliveryTracking ?? false;
    bool hasCustomerApp = plan?.hasCustomerApp ?? false;
    bool hasAnalytics = plan?.hasAnalytics ?? false;
    bool hasWhatsapp = plan?.hasWhatsappNotifications ?? false;
    bool hasMultiBranch = plan?.hasMultiBranch ?? false;

    void applyTierDefaults(String t, StateSetter setState) {
      final defaults = _tierDefaults[t];
      if (defaults == null) return;
      setState(() {
        menuItemsCtrl.text = defaults['max_menu_items'].toString();
        staffCtrl.text = defaults['max_staff_users'].toString();
        customersCtrl.text = defaults['max_customers'].toString();
        ordersCtrl.text = defaults['max_orders_per_month'].toString();
      });
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Plan' : 'Create Plan'),
          content: SizedBox(
            width: 520,
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

                    // ── Basic Info ──
                    TextFormField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Plan Name *'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Plan name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: tier,
                            decoration:
                                const InputDecoration(labelText: 'Tier'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'free', child: Text('Free / Trial')),
                              DropdownMenuItem(
                                  value: 'basic', child: Text('Basic')),
                              DropdownMenuItem(
                                  value: 'pro', child: Text('Professional')),
                              DropdownMenuItem(
                                  value: 'enterprise',
                                  child: Text('Enterprise')),
                            ],
                            onChanged: (v) {
                              setDialogState(() => tier = v!);
                              if (!isEdit) {
                                applyTierDefaults(v!, setDialogState);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: trialDaysCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Trial Days'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      maxLines: 2,
                    ),

                    // ── Pricing ──
                    const SizedBox(height: 20),
                    Text('Pricing',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: monthlyCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Monthly (AED)'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) {
                              if (v != null &&
                                  v.isNotEmpty &&
                                  double.tryParse(v) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: yearlyCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Yearly (AED)'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (v) {
                              if (v != null &&
                                  v.isNotEmpty &&
                                  double.tryParse(v) == null) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // ── Usage Limits ──
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('Usage Limits',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                        const SizedBox(width: 8),
                        Text('(0 = unlimited)',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: menuItemsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Menu Items',
                              helperText: 'Recipes / dishes',
                              helperMaxLines: 1,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v != null &&
                                    v.isNotEmpty &&
                                    int.tryParse(v) == null
                                ? 'Integer required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: staffCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Staff Users',
                              helperText: 'Kitchen & admin',
                              helperMaxLines: 1,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v != null &&
                                    v.isNotEmpty &&
                                    int.tryParse(v) == null
                                ? 'Integer required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: customersCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Customers',
                              helperText: 'B2C subscribers',
                              helperMaxLines: 1,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v != null &&
                                    v.isNotEmpty &&
                                    int.tryParse(v) == null
                                ? 'Integer required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: ordersCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Deliveries / mo',
                              helperText: 'Meal deliveries per month',
                              helperMaxLines: 1,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) => v != null &&
                                    v.isNotEmpty &&
                                    int.tryParse(v) == null
                                ? 'Integer required'
                                : null,
                          ),
                        ),
                      ],
                    ),

                    // ── Feature Flags ──
                    const SizedBox(height: 20),
                    Text('Features',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        _featureChip('Inventory Mgmt', hasInventory, (v) {
                          setDialogState(() => hasInventory = v);
                        }),
                        _featureChip('Delivery Tracking', hasDeliveryTracking,
                            (v) {
                          setDialogState(() => hasDeliveryTracking = v);
                        }),
                        _featureChip('Customer App', hasCustomerApp, (v) {
                          setDialogState(() => hasCustomerApp = v);
                        }),
                        _featureChip('Analytics', hasAnalytics, (v) {
                          setDialogState(() => hasAnalytics = v);
                        }),
                        _featureChip('WhatsApp Notif.', hasWhatsapp, (v) {
                          setDialogState(() => hasWhatsapp = v);
                        }),
                        _featureChip('Multi-Branch', hasMultiBranch, (v) {
                          setDialogState(() => hasMultiBranch = v);
                        }),
                      ],
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

                // Default empty prices to "0.00"
                final monthly = monthlyCtrl.text.trim().isEmpty
                    ? '0.00'
                    : monthlyCtrl.text.trim();
                final yearly = yearlyCtrl.text.trim().isEmpty
                    ? '0.00'
                    : yearlyCtrl.text.trim();

                final data = {
                  'name': nameCtrl.text.trim(),
                  'tier': tier,
                  'description': descCtrl.text.trim(),
                  'price_monthly': monthly,
                  'price_yearly': yearly,
                  'trial_days':
                      int.tryParse(trialDaysCtrl.text.trim()) ?? 14,
                  'max_menu_items':
                      int.tryParse(menuItemsCtrl.text.trim()) ?? 100,
                  'max_staff_users':
                      int.tryParse(staffCtrl.text.trim()) ?? 15,
                  'max_customers':
                      int.tryParse(customersCtrl.text.trim()) ?? 1000,
                  'max_orders_per_month':
                      int.tryParse(ordersCtrl.text.trim()) ?? 50000,
                  'has_inventory_management': hasInventory,
                  'has_delivery_tracking': hasDeliveryTracking,
                  'has_customer_app': hasCustomerApp,
                  'has_analytics': hasAnalytics,
                  'has_whatsapp_notifications': hasWhatsapp,
                  'has_multi_branch': hasMultiBranch,
                };

                try {
                  if (isEdit) {
                    await _repo.updatePlan(plan.id, data);
                  } else {
                    await _repo.createPlan(data);
                  }
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _load();
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(isEdit
                            ? 'Plan updated successfully'
                            : 'Plan created successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() {
                    dialogError =
                        e.toString().replaceAll('Exception: ', '');
                  });
                }
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureChip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: value,
      onSelected: onChanged,
      selectedColor: const Color(0xFF3F51B5).withAlpha(30),
      checkmarkColor: const Color(0xFF3F51B5),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ServicePlan plan;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  const _PlanCard({
    required this.plan,
    required this.onEdit,
    required this.onToggle,
  });

  List<String> get _activeFeatures {
    final features = <String>[];
    if (plan.hasInventoryManagement) features.add('Inventory');
    if (plan.hasDeliveryTracking) features.add('Delivery');
    if (plan.hasCustomerApp) features.add('Customer App');
    if (plan.hasAnalytics) features.add('Analytics');
    if (plan.hasWhatsappNotifications) features.add('WhatsApp');
    if (plan.hasMultiBranch) features.add('Multi-Branch');
    return features;
  }

  /// Format a plan limit for display: 0 → "Unlimited", else add commas.
  String _fmtLimit(int value, String label) {
    if (value == 0) return 'Unlimited $label';
    // Add thousands separators
    final str = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return '${buf.toString()} $label';
  }

  Color get _tierColor {
    switch (plan.tier) {
      case 'free':
        return Colors.grey;
      case 'basic':
        return const Color(0xFF2196F3);
      case 'pro':
        return const Color(0xFF3F51B5);
      case 'enterprise':
        return const Color(0xFF7B1FA2);
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: plan.isActive ? _tierColor.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: plan.isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _tierColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  plan.tierLabel,
                  style: TextStyle(
                      color: _tierColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
              const Spacer(),
              if (!plan.isActive)
                const Text('Inactive',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: onEdit,
                tooltip: 'Edit plan',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name + Price
          Text(plan.name,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            plan.description.isEmpty ? 'No description' : plan.description,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Pricing
          Row(
            children: [
              Text(
                'AED ${plan.priceMonthly.toStringAsFixed(0)}',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _tierColor),
              ),
              Text('/mo',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),

          // Limits
          const Divider(),
          const SizedBox(height: 8),
          _LimitRow(Icons.menu_book, _fmtLimit(plan.maxMenuItems, 'menu items')),
          _LimitRow(Icons.people, _fmtLimit(plan.maxStaffUsers, 'staff users')),
          _LimitRow(Icons.person, _fmtLimit(plan.maxCustomers, 'customers')),
          _LimitRow(Icons.local_shipping, _fmtLimit(plan.maxOrdersPerMonth, 'deliveries/mo')),
          const SizedBox(height: 8),

          // Feature badges
          if (_activeFeatures.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _activeFeatures
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _tierColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(f,
                            style:
                                TextStyle(fontSize: 10, color: _tierColor)),
                      ))
                  .toList(),
            ),
          const Spacer(),

          // Features + Tenants
          Row(
            children: [
              Text(
                '${plan.tenantCount} tenant${plan.tenantCount == 1 ? '' : 's'}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: onToggle,
                child: Text(
                  plan.isActive ? 'Deactivate' : 'Activate',
                  style: TextStyle(
                    color: plan.isActive ? Colors.red : Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _LimitRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}
