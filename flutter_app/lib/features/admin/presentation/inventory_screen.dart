import 'package:flutter/material.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _repo = AdminRepository();
  List<InventoryItemModel> _items = [];
  bool _loading = true;
  String? _error;
  bool _showLowStockOnly = false;

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
      final items = _showLowStockOnly
          ? await _repo.getLowStockItems()
          : await _repo.getInventoryItems();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAdjustStockDialog(InventoryItemModel item) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust Stock — ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current stock: ${item.currentStock} ${item.unitAbbreviation ?? ''}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Quantity (+/-)',
                helperText: 'Positive to add, negative to subtract',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final qty = double.tryParse(controller.text);
              if (qty == null) return;
              Navigator.pop(ctx);
              try {
                await _repo.adjustStock(item.id, qty);
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock adjusted for ${item.name}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog({InventoryItemModel? item}) {
    final nameCtrl = TextEditingController(text: item?.name ?? '');
    final descCtrl = TextEditingController(text: item?.description ?? '');
    final stockCtrl = TextEditingController(
      text: item != null ? item.currentStock.toString() : '0',
    );
    final minStockCtrl = TextEditingController(
      text: item != null ? item.minStockLevel.toString() : '0',
    );
    final costCtrl = TextEditingController(
      text: item != null ? item.costPerUnit.toString() : '0',
    );
    final supplierCtrl = TextEditingController(text: item?.supplier ?? '');
    final formKey = GlobalKey<FormState>();
    String? dialogError;

    // Unit selection state
    List<UnitOfMeasure> units = [];
    int? selectedUnitId = item?.unitId;
    bool loadingUnits = true;
    bool unitsFetchStarted = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Load units once on first build
          if (!unitsFetchStarted) {
            unitsFetchStarted = true;
            _repo.getUnits().then((fetched) {
              setDialogState(() {
                units = fetched;
                loadingUnits = false;
                if (selectedUnitId == null && units.isNotEmpty) {
                  selectedUnitId = units.first.id;
                }
              });
            }).catchError((_) {
              setDialogState(() => loadingUnits = false);
            });
          }

          return AlertDialog(
            title: Text(item == null ? 'Add Inventory Item' : 'Edit ${item.name}'),
            content: SizedBox(
              width: 480,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dialogError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dialogError!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. Rice, Chicken, Cooking Oil',
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),

                      // ── Unit dropdown ──
                      if (loadingUnits)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(),
                        )
                      else if (units.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Text(
                            'No units of measure found. Create them first '
                            'via the admin panel (e.g. kg, litre, piece).',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<int>(
                          initialValue: selectedUnitId,
                          decoration: const InputDecoration(
                            labelText: 'Unit *',
                            border: OutlineInputBorder(),
                          ),
                          items: units.map((u) {
                            return DropdownMenuItem(
                              value: u.id,
                              child: Text('${u.name} (${u.abbreviation})'),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedUnitId = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: stockCtrl,
                              decoration: InputDecoration(
                                labelText: 'Current Stock *',
                                border: const OutlineInputBorder(),
                                suffixText: _unitAbbr(units, selectedUnitId),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (double.tryParse(v) == null) {
                                  return 'Enter a number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: minStockCtrl,
                              decoration: InputDecoration(
                                labelText: 'Min Stock Level',
                                border: const OutlineInputBorder(),
                                suffixText: _unitAbbr(units, selectedUnitId),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (v) {
                                if (v != null &&
                                    v.isNotEmpty &&
                                    double.tryParse(v) == null) {
                                  return 'Enter a number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: costCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cost per Unit (AED)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              validator: (v) {
                                if (v != null &&
                                    v.isNotEmpty &&
                                    double.tryParse(v) == null) {
                                  return 'Enter a number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: supplierCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Supplier',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final data = <String, dynamic>{
                    'name': nameCtrl.text,
                    'description': descCtrl.text,
                    'current_stock': stockCtrl.text,
                    'min_stock_level':
                        minStockCtrl.text.isEmpty ? '0' : minStockCtrl.text,
                    'cost_per_unit':
                        costCtrl.text.isEmpty ? '0' : costCtrl.text,
                    'supplier': supplierCtrl.text,
                    if (selectedUnitId != null) // ignore: use_null_aware_elements
                      'unit': selectedUnitId,
                  };
                  try {
                    if (item == null) {
                      await _repo.createInventoryItem(data);
                    } else {
                      await _repo.updateInventoryItem(item.id, data);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } catch (e) {
                    setDialogState(() {
                      dialogError =
                          e.toString().replaceFirst('Exception: ', '');
                    });
                  }
                },
                child: Text(item == null ? 'Add' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _unitAbbr(List<UnitOfMeasure> units, int? id) {
    if (id == null || units.isEmpty) return '';
    try {
      return units.firstWhere((u) => u.id == id).abbreviation;
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage ingredients and stock levels',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              FilterChip(
                label: const Text('Low Stock Only'),
                selected: _showLowStockOnly,
                onSelected: (v) {
                  setState(() => _showLowStockOnly = v);
                  _load();
                },
                selectedColor: Colors.red.shade100,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _showAddEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: TextStyle(color: Colors.red[700])),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inventory_2, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                _showLowStockOnly
                                    ? 'No low-stock items'
                                    : 'No inventory items',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return _InventoryCard(
                                item: item,
                                onEdit: () => _showAddEditDialog(item: item),
                                onAdjust: () => _showAdjustStockDialog(item),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}

class _InventoryCard extends StatelessWidget {
  final InventoryItemModel item;
  final VoidCallback onEdit;
  final VoidCallback onAdjust;

  const _InventoryCard({
    required this.item,
    required this.onEdit,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.isLowStock
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.isLowStock
                    ? Icons.warning_amber_rounded
                    : Icons.inventory_2_rounded,
                color: item.isLowStock ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock: ${item.currentStock} ${item.unitAbbreviation ?? ''}'
                    ' · Min: ${item.minStockLevel}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  if (item.supplier != null && item.supplier!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Supplier: ${item.supplier}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'AED ${item.costPerUnit.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                if (item.isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'LOW STOCK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'adjust') onAdjust();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'adjust', child: Text('Adjust Stock')),
                const PopupMenuItem(value: 'edit', child: Text('Edit Item')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
