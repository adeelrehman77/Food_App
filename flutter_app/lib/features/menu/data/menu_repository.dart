import 'package:uuid/uuid.dart';
import '../domain/food_item.dart';

class MenuRepository {
  final List<FoodItem> _mockItems = [
    const FoodItem(
      id: '1',
      name: 'Classic Burger',
      description: 'Juicy beef patty with lettuce, tomato, and cheese.',
      basePrice: 12.99,
      calories: 850,
      allergens: ['Gluten', 'Dairy'],
      isActive: true,
      imageUrl: 'https://via.placeholder.com/150',
    ),
    const FoodItem(
      id: '2',
      name: 'Vegan Salad',
      description: 'Fresh greens with avocado and vinaigrette.',
      basePrice: 10.50,
      calories: 350,
      allergens: [],
      isActive: true,
      imageUrl: 'https://via.placeholder.com/150',
    ),
      const FoodItem(
      id: '3',
      name: 'Spicy Wings',
      description: 'Chicken wings tossed in hot sauce.',
      basePrice: 15.00,
      calories: 900,
      allergens: ['Gluten'],
      isActive: false,
      imageUrl: 'https://via.placeholder.com/150',
    ),
  ];

  Future<List<FoodItem>> getFoodItems() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockItems;
  }

  Future<void> addFoodItem(FoodItem item) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newItem = item.copyWith(id: const Uuid().v4());
    _mockItems.add(newItem);
  }

  Future<void> updateFoodItem(FoodItem item) async {
      await Future.delayed(const Duration(milliseconds: 500));
      final index = _mockItems.indexWhere((element) => element.id == item.id);
      if (index != -1) {
          _mockItems[index] = item;
      }
  }

    Future<void> toggleActiveStatus(String id, bool isActive) async {
      await Future.delayed(const Duration(milliseconds: 200));
      final index = _mockItems.indexWhere((element) => element.id == id);
      if (index != -1) {
          _mockItems[index] = _mockItems[index].copyWith(isActive: isActive);
      }
  }
}
