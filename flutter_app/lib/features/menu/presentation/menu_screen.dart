import 'package:flutter/material.dart';
import '../data/menu_repository.dart';
import '../domain/food_item.dart';
import 'widgets/food_item_card.dart';
import 'widgets/add_item_modal.dart';
import '../../admin/presentation/daily_planner_screen.dart';
import '../../admin/presentation/meal_packages_screen.dart';

/// Menu screen with three tabs:
///  1. Master Items – the reusable food item library
///  2. Daily Planner – weekly calendar view for daily rotating menus (Veg + Non-Veg)
///  3. Packages – tenant-defined subscription tiers with pricing
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Tab bar ──
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 1,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(icon: Icon(Icons.restaurant_menu), text: 'Master Items'),
              Tab(icon: Icon(Icons.calendar_month), text: 'Daily Planner'),
              Tab(icon: Icon(Icons.card_giftcard), text: 'Packages'),
            ],
          ),
        ),
        // ── Tab views ──
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: const [
              _MasterItemsTab(),
              DailyPlannerScreen(),
              MealPackagesScreen(),
            ],
          ),
        ),
      ],
    );
  }
}

/// The original master items grid, extracted into its own widget.
class _MasterItemsTab extends StatefulWidget {
  const _MasterItemsTab();

  @override
  State<_MasterItemsTab> createState() => _MasterItemsTabState();
}

class _MasterItemsTabState extends State<_MasterItemsTab>
    with AutomaticKeepAliveClientMixin {
  final MenuRepository _repository = MenuRepository();
  List<FoodItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _repository.getFoodItems();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _addNewItem(FoodItem item) async {
    try {
      await _repository.addFoodItem(item);
      _loadItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Item added successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to add item: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleItemStatus(FoodItem item, bool isActive) async {
    // Optimistic update
    final previousItems = List<FoodItem>.from(_items);
    setState(() {
      final index = _items.indexWhere((element) => element.id == item.id);
      if (index != -1) {
        _items[index] = item.copyWith(isActive: isActive);
      }
    });

    try {
      await _repository.toggleActiveStatus(item.id, isActive);
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() => _items = previousItems);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update item status'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showAddItemModal() {
    showDialog(
      context: context,
      builder: (context) => AddItemModal(onSave: _addNewItem),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Master Item Library',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (!_isLoading)
                    IconButton(
                      onPressed: _loadItems,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddItemModal,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadItems,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No menu items yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first item to get started',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadItems,
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
    );
  }
}
