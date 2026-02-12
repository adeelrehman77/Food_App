import 'package:flutter/material.dart';
import '../../domain/food_item.dart';

class FoodItemCard extends StatelessWidget {
  final FoodItem item;
  final Function(bool) onToggleActive;
  final Function() onTap;

  const FoodItemCard({
    super.key,
    required this.item,
    required this.onToggleActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Placeholder
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(
                  color: Colors.grey[200],
                  width: double.infinity,
                  child: item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                                child: Icon(Icons.broken_image,
                                    size: 50, color: Colors.grey));
                          },
                        )
                      : const Center(
                          child: Icon(Icons.fastfood,
                              size: 50, color: Colors.grey)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${item.basePrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Diet type badge
                  _DietBadge(dietType: item.dietType),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Active/Inactive Badge/Toggle
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: item.isActive,
                              onChanged: onToggleActive,
                              activeThumbColor: Colors.green,
                            ),
                            Text(
                              item.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: item.isActive ? Colors.green : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (item.allergens.isNotEmpty)
                        Tooltip(
                          message: 'Allergens: ${item.allergens.join(', ')}',
                          child: const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.orange),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DietBadge extends StatelessWidget {
  final String dietType;
  const _DietBadge({required this.dietType});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    final IconData icon;
    switch (dietType) {
      case 'veg':
        color = Colors.green;
        label = 'Veg';
        icon = Icons.eco;
      case 'nonveg':
        color = Colors.red.shade700;
        label = 'Non-Veg';
        icon = Icons.restaurant;
      default:
        color = Colors.blue;
        label = 'Both';
        icon = Icons.all_inclusive;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
