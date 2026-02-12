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
            childAspectRatio: 0.85,
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

  void _showPlanDialog(BuildContext context, {ServicePlan? plan}) {
    final isEdit = plan != null;
    final nameCtrl = TextEditingController(text: plan?.name ?? '');
    final descCtrl = TextEditingController(text: plan?.description ?? '');
    final monthlyCtrl = TextEditingController(
        text: plan != null ? plan.priceMonthly.toStringAsFixed(2) : '');
    final yearlyCtrl = TextEditingController(
        text: plan != null ? plan.priceYearly.toStringAsFixed(2) : '');
    String tier = plan?.tier ?? 'basic';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Plan' : 'Create Plan'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Plan Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tier,
                    decoration: const InputDecoration(labelText: 'Tier'),
                    items: const [
                      DropdownMenuItem(value: 'free', child: Text('Free / Trial')),
                      DropdownMenuItem(value: 'basic', child: Text('Basic')),
                      DropdownMenuItem(value: 'pro', child: Text('Professional')),
                      DropdownMenuItem(
                          value: 'enterprise', child: Text('Enterprise')),
                    ],
                    onChanged: (v) => setDialogState(() => tier = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: monthlyCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Monthly Price (AED)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: yearlyCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Yearly Price (AED)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final data = {
                  'name': nameCtrl.text,
                  'tier': tier,
                  'description': descCtrl.text,
                  'price_monthly': monthlyCtrl.text,
                  'price_yearly': yearlyCtrl.text,
                };
                Navigator.pop(context);
                try {
                  if (isEdit) {
                    await _repo.updatePlan(plan.id, data);
                  } else {
                    await _repo.createPlan(data);
                  }
                  _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
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
          color: plan.isActive ? _tierColor.withOpacity(0.3) : Colors.grey.shade200,
          width: plan.isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                  color: _tierColor.withOpacity(0.1),
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
          _LimitRow(Icons.menu_book, '${plan.maxMenuItems} menu items'),
          _LimitRow(Icons.people, '${plan.maxStaffUsers} staff users'),
          _LimitRow(Icons.person, '${plan.maxCustomers} customers'),
          _LimitRow(Icons.receipt, '${plan.maxOrdersPerMonth} orders/mo'),
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
