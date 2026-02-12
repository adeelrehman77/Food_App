import 'package:equatable/equatable.dart';

/// Domain model for a food/menu item.
///
/// Field names align with the backend `MenuItem` model and its serializer:
///   - `price` (backend) <-> `basePrice` (UI convenience alias)
///   - `is_available` (backend) <-> `isActive` (UI convenience alias)
class FoodItem extends Equatable {
  final String id;
  final String name;
  final String description;
  final double basePrice;
  final int calories;
  final List<String> allergens;
  final bool isActive;
  final int? categoryId;
  final String? categoryName;
  final String dietType; // 'veg', 'nonveg', or 'both'
  final String? dietTypeDisplay;
  final String? inventoryItemId;
  final String? imageUrl;

  const FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.basePrice,
    required this.calories,
    required this.allergens,
    required this.isActive,
    this.categoryId,
    this.categoryName,
    this.dietType = 'both',
    this.dietTypeDisplay,
    this.inventoryItemId,
    this.imageUrl,
  });

  /// Deserialize from backend JSON.
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      basePrice: (json['price'] is String)
          ? double.tryParse(json['price']) ?? 0.0
          : (json['price'] as num?)?.toDouble() ?? 0.0,
      calories: json['calories'] ?? 0,
      allergens: (json['allergens'] is List)
          ? List<String>.from(json['allergens'])
          : <String>[],
      isActive: json['is_available'] ?? true,
      categoryId: json['category'],
      categoryName: json['category_name'],
      dietType: json['diet_type'] ?? 'both',
      dietTypeDisplay: json['diet_type_display'],
      inventoryItemId: json['inventory_item_id']?.toString(),
      imageUrl: json['image'],
    );
  }

  /// Serialize to JSON for sending to backend.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': basePrice.toStringAsFixed(2),
      'calories': calories,
      'allergens': allergens,
      if (categoryId != null) 'category': categoryId,
      'diet_type': dietType,
      'is_available': isActive,
      if (inventoryItemId != null) 'inventory_item': inventoryItemId,
    };
  }

  FoodItem copyWith({
    String? id,
    String? name,
    String? description,
    double? basePrice,
    int? calories,
    List<String>? allergens,
    bool? isActive,
    int? categoryId,
    String? categoryName,
    String? dietType,
    String? dietTypeDisplay,
    String? inventoryItemId,
    String? imageUrl,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      basePrice: basePrice ?? this.basePrice,
      calories: calories ?? this.calories,
      allergens: allergens ?? this.allergens,
      isActive: isActive ?? this.isActive,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      dietType: dietType ?? this.dietType,
      dietTypeDisplay: dietTypeDisplay ?? this.dietTypeDisplay,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        basePrice,
        calories,
        allergens,
        isActive,
        categoryId,
        categoryName,
        dietType,
        inventoryItemId,
        imageUrl,
      ];
}
