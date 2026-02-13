import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/models.dart';

/// Repository for all tenant-admin API calls.
/// Endpoints are under /api/v1/ and require X-Tenant-Slug header.
class AdminRepository {
  final ApiClient _apiClient;

  AdminRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<String> _baseUrl() => _apiClient.getBaseUrl();

  List<T> _parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is Map) {
      return (data['results'] as List? ?? [])
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final messages = <String>[];
      data.forEach((key, value) {
        if (value is List) {
          messages.add('$key: ${value.join(', ')}');
        } else {
          messages.add('$key: $value');
        }
      });
      if (messages.isNotEmpty) return messages.join('\n');
    }
    return e.message ?? 'Request failed';
  }

  // ─── Dashboard ────────────────────────────────────────────────────────────

  Future<DashboardSummary> getDashboardSummary() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}dashboard/summary/');
    return DashboardSummary.fromJson(response.data);
  }

  // ─── Orders ───────────────────────────────────────────────────────────────

  /// Fetch orders with optional filters and pagination support.
  /// Returns a paginated response with count, next, previous, and results.
  Future<Map<String, dynamic>> getOrdersPaginated({
    String? status,
    String? deliveryDate,
    String? orderDate,
    String? nextUrl,
  }) async {
    final base = await _baseUrl();
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (deliveryDate != null && deliveryDate.isNotEmpty) params['delivery_date'] = deliveryDate;
    if (orderDate != null && orderDate.isNotEmpty) params['order_date'] = orderDate;
    
    final url = nextUrl ?? '${base}orders/';
    final response = await _apiClient.dio.get(
      url,
      queryParameters: nextUrl == null ? params : null,
    );
    
    final data = response.data as Map<String, dynamic>;
    return {
      'count': data['count'] ?? 0,
      'next': data['next'],
      'previous': data['previous'],
      'results': _parseList(data, OrderItem.fromJson),
    };
  }

  /// Fetch all orders (handles pagination automatically).
  /// Use this for simple cases where you want all results.
  Future<List<OrderItem>> getOrders({
    String? status,
    String? deliveryDate,
    String? orderDate,
  }) async {
    final List<OrderItem> allOrders = [];
    String? nextUrl;
    
    do {
      final response = await getOrdersPaginated(
        status: status,
        deliveryDate: deliveryDate,
        orderDate: orderDate,
        nextUrl: nextUrl,
      );
      allOrders.addAll(response['results'] as List<OrderItem>);
      nextUrl = response['next'] as String?;
    } while (nextUrl != null);
    
    return allOrders;
  }

  Future<OrderItem> getOrder(int id) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}orders/$id/');
    return OrderItem.fromJson(response.data);
  }

  Future<OrderItem> updateOrderStatus(int id, String newStatus) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}orders/$id/update_status/',
      data: {'status': newStatus},
    );
    return OrderItem.fromJson(response.data);
  }

  // ─── Customers ────────────────────────────────────────────────────────────

  Future<List<CustomerItem>> getCustomers({String? search}) async {
    final base = await _baseUrl();
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final response = await _apiClient.dio.get(
      '${base}customers/',
      queryParameters: params,
    );
    return _parseList(response.data, CustomerItem.fromJson);
  }

  Future<List<RegistrationRequest>> getRegistrationRequests({
    String? status,
  }) async {
    final base = await _baseUrl();
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _apiClient.dio.get(
      '${base}registration-requests/',
      queryParameters: params,
    );
    return _parseList(response.data, RegistrationRequest.fromJson);
  }

  Future<CustomerItem> createCustomer(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}customers/',
      data: data,
    );
    return CustomerItem.fromJson(response.data);
  }

  Future<CustomerItem> updateCustomer(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.patch(
      '${base}customers/$id/',
      data: data,
    );
    return CustomerItem.fromJson(response.data);
  }

  // ─── Customer Addresses ──────────────────────────────────────────────────

  Future<CustomerAddress> createAddress(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}customer-addresses/',
        data: data,
      );
      return CustomerAddress.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<CustomerAddress> updateAddress(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.patch(
        '${base}customer-addresses/$id/',
        data: data,
      );
      return CustomerAddress.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> deleteAddress(int id) async {
    final base = await _baseUrl();
    await _apiClient.dio.delete('${base}customer-addresses/$id/');
  }

  Future<Map<String, dynamic>> approveRegistration(int id) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}registration-requests/$id/approve/',
    );
    return response.data as Map<String, dynamic>;
  }

  Future<RegistrationRequest> rejectRegistration(int id, String reason) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}registration-requests/$id/reject/',
      data: {'reason': reason},
    );
    return RegistrationRequest.fromJson(response.data);
  }

  // ─── Invoices ─────────────────────────────────────────────────────────────

  Future<InvoiceSummary> getInvoiceSummary() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}invoices/summary/');
    return InvoiceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<InvoiceItem>> getInvoices({String? status}) async {
    final base = await _baseUrl();
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _apiClient.dio.get(
      '${base}invoices/',
      queryParameters: params,
    );
    return _parseList(response.data, InvoiceItem.fromJson);
  }

  Future<InvoiceItem> markInvoicePaid(int id) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post('${base}invoices/$id/mark_paid/');
    return InvoiceItem.fromJson(response.data as Map<String, dynamic>);
  }

  // ─── Inventory ────────────────────────────────────────────────────────────

  Future<List<UnitOfMeasure>> getUnits() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}inventory/units/');
    return _parseList(response.data, UnitOfMeasure.fromJson);
  }

  Future<List<InventoryItemModel>> getInventoryItems() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}inventory/items/');
    return _parseList(response.data, InventoryItemModel.fromJson);
  }

  Future<List<InventoryItemModel>> getLowStockItems() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}inventory/items/low_stock/');
    return _parseList(response.data, InventoryItemModel.fromJson);
  }

  Future<InventoryItemModel> createInventoryItem(
      Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}inventory/items/',
        data: data,
      );
      return InventoryItemModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<InventoryItemModel> updateInventoryItem(
      int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.patch(
        '${base}inventory/items/$id/',
        data: data,
      );
      return InventoryItemModel.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<InventoryItemModel> adjustStock(int id, double quantity) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}inventory/items/$id/adjust_stock/',
      data: {'quantity': quantity.toString()},
    );
    return InventoryItemModel.fromJson(response.data);
  }

  // ─── Deliveries ───────────────────────────────────────────────────────────

  /// Fetch deliveries with pagination support.
  Future<Map<String, dynamic>> getDeliveriesPaginated({
    String? status,
    String? nextUrl,
  }) async {
    final base = await _baseUrl();
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    
    final url = nextUrl ?? '${base}delivery/deliveries/';
    final response = await _apiClient.dio.get(
      url,
      queryParameters: nextUrl == null ? params : null,
    );
    
    final data = response.data as Map<String, dynamic>;
    return {
      'count': data['count'] ?? 0,
      'next': data['next'],
      'previous': data['previous'],
      'results': _parseList(data, DeliveryItem.fromJson),
    };
  }

  /// Fetch all deliveries (handles pagination automatically).
  Future<List<DeliveryItem>> getDeliveries({String? status}) async {
    final List<DeliveryItem> allDeliveries = [];
    String? nextUrl;
    
    do {
      final response = await getDeliveriesPaginated(
        status: status,
        nextUrl: nextUrl,
      );
      allDeliveries.addAll(response['results'] as List<DeliveryItem>);
      nextUrl = response['next'] as String?;
    } while (nextUrl != null);
    
    return allDeliveries;
  }

  Future<DeliveryItem> updateDeliveryStatus(int id, String newStatus) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}delivery/deliveries/$id/update_status/',
      data: {'status': newStatus},
    );
    return DeliveryItem.fromJson(response.data);
  }

  Future<DeliveryItem> assignDeliveryDriver(int deliveryId, int driverId) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}delivery/deliveries/$deliveryId/assign_driver/',
      data: {'driver_id': driverId},
    );
    return DeliveryItem.fromJson(response.data);
  }

  // ─── Delivery Drivers ────────────────────────────────────────────────────

  Future<List<DeliveryDriver>> getDrivers() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}driver/drivers/');
    return _parseList(response.data, DeliveryDriver.fromJson);
  }

  Future<DeliveryDriver> createDriver(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}driver/drivers/',
        data: data,
      );
      return DeliveryDriver.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<DeliveryDriver> updateDriver(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.patch(
        '${base}driver/drivers/$id/',
        data: data,
      );
      return DeliveryDriver.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> deleteDriver(int id) async {
    final base = await _baseUrl();
    await _apiClient.dio.delete('${base}driver/drivers/$id/');
  }

  Future<DeliveryDriver> toggleDriverActive(int id) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}driver/drivers/$id/toggle_active/',
    );
    return DeliveryDriver.fromJson(response.data);
  }

  Future<DeliveryDriver> assignDriverZones(int driverId, List<int> zoneIds) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}driver/drivers/$driverId/assign_zones/',
      data: {'zone_ids': zoneIds},
    );
    return DeliveryDriver.fromJson(response.data);
  }

  Future<DeliveryDriver> assignDriverRoutes(int driverId, List<int> routeIds) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}driver/drivers/$driverId/assign_routes/',
      data: {'route_ids': routeIds},
    );
    return DeliveryDriver.fromJson(response.data);
  }

  // ─── Delivery Zones ─────────────────────────────────────────────────────

  Future<List<DeliveryZone>> getZones() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}driver/zones/');
    return _parseList(response.data, DeliveryZone.fromJson);
  }

  Future<DeliveryZone> createZone(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}driver/zones/',
        data: data,
      );
      return DeliveryZone.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<DeliveryZone> updateZone(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.patch(
        '${base}driver/zones/$id/',
        data: data,
      );
      return DeliveryZone.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> deleteZone(int id) async {
    final base = await _baseUrl();
    await _apiClient.dio.delete('${base}driver/zones/$id/');
  }

  // ─── Delivery Routes ────────────────────────────────────────────────────

  Future<List<DeliveryRoute>> getRoutes({int? zoneId}) async {
    final base = await _baseUrl();
    final params = <String, dynamic>{};
    if (zoneId != null) params['zone'] = zoneId;
    final response = await _apiClient.dio.get(
      '${base}driver/routes/',
      queryParameters: params,
    );
    return _parseList(response.data, DeliveryRoute.fromJson);
  }

  Future<DeliveryRoute> createRoute(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}driver/routes/',
        data: data,
      );
      return DeliveryRoute.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<DeliveryRoute> updateRoute(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.patch(
        '${base}driver/routes/$id/',
        data: data,
      );
      return DeliveryRoute.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> deleteRoute(int id) async {
    final base = await _baseUrl();
    await _apiClient.dio.delete('${base}driver/routes/$id/');
  }

  // ─── Staff ────────────────────────────────────────────────────────────────

  Future<List<StaffUser>> getStaffUsers() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}staff/');
    return _parseList(response.data, StaffUser.fromJson);
  }

  Future<StaffUser> createStaffUser(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post('${base}staff/', data: data);
      return StaffUser.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> deactivateStaffUser(int id) async {
    final base = await _baseUrl();
    await _apiClient.dio.post('${base}staff/$id/deactivate/');
  }

  Future<StaffUser> changeStaffRole(int id, String role) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post(
      '${base}staff/$id/change_role/',
      data: {'role': role},
    );
    return StaffUser.fromJson(response.data);
  }

  // ─── Meal Slots ──────────────────────────────────────────────────────────

  Future<List<MealSlot>> getMealSlots() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}meal-slots/');
    return _parseList(response.data, MealSlot.fromJson);
  }

  // ─── Subscriptions (Admin) ────────────────────────────────────────────────

  /// Fetch subscriptions with pagination support.
  Future<Map<String, dynamic>> getSubscriptionsPaginated({
    String? status,
    String? nextUrl,
  }) async {
    final base = await _baseUrl();
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    
    final url = nextUrl ?? '${base}subscriptions-admin/';
    final response = await _apiClient.dio.get(
      url,
      queryParameters: nextUrl == null ? params : null,
    );
    
    final data = response.data as Map<String, dynamic>;
    return {
      'count': data['count'] ?? 0,
      'next': data['next'],
      'previous': data['previous'],
      'results': _parseList(data, SubscriptionItem.fromJson),
    };
  }

  /// Fetch all subscriptions (handles pagination automatically).
  Future<List<SubscriptionItem>> getSubscriptions({String? status}) async {
    final List<SubscriptionItem> allSubscriptions = [];
    String? nextUrl;
    
    do {
      final response = await getSubscriptionsPaginated(
        status: status,
        nextUrl: nextUrl,
      );
      allSubscriptions.addAll(response['results'] as List<SubscriptionItem>);
      nextUrl = response['next'] as String?;
    } while (nextUrl != null);
    
    return allSubscriptions;
  }

  Future<SubscriptionItem> getSubscription(int id) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}subscriptions-admin/$id/');
    return SubscriptionItem.fromJson(response.data);
  }

  Future<SubscriptionItem> createSubscription(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}subscriptions-admin/',
        data: data,
      );
      return SubscriptionItem.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<SubscriptionItem> updateSubscription(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.patch(
        '${base}subscriptions-admin/$id/',
        data: data,
      );
      return SubscriptionItem.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<SubscriptionItem> activateSubscription(int id) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}subscriptions-admin/$id/activate/',
      );
      return SubscriptionItem.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<SubscriptionItem> pauseSubscription(int id) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}subscriptions-admin/$id/pause/',
      );
      return SubscriptionItem.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<SubscriptionItem> cancelSubscription(int id) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}subscriptions-admin/$id/cancel/',
      );
      return SubscriptionItem.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<Map<String, dynamic>> generateOrders(int subscriptionId) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}subscriptions-admin/$subscriptionId/generate_orders/',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// Fetch time slots for subscription forms.
  Future<List<Map<String, dynamic>>> getTimeSlots() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}meal-slots/');
    if (response.data is Map && response.data['results'] != null) {
      return (response.data['results'] as List).cast<Map<String, dynamic>>();
    }
    if (response.data is List) {
      return (response.data as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── Daily Menus ─────────────────────────────────────────────────────────

  /// Fetch a week's menus. [startDate] should be a Monday (YYYY-MM-DD).
  Future<Map<String, dynamic>> getWeekMenus(String startDate) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get(
      '${base}daily-menus/week/',
      queryParameters: {'start': startDate},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Fetch today's published menus (customer-facing).
  Future<List<DailyMenu>> getTodayMenus() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}daily-menus/today/');
    if (response.data is List) {
      return (response.data as List)
          .map((e) => DailyMenu.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Fetch daily menus with optional filters.
  Future<List<DailyMenu>> getDailyMenus({
    String? dateFrom,
    String? dateTo,
    int? mealSlot,
    String? status,
  }) async {
    final base = await _baseUrl();
    final params = <String, dynamic>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (mealSlot != null) params['meal_slot'] = mealSlot;
    if (status != null && status.isNotEmpty) params['status'] = status;
    final response = await _apiClient.dio.get(
      '${base}daily-menus/',
      queryParameters: params,
    );
    return _parseList(response.data, DailyMenu.fromJson);
  }

  /// Fetch a single daily menu with full items.
  Future<DailyMenu> getDailyMenu(int id) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}daily-menus/$id/');
    return DailyMenu.fromJson(response.data);
  }

  /// Create a new daily menu (with items).
  Future<DailyMenu> createDailyMenu(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}daily-menus/',
        data: data,
      );
      return DailyMenu.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// Update an existing daily menu (with items).
  Future<DailyMenu> updateDailyMenu(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.patch(
        '${base}daily-menus/$id/',
        data: data,
      );
      return DailyMenu.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// Delete a daily menu.
  Future<void> deleteDailyMenu(int id) async {
    final base = await _baseUrl();
    await _apiClient.dio.delete('${base}daily-menus/$id/');
  }

  /// Publish a daily menu.
  Future<DailyMenu> publishDailyMenu(int id) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}daily-menus/$id/publish/',
      );
      return DailyMenu.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  /// Close a daily menu.
  Future<DailyMenu> closeDailyMenu(int id) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}daily-menus/$id/close/',
      );
      return DailyMenu.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  // ─── Menus (Menu plans for MealPackage) ───────────────────────────────────

  Future<List<MenuPlan>> getMenus() async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.get('${base}menus/');
    return _parseList(response.data, MenuPlan.fromJson);
  }

  Future<MenuPlan> createMenu(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.post('${base}menus/', data: data);
    return MenuPlan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<MenuPlan> updateMenu(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    final response = await _apiClient.dio.patch('${base}menus/$id/', data: data);
    return MenuPlan.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteMenu(int id) async {
    final base = await _baseUrl();
    await _apiClient.dio.delete('${base}menus/$id/');
  }

  // ─── Meal Packages ─────────────────────────────────────────────────────────

  Future<List<MealPackage>> getMealPackages({String? dietType}) async {
    final base = await _baseUrl();
    final params = <String, dynamic>{};
    if (dietType != null && dietType.isNotEmpty) params['diet_type'] = dietType;
    final response = await _apiClient.dio.get(
      '${base}meal-packages/',
      queryParameters: params,
    );
    return _parseList(response.data, MealPackage.fromJson);
  }

  Future<MealPackage> createMealPackage(Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.post(
        '${base}meal-packages/',
        data: data,
      );
      return MealPackage.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<MealPackage> updateMealPackage(int id, Map<String, dynamic> data) async {
    final base = await _baseUrl();
    try {
      final response = await _apiClient.dio.patch(
        '${base}meal-packages/$id/',
        data: data,
      );
      return MealPackage.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<void> deleteMealPackage(int id) async {
    final base = await _baseUrl();
    await _apiClient.dio.delete('${base}meal-packages/$id/');
  }
}
