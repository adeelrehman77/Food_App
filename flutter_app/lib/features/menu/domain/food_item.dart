import 'package:equatable/equatable.dart';

class FoodItem extends Equatable {
  final String id;
  final String name;
  final String description;
  final double basePrice;
  final int calories;
  final List<String> allergens;
  final bool isActive;
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
    this.inventoryItemId,
    this.imageUrl,
  });

  FoodItem copyWith({
    String? id,
    String? name,
    String? description,
    double? basePrice,
    int? calories,
    List<String>? allergens,
    bool? isActive,
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
        inventoryItemId,
        imageUrl,
      ];
}
