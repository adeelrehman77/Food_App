import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';
import '../../menu/data/menu_repository.dart';
import '../../menu/domain/food_item.dart';

/// Dialog for creating / editing a daily menu for a specific date + meal slot + diet type.
/// Users pick items from the master library, set optional price overrides
/// and portion labels, then save as draft or publish.
class DailyMenuEditorDialog extends StatefulWidget {
  final DateTime date;
  final MealSlot mealSlot;
  final String dietType; // 'veg' or 'nonveg'
  final DailyMenu? existingMenu;
  final AdminRepository repo;

  const DailyMenuEditorDialog({
    super.key,
    required this.date,
    required this.mealSlot,
    required this.dietType,
    this.existingMenu,
    required this.repo,
  });

  @override
  State<DailyMenuEditorDialog> createState() => _DailyMenuEditorDialogState();
}

class _DailyMenuEditorDialogState extends State<DailyMenuEditorDialog> {
  final MenuRepository _menuRepo = MenuRepository();
  final _notesCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  bool _loadingMaster = true;
  bool _saving = false;
  String? _error;

  List<FoodItem> _masterItems = [];
  List<FoodItem> _filteredMaster = [];
  final List<_EditorItem> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _notesCtrl.text = widget.existingMenu?.notes ?? '';
    _loadMasterItems();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasterItems() async {
    try {
      final items = await _menuRepo.getFoodItems();
      if (mounted) {
        setState(() {
          _masterItems = items;
          _filteredMaster = _filterByDiet(items);
          _loadingMaster = false;

          // Pre-fill selected items from existing menu
          if (widget.existingMenu != null) {
            for (final di in widget.existingMenu!.items) {
              _selectedItems.add(_EditorItem(
                masterItemId: di.masterItemId,
                masterItemName: di.masterItemName,
                masterItemPrice: di.masterItemPrice,
                overridePrice: di.overridePrice,
                portionLabel: di.portionLabel,
              ));
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingMaster = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  /// Filter master items by search text AND diet type.
  /// Items with diet_type 'both' are shown on either track.
  List<FoodItem> _filterByDiet(List<FoodItem> items) {
    return items.where((i) {
      return i.dietType == widget.dietType || i.dietType == 'both';
    }).toList();
  }

  void _filterMaster(String query) {
    setState(() {
      var items = _filterByDiet(_masterItems);
      if (query.isNotEmpty) {
        final q = query.toLowerCase();
        items = items
            .where((i) =>
                i.name.toLowerCase().contains(q) ||
                (i.categoryName ?? '').toLowerCase().contains(q))
            .toList();
      }
      _filteredMaster = items;
    });
  }

  void _addItem(FoodItem item) {
    setState(() {
      _selectedItems.add(_EditorItem(
        masterItemId: int.parse(item.id),
        masterItemName: item.name,
        masterItemPrice: item.basePrice,
      ));
    });
  }

  void _removeItem(int index) {
    setState(() => _selectedItems.removeAt(index));
  }

  void _moveUp(int index) {
    if (index == 0) return;
    setState(() {
      final item = _selectedItems.removeAt(index);
      _selectedItems.insert(index - 1, item);
    });
  }

  void _moveDown(int index) {
    if (index >= _selectedItems.length - 1) return;
    setState(() {
      final item = _selectedItems.removeAt(index);
      _selectedItems.insert(index + 1, item);
    });
  }

  Future<void> _save({bool publish = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final items = _selectedItems.asMap().entries.map((entry) {
      final i = entry.key;
      final item = entry.value;
      return <String, dynamic>{
        'master_item': item.masterItemId,
        if (item.overridePrice != null) 'override_price': item.overridePrice.toString(),
        'portion_label': item.portionLabel,
        'sort_order': i,
      };
    }).toList();

    final data = <String, dynamic>{
      'menu_date': DateFormat('yyyy-MM-dd').format(widget.date),
      'meal_slot': widget.mealSlot.id,
      'diet_type': widget.dietType,
      'notes': _notesCtrl.text,
      'items': items,
    };

    try {
      DailyMenu result;
      if (widget.existingMenu != null) {
        result = await widget.repo.updateDailyMenu(widget.existingMenu!.id, data);
      } else {
        result = await widget.repo.createDailyMenu(data);
      }

      if (publish && result.status == 'draft') {
        await widget.repo.publishDailyMenu(result.id);
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

  Future<void> _delete() async {
    if (widget.existingMenu == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Daily Menu?'),
        content: const Text('This will permanently remove this daily menu and all its items.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await widget.repo.deleteDailyMenu(widget.existingMenu!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEEE, MMM d, yyyy');
    final title = widget.existingMenu != null ? 'Edit Daily Menu' : 'Create Daily Menu';
    final isClosed = widget.existingMenu?.status == 'closed';

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          '${dateFmt.format(widget.date)} — ${widget.mealSlot.name} — ${widget.dietType == 'veg' ? 'Vegetarian' : 'Non-Vegetarian'}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        if (widget.existingMenu != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _statusBadge(widget.existingMenu!.status),
                          ),
                      ],
                    ),
                  ),
                  if (widget.existingMenu != null && !isClosed)
                    IconButton(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Delete menu',
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Colors.red[700])),
                ),

              // ── Body (two-column layout) ──
              Expanded(
                child: isClosed
                    ? _buildReadOnlyView()
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: master item picker
                          Expanded(flex: 2, child: _buildMasterPicker()),
                          const SizedBox(width: 16),
                          // Right: selected items
                          Expanded(flex: 3, child: _buildSelectedItems()),
                        ],
                      ),
              ),

              // ── Notes ──
              if (!isClosed) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (internal)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  maxLines: 2,
                ),
              ],

              // ── Actions ──
              const SizedBox(height: 16),
              if (!isClosed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _saving ? null : () => _save(publish: false),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Draft'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving || _selectedItems.isEmpty
                          ? null
                          : () => _save(publish: true),
                      child: const Text('Save & Publish'),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Close'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'published' => Colors.green,
      'closed' => Colors.grey,
      _ => Colors.orange,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ── Master Item Picker (left column) ──

  Widget _buildMasterPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Master Items',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _searchCtrl,
          onChanged: _filterMaster,
          decoration: const InputDecoration(
            hintText: 'Search items...',
            prefixIcon: Icon(Icons.search, size: 20),
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingMaster
              ? const Center(child: CircularProgressIndicator())
              : _filteredMaster.isEmpty
                  ? Center(
                      child: Text(
                        'No items found',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredMaster.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = _filteredMaster[i];
                        final alreadyAdded = _selectedItems
                            .any((s) => s.masterItemId == int.parse(item.id));
                        return ListTile(
                          dense: true,
                          title: Text(
                            item.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${item.categoryName ?? ''} • AED ${item.basePrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: alreadyAdded
                              ? const Icon(Icons.check, color: Colors.green, size: 18)
                              : IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: () => _addItem(item),
                                  tooltip: 'Add to menu',
                                ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Selected Items (right column) ──

  Widget _buildSelectedItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Menu Items (${_selectedItems.length})',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _selectedItems.isEmpty
              ? Center(
                  child: Text(
                    'Add items from the left panel',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: _selectedItems.length,
                  onReorder: (oldIdx, newIdx) {
                    setState(() {
                      if (newIdx > oldIdx) newIdx--;
                      final item = _selectedItems.removeAt(oldIdx);
                      _selectedItems.insert(newIdx, item);
                    });
                  },
                  itemBuilder: (context, idx) {
                    final item = _selectedItems[idx];
                    return _buildSelectedItemTile(item, idx);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSelectedItemTile(_EditorItem item, int idx) {
    return Card(
      key: ValueKey('${item.masterItemId}_$idx'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: idx,
              child: const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.masterItemName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(
                    'Base: AED ${item.masterItemPrice.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            // Portion label
            SizedBox(
              width: 100,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Portion',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                style: const TextStyle(fontSize: 12),
                controller: TextEditingController(text: item.portionLabel),
                onChanged: (v) => item.portionLabel = v,
              ),
            ),
            const SizedBox(width: 8),
            // Override price
            SizedBox(
              width: 80,
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Price',
                  isDense: true,
                  border: OutlineInputBorder(),
                  prefixText: 'AED ',
                  prefixStyle: TextStyle(fontSize: 11),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                style: const TextStyle(fontSize: 12),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                controller: TextEditingController(
                  text: item.overridePrice?.toStringAsFixed(2) ?? '',
                ),
                onChanged: (v) {
                  item.overridePrice = double.tryParse(v);
                },
              ),
            ),
            const SizedBox(width: 4),
            // Reorder + delete
            Column(
              children: [
                InkWell(
                  onTap: () => _moveUp(idx),
                  child: Icon(Icons.arrow_upward,
                      size: 16, color: idx > 0 ? Colors.grey[700] : Colors.grey[300]),
                ),
                InkWell(
                  onTap: () => _moveDown(idx),
                  child: Icon(Icons.arrow_downward,
                      size: 16,
                      color: idx < _selectedItems.length - 1
                          ? Colors.grey[700]
                          : Colors.grey[300]),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: Colors.red, size: 18),
              onPressed: () => _removeItem(idx),
              tooltip: 'Remove',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Read-only view for closed menus ──

  Widget _buildReadOnlyView() {
    final items = widget.existingMenu?.items ?? [];
    if (items.isEmpty) {
      return const Center(child: Text('No items in this menu.'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[200],
            child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
          ),
          title: Text(item.masterItemName),
          subtitle: Text(
            [
              if (item.portionLabel.isNotEmpty) item.portionLabel,
              'AED ${item.effectivePrice.toStringAsFixed(2)}',
            ].join(' • '),
          ),
        );
      },
    );
  }
}

// ── Internal mutable editor item ──

class _EditorItem {
  final int masterItemId;
  final String masterItemName;
  final double masterItemPrice;
  double? overridePrice;
  String portionLabel;

  _EditorItem({
    required this.masterItemId,
    required this.masterItemName,
    required this.masterItemPrice,
    this.overridePrice,
    this.portionLabel = '',
  });
}
