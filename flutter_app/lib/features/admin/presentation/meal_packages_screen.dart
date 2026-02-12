import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

/// Screen for managing tenant-defined meal packages / subscription tiers.
/// Tenants create their own package names, prices, diet types, and durations.
class MealPackagesScreen extends StatefulWidget {
  const MealPackagesScreen({super.key});

  @override
  State<MealPackagesScreen> createState() => _MealPackagesScreenState();
}

class _MealPackagesScreenState extends State<MealPackagesScreen> {
  final AdminRepository _repo = AdminRepository();

  bool _loading = true;
  String? _error;
  List<MealPackage> _packages = [];

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
      final packages = await _repo.getMealPackages();
      if (mounted) {
        setState(() {
          _packages = packages;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _showAddEditDialog([MealPackage? existing]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _MealPackageFormDialog(
        repo: _repo,
        existing: existing,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _deletePackage(MealPackage pkg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Package?'),
        content: Text('Delete "${pkg.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _repo.deleteMealPackage(pkg.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Package deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
              Text(
                'Meal Packages',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!_loading)
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Package'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Define your subscription tiers and pricing for customers.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.card_giftcard, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No packages yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first subscription package',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _packages.length,
      itemBuilder: (context, i) => _buildPackageCard(_packages[i]),
    );
  }

  Widget _buildPackageCard(MealPackage pkg) {
    final isVeg = pkg.dietType == 'veg';
    final isBoth = pkg.dietType == 'both';
    final dietColor = isVeg
        ? Colors.green
        : isBoth
            ? Colors.blue
            : Colors.red.shade700;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showAddEditDialog(pkg),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pkg.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!pkg.isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'INACTIVE',
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _showAddEditDialog(pkg);
                      if (v == 'delete') _deletePackage(pkg);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child:
                            Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, size: 18),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Price
              Text(
                '${pkg.currency.isNotEmpty ? pkg.currency : ''} ${pkg.price.toStringAsFixed(2)}'.trim(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                '/ ${pkg.durationDisplay.toLowerCase()} (${pkg.durationDays} days)',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
              // Diet type chip
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip(pkg.dietTypeDisplay, dietColor),
                  _chip('${pkg.mealsPerDay} meals/day', Colors.blue.shade700),
                  if (pkg.portionLabel.isNotEmpty)
                    _chip(pkg.portionLabel, Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Form Dialog ────────────────────────────────────────────────────────────

class _MealPackageFormDialog extends StatefulWidget {
  final AdminRepository repo;
  final MealPackage? existing;

  const _MealPackageFormDialog({required this.repo, this.existing});

  @override
  State<_MealPackageFormDialog> createState() => _MealPackageFormDialogState();
}

class _MealPackageFormDialogState extends State<_MealPackageFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _durationDaysCtrl = TextEditingController();
  final _mealsPerDayCtrl = TextEditingController();
  final _portionLabelCtrl = TextEditingController();
  final _sortOrderCtrl = TextEditingController();

  String _dietType = 'both';
  String _duration = 'monthly';
  bool _isActive = true;
  bool _saving = false;
  String? _error;

  List<MenuPlan> _menus = [];
  final Set<int> _selectedMenuIds = {};
  bool _loadingMenus = true;

  @override
  void initState() {
    super.initState();
    _loadMenus();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _descCtrl.text = e.description;
      _priceCtrl.text = e.price.toStringAsFixed(2);
      _currencyCtrl.text = e.currency;
      _durationDaysCtrl.text = e.durationDays.toString();
      _mealsPerDayCtrl.text = e.mealsPerDay.toString();
      _portionLabelCtrl.text = e.portionLabel;
      _sortOrderCtrl.text = e.sortOrder.toString();
      _dietType = e.dietType;
      _duration = e.duration;
      _isActive = e.isActive;
      _selectedMenuIds.addAll(e.menus.map((m) => m.id));
    } else {
      _durationDaysCtrl.text = '30';
      _mealsPerDayCtrl.text = '2';
      _sortOrderCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _currencyCtrl.dispose();
    _durationDaysCtrl.dispose();
    _mealsPerDayCtrl.dispose();
    _portionLabelCtrl.dispose();
    _sortOrderCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMenus() async {
    try {
      final menus = await widget.repo.getMenus();
      if (mounted) {
        setState(() {
          _menus = menus;
          _loadingMenus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMenus = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'price': _priceCtrl.text.trim(),
      'currency': _currencyCtrl.text.trim(),
      'diet_type': _dietType,
      'duration': _duration,
      'duration_days': int.tryParse(_durationDaysCtrl.text) ?? 30,
      'meals_per_day': int.tryParse(_mealsPerDayCtrl.text) ?? 2,
      'portion_label': _portionLabelCtrl.text.trim(),
      'sort_order': int.tryParse(_sortOrderCtrl.text) ?? 0,
      'is_active': _isActive,
    };
    if (_selectedMenuIds.isNotEmpty) {
      data['menu_ids'] = _selectedMenuIds.toList();
    }

    try {
      if (widget.existing != null) {
        await widget.repo.updateMealPackage(widget.existing!.id, data);
      } else {
        await widget.repo.createMealPackage(data);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Package' : 'Create Package',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!,
                        style: TextStyle(color: Colors.red[700])),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Package Name *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _priceCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Price *',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Required';
                                  if (double.tryParse(v.trim()) == null) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _currencyCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Currency',
                                  hintText: 'e.g. AED',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _dietType,
                                decoration: const InputDecoration(
                                  labelText: 'Diet Type',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'veg', child: Text('Vegetarian')),
                                  DropdownMenuItem(
                                      value: 'nonveg',
                                      child: Text('Non-Vegetarian')),
                                  DropdownMenuItem(
                                      value: 'both', child: Text('Both')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _dietType = v ?? 'both'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _duration,
                                decoration: const InputDecoration(
                                  labelText: 'Duration',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'weekly', child: Text('Weekly')),
                                  DropdownMenuItem(
                                      value: 'monthly', child: Text('Monthly')),
                                  DropdownMenuItem(
                                      value: 'custom', child: Text('Custom')),
                                ],
                                onChanged: (v) =>
                                    setState(() => _duration = v ?? 'monthly'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _durationDaysCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Duration (days)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _mealsPerDayCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Meals / Day',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _portionLabelCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Portion Label',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _sortOrderCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Sort Order',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Menus (optional)',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700])),
                        const SizedBox(height: 6),
                        _loadingMenus
                            ? const LinearProgressIndicator()
                            : Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: _menus.map((m) {
                                  final sel = _selectedMenuIds.contains(m.id);
                                  return FilterChip(
                                    label: Text('${m.name} (${m.price.toStringAsFixed(0)})'),
                                    selected: sel,
                                    onSelected: (v) {
                                      setState(() {
                                        if (v) {
                                          _selectedMenuIds.add(m.id);
                                        } else {
                                          _selectedMenuIds.remove(m.id);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Active'),
                          subtitle: const Text(
                              'Inactive packages are hidden from customers'),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEdit ? 'Update' : 'Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
