import 'package:flutter/material.dart';
import '../../domain/food_item.dart';
import '../../data/menu_repository.dart';

class AddItemModal extends StatefulWidget {
  final FoodItem? existing;
  final Function(FoodItem, bool isEdit) onSave;

  const AddItemModal({
    super.key,
    this.existing,
    required this.onSave,
  });

  @override
  State<AddItemModal> createState() => _AddItemModalState();
}

class _AddItemModalState extends State<AddItemModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _caloriesController = TextEditingController();
  final MenuRepository _repo = MenuRepository();

  String _dietType = 'both';
  int? _selectedCategoryId;
  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;

  final List<String> _availableAllergens = [
    'Gluten',
    'Dairy',
    'Nuts',
    'Soy',
    'Eggs',
  ];
  final List<String> _selectedAllergens = [];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _descriptionController.text = e.description;
      _priceController.text = e.basePrice.toStringAsFixed(2);
      _caloriesController.text = e.calories > 0 ? e.calories.toString() : '';
      _dietType = e.dietType;
      _selectedCategoryId = e.categoryId;
      _selectedAllergens.addAll(e.allergens);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _repo.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _loadingCategories = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _showAddCategoryDialog() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _AddCategoryDialog(),
    );

    if (created != null && mounted) {
      final newId = created['id'] as int;
      // Reload categories and auto-select the newly created one
      setState(() => _loadingCategories = true);
      await _loadCategories();
      if (mounted) {
        setState(() => _selectedCategoryId = newId);
      }
    }
  }

  void _saveItem() {
    if (_formKey.currentState!.validate()) {
      final item = FoodItem(
        id: _isEdit ? widget.existing!.id : '',
        name: _nameController.text,
        description: _descriptionController.text,
        basePrice: double.parse(_priceController.text),
        calories: int.tryParse(_caloriesController.text) ?? 0,
        allergens: _selectedAllergens,
        dietType: _dietType,
        categoryId: _selectedCategoryId,
        isActive: _isEdit ? widget.existing!.isActive : true,
      );
      widget.onSave(item, _isEdit);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Food Item' : 'Add New Food Item',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(
                          labelText: 'Base Price *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) =>
                            value == null || double.tryParse(value) == null
                                ? 'Invalid Price'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category dropdown + add button
                    Expanded(
                      child: _loadingCategories
                          ? const LinearProgressIndicator()
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: _selectedCategoryId,
                                    decoration: const InputDecoration(
                                      labelText: 'Category *',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: _categories.map((cat) {
                                      return DropdownMenuItem<int>(
                                        value: cat['id'] as int,
                                        child: Text(cat['name'] as String),
                                      );
                                    }).toList(),
                                    onChanged: (val) =>
                                        setState(() => _selectedCategoryId = val),
                                    validator: (value) =>
                                        value == null ? 'Select a category' : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: IconButton(
                                    onPressed: _showAddCategoryDialog,
                                    icon: const Icon(Icons.add_circle_outline),
                                    tooltip: 'Create new category',
                                    style: IconButton.styleFrom(
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Diet type dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _dietType,
                        decoration: const InputDecoration(
                          labelText: 'Diet Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'veg', child: Text('Vegetarian')),
                          DropdownMenuItem(
                              value: 'nonveg', child: Text('Non-Vegetarian')),
                          DropdownMenuItem(
                              value: 'both', child: Text('Both / Neutral')),
                        ],
                        onChanged: (val) =>
                            setState(() => _dietType = val ?? 'both'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _caloriesController,
                  decoration: const InputDecoration(
                    labelText: 'Calories (optional)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (int.tryParse(value) == null) return 'Must be a number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text('Allergens',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _availableAllergens.map((allergen) {
                    final isSelected = _selectedAllergens.contains(allergen);
                    return FilterChip(
                      label: Text(allergen),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedAllergens.add(allergen);
                          } else {
                            _selectedAllergens.remove(allergen);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _saveItem,
                      child: Text(_isEdit ? 'Update Item' : 'Save Item'),
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

/// Separate stateful widget for the "New Category" dialog so that
/// TextEditingControllers are properly owned and disposed.
class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _repo = MenuRepository();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cat = await _repo.createCategory(
        name,
        description: _descCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, cat);
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
    return AlertDialog(
      title: const Text('New Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 13)),
            ),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Category Name *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _create,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
