import 'package:flutter/material.dart';
import '../data/menu_repository.dart';
import '../domain/food_item.dart';
import 'widgets/food_item_card.dart';
import 'widgets/add_item_modal.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final MenuRepository _repository = MenuRepository();
  List<FoodItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final items = await _repository.getFoodItems();
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _addNewItem(FoodItem item) async {
    await _repository.addFoodItem(item);
    _loadItems(); // Refresh list
    if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item added successfully')));
    }
  }

  Future<void> _toggleItemStatus(FoodItem item, bool isActive) async {
      // Optimistic update
      setState(() {
          final index = _items.indexWhere((element) => element.id == item.id);
          if (index != -1) {
              _items[index] = item.copyWith(isActive: isActive);
          }
      });
      
      await _repository.toggleActiveStatus(item.id, isActive);
  }

  void _showAddItemModal() {
    showDialog(
      context: context,
      builder: (context) => AddItemModal(onSave: _addNewItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Menu Management',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showAddItemModal,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300,
                childAspectRatio: 0.8,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return FoodItemCard(
                  item: item,
                  onToggleActive: (val) => _toggleItemStatus(item, val),
                  onTap: () {
                    // TODO: Show edit modal
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
