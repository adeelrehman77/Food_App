import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';
import '../../menu/data/menu_repository.dart';

/// Screen for managing Menus (bundles of menu items used in MealPackages).
class MenusScreen extends StatefulWidget {
  const MenusScreen({super.key});

  @override
  State<MenusScreen> createState() => _MenusScreenState();
}

class _MenusScreenState extends State<MenusScreen> {
  final AdminRepository _repo = AdminRepository();
  List<MenuPlan> _menus = [];
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
      final menus = await _repo.getMenus();
      if (mounted) setState(() => _menus = menus);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAddEditDialog([MenuPlan? existing]) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _MenuFormDialog(repo: _repo, existing: existing),
    );
    if (result == true && mounted) _load();
  }

  Future<void> _deleteMenu(MenuPlan m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Menu'),
        content: Text('Delete "${m.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteMenu(m.id);
      if (mounted) {
        _load();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu deleted'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Menu Plans',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (!_loading)
                    IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _showAddEditDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Menu'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _menus.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No menus yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create menu plans (bundles of items) to use in Meal Packages.',
                              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _menus.length,
                        itemBuilder: (_, i) {
                          final m = _menus[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepOrange.shade100,
                                child: Icon(Icons.menu_book, color: Colors.deepOrange.shade700),
                              ),
                              title: Text(m.name),
                              subtitle: Text(
                                m.description?.isNotEmpty == true
                                    ? m.description!
                                    : 'AED ${m.price.toStringAsFixed(2)} • ${m.menuItemIds.length} items',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('AED ${m.price.toStringAsFixed(2)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700])),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showAddEditDialog(m),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                    onPressed: () => _deleteMenu(m),
                                  ),
                                ],
                              ),
                              onTap: () => _showAddEditDialog(m),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _MenuFormDialog extends StatefulWidget {
  final AdminRepository repo;
  final MenuPlan? existing;

  const _MenuFormDialog({required this.repo, this.existing});

  @override
  State<_MenuFormDialog> createState() => _MenuFormDialogState();
}

class _MenuFormDialogState extends State<_MenuFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _foodItems = [];
  final Set<int> _selectedItemIds = {};
  bool _loadingItems = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _descCtrl.text = e.description ?? '';
      _priceCtrl.text = e.price.toStringAsFixed(2);
      _selectedItemIds.addAll(e.menuItemIds);
    }
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final repo = MenuRepository();
      final items = await repo.getFoodItems();
      if (mounted) {
        setState(() {
          _foodItems = items.map((i) => {'id': int.tryParse(i.id) ?? 0, 'name': i.name}).toList();
          _loadingItems = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingItems = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = {
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'price': _priceCtrl.text.trim(),
      'is_active': true,
      'menu_item_ids': _selectedItemIds.toList(),
    };
    try {
      if (widget.existing != null) {
        await widget.repo.updateMenu(widget.existing!.id, data);
      } else {
        await widget.repo.createMenu(data);
      }
      if (mounted) Navigator.pop(context, true);
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
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.existing != null ? 'Edit Menu' : 'New Menu',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: Colors.red[700])),
                  ),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder(), isDense: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), isDense: true),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price *', border: OutlineInputBorder(), isDense: true),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) return 'Invalid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text('Items in this menu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                const SizedBox(height: 6),
                _loadingItems
                    ? const LinearProgressIndicator()
                    : Flexible(
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _foodItems.map((fi) {
                              final id = fi['id'] as int;
                              final sel = _selectedItemIds.contains(id);
                              return FilterChip(
                                label: Text(fi['name'] as String),
                                selected: sel,
                                onSelected: (v) {
                                  setState(() {
                                    if (v) {
                                      _selectedItemIds.add(id);
                                    } else {
                                      _selectedItemIds.remove(id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.existing != null ? 'Update' : 'Create'),
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
