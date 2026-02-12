import '../domain/food_item.dart';
import '../../../core/network/api_client.dart';

/// Repository that fetches menu items from the backend API.
class MenuRepository {
  final ApiClient _apiClient;

  MenuRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetch all menu items from the API.
  Future<List<FoodItem>> getFoodItems() async {
    final baseUrl = await _apiClient.getBaseUrl();
    final response = await _apiClient.dio.get('${baseUrl}menu-items/');

    if (response.statusCode == 200) {
      final data = response.data;
      // Handle both paginated and non-paginated responses
      final List<dynamic> results =
          data is Map ? (data['results'] ?? []) : (data as List);
      return results.map((json) => FoodItem.fromJson(json)).toList();
    }
    throw Exception('Failed to load menu items');
  }

  /// Add a new menu item.
  Future<FoodItem> addFoodItem(FoodItem item) async {
    final baseUrl = await _apiClient.getBaseUrl();
    final response = await _apiClient.dio.post(
      '${baseUrl}menu-items/',
      data: item.toJson(),
    );

    if (response.statusCode == 201) {
      return FoodItem.fromJson(response.data);
    }
    throw Exception('Failed to add menu item');
  }

  /// Update an existing menu item.
  Future<FoodItem> updateFoodItem(FoodItem item) async {
    final baseUrl = await _apiClient.getBaseUrl();
    final response = await _apiClient.dio.patch(
      '${baseUrl}menu-items/${item.id}/',
      data: item.toJson(),
    );

    if (response.statusCode == 200) {
      return FoodItem.fromJson(response.data);
    }
    throw Exception('Failed to update menu item');
  }

  /// Toggle the availability status of a menu item.
  Future<void> toggleActiveStatus(String id, bool isActive) async {
    final baseUrl = await _apiClient.getBaseUrl();
    await _apiClient.dio.post(
      '${baseUrl}menu-items/$id/toggle_availability/',
    );
  }

  /// Fetch all categories.
  Future<List<Map<String, dynamic>>> getCategories() async {
    final baseUrl = await _apiClient.getBaseUrl();
    final response = await _apiClient.dio.get('${baseUrl}categories/');

    if (response.statusCode == 200) {
      final data = response.data;
      final List<dynamic> results =
          data is Map ? (data['results'] ?? []) : (data as List);
      return results.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load categories');
  }

  /// Create a new category.
  Future<Map<String, dynamic>> createCategory(String name, {String description = ''}) async {
    final baseUrl = await _apiClient.getBaseUrl();
    final response = await _apiClient.dio.post(
      '${baseUrl}categories/',
      data: {'name': name, 'description': description},
    );

    if (response.statusCode == 201) {
      return response.data as Map<String, dynamic>;
    }
    throw Exception('Failed to create category');
  }
}
