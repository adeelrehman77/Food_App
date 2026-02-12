// Domain models for the Tenant Admin dashboard.
// Maps to the Django REST Framework serializers in apps/main, apps/inventory,
// apps/delivery, and apps/driver.

// ─── Dashboard Summary ──────────────────────────────────────────────────────

class DashboardSummary {
  final OrdersSummary orders;
  final CustomersSummary customers;
  final RevenueSummary revenue;
  final StaffSummary staff;
  final InventorySummary inventory;
  final DeliveriesSummary deliveries;
  final List<OrderItem> recentOrders;

  DashboardSummary({
    required this.orders,
    required this.customers,
    required this.revenue,
    required this.staff,
    required this.inventory,
    required this.deliveries,
    required this.recentOrders,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      orders: OrdersSummary.fromJson(json['orders'] ?? {}),
      customers: CustomersSummary.fromJson(json['customers'] ?? {}),
      revenue: RevenueSummary.fromJson(json['revenue'] ?? {}),
      staff: StaffSummary.fromJson(json['staff'] ?? {}),
      inventory: InventorySummary.fromJson(json['inventory'] ?? {}),
      deliveries: DeliveriesSummary.fromJson(json['deliveries'] ?? {}),
      recentOrders: (json['recent_orders'] as List? ?? [])
          .map((e) => OrderItem.fromJson(e))
          .toList(),
    );
  }
}

class OrdersSummary {
  final int total;
  final int today;
  final int pending;
  final int preparing;

  OrdersSummary({
    required this.total,
    required this.today,
    required this.pending,
    required this.preparing,
  });

  factory OrdersSummary.fromJson(Map<String, dynamic> json) {
    return OrdersSummary(
      total: json['total'] ?? 0,
      today: json['today'] ?? 0,
      pending: json['pending'] ?? 0,
      preparing: json['preparing'] ?? 0,
    );
  }
}

class CustomersSummary {
  final int total;
  final int activeSubscriptions;
  final int pendingRegistrations;

  CustomersSummary({
    required this.total,
    required this.activeSubscriptions,
    required this.pendingRegistrations,
  });

  factory CustomersSummary.fromJson(Map<String, dynamic> json) {
    return CustomersSummary(
      total: json['total'] ?? 0,
      activeSubscriptions: json['active_subscriptions'] ?? 0,
      pendingRegistrations: json['pending_registrations'] ?? 0,
    );
  }
}

class RevenueSummary {
  final double monthly;
  final int pendingInvoices;
  final int overdueInvoices;

  RevenueSummary({
    required this.monthly,
    required this.pendingInvoices,
    required this.overdueInvoices,
  });

  factory RevenueSummary.fromJson(Map<String, dynamic> json) {
    return RevenueSummary(
      monthly: (json['monthly'] ?? 0).toDouble(),
      pendingInvoices: json['pending_invoices'] ?? 0,
      overdueInvoices: json['overdue_invoices'] ?? 0,
    );
  }
}

class StaffSummary {
  final int total;

  StaffSummary({required this.total});

  factory StaffSummary.fromJson(Map<String, dynamic> json) {
    return StaffSummary(total: json['total'] ?? 0);
  }
}

class InventorySummary {
  final int lowStockCount;

  InventorySummary({required this.lowStockCount});

  factory InventorySummary.fromJson(Map<String, dynamic> json) {
    return InventorySummary(lowStockCount: json['low_stock_count'] ?? 0);
  }
}

class DeliveriesSummary {
  final int today;
  final int completed;

  DeliveriesSummary({required this.today, required this.completed});

  factory DeliveriesSummary.fromJson(Map<String, dynamic> json) {
    return DeliveriesSummary(
      today: json['today'] ?? 0,
      completed: json['completed'] ?? 0,
    );
  }
}

// ─── Order ──────────────────────────────────────────────────────────────────

class OrderItem {
  final int id;
  final int? subscriptionId;
  final String? orderDate;
  final String? deliveryDate;
  final String status;
  final int quantity;
  final String? specialInstructions;
  final String? customerName;
  final String? customerPhone;
  final String? createdAt;
  final String? updatedAt;

  OrderItem({
    required this.id,
    this.subscriptionId,
    this.orderDate,
    this.deliveryDate,
    required this.status,
    required this.quantity,
    this.specialInstructions,
    this.customerName,
    this.customerPhone,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      subscriptionId: json['subscription'],
      orderDate: json['order_date'],
      deliveryDate: json['delivery_date'],
      status: json['status'] ?? 'pending',
      quantity: json['quantity'] ?? 0,
      specialInstructions: json['special_instructions'],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

// ─── Customer Address ────────────────────────────────────────────────────────

class CustomerAddress {
  final int id;
  final int? customerId;
  final String? customerName;
  final String? street;
  final String? city;
  final String? buildingName;
  final String? floorNumber;
  final String? flatNumber;
  final bool isDefault;
  final String status;
  final String? createdAt;

  CustomerAddress({
    required this.id,
    this.customerId,
    this.customerName,
    this.street,
    this.city,
    this.buildingName,
    this.floorNumber,
    this.flatNumber,
    this.isDefault = false,
    this.status = 'active',
    this.createdAt,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: json['id'] ?? 0,
      customerId: json['customer'],
      customerName: json['customer_name'],
      street: json['street'],
      city: json['city'],
      buildingName: json['building_name'],
      floorNumber: json['floor_number'],
      flatNumber: json['flat_number'],
      isDefault: json['is_default'] ?? false,
      status: json['status'] ?? 'active',
      createdAt: json['created_at'],
    );
  }

  String get displayString {
    final parts = <String>[];
    if (buildingName != null && buildingName!.isNotEmpty) parts.add(buildingName!);
    if (flatNumber != null && flatNumber!.isNotEmpty) parts.add('Flat $flatNumber');
    if (floorNumber != null && floorNumber!.isNotEmpty) parts.add('Floor $floorNumber');
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  Map<String, dynamic> toJson({int? forCustomerId}) {
    return {
      if (forCustomerId != null) 'customer': forCustomerId,
      'building_name': buildingName ?? '',
      'flat_number': flatNumber ?? '',
      'floor_number': floorNumber ?? '',
      'street': street ?? '',
      'city': city ?? '',
      'is_default': isDefault,
    };
  }
}

// ─── Customer ───────────────────────────────────────────────────────────────

class CustomerItem {
  final int id;
  final String? username;
  final String? email;
  final String? fullName;
  final String name;
  final String? phone;
  final String? emiratesId;
  final String? zone;
  final double walletBalance;
  final int loyaltyPoints;
  final String loyaltyTier;
  final String? preferredCommunication;
  final List<CustomerAddress> addresses;
  final String? createdAt;

  CustomerItem({
    required this.id,
    this.username,
    this.email,
    this.fullName,
    required this.name,
    this.phone,
    this.emiratesId,
    this.zone,
    this.walletBalance = 0,
    this.loyaltyPoints = 0,
    this.loyaltyTier = 'bronze',
    this.preferredCommunication,
    this.addresses = const [],
    this.createdAt,
  });

  /// The default or first address, if any.
  CustomerAddress? get defaultAddress {
    if (addresses.isEmpty) return null;
    return addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first);
  }

  factory CustomerItem.fromJson(Map<String, dynamic> json) {
    return CustomerItem(
      id: json['id'] ?? 0,
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      name: json['name'] ?? '',
      phone: json['phone'],
      emiratesId: json['emirates_id'],
      zone: json['zone'],
      walletBalance: double.tryParse(json['wallet_balance']?.toString() ?? '0') ?? 0,
      loyaltyPoints: json['loyalty_points'] ?? 0,
      loyaltyTier: json['loyalty_tier'] ?? 'bronze',
      preferredCommunication: json['preferred_communication'],
      addresses: (json['addresses'] as List<dynamic>?)
              ?.map((a) => CustomerAddress.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['created_at'],
    );
  }
}

// ─── Registration Request ───────────────────────────────────────────────────

class RegistrationRequest {
  final int id;
  final String name;
  final String contactNumber;
  final String? address;
  final String? mealSelection;
  final String? mealType;
  final int quantity;
  final String status;
  final String? adminNotes;
  final String? rejectionReason;
  final String? createdAt;
  final String? processedAt;

  RegistrationRequest({
    required this.id,
    required this.name,
    required this.contactNumber,
    this.address,
    this.mealSelection,
    this.mealType,
    this.quantity = 0,
    required this.status,
    this.adminNotes,
    this.rejectionReason,
    this.createdAt,
    this.processedAt,
  });

  factory RegistrationRequest.fromJson(Map<String, dynamic> json) {
    return RegistrationRequest(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      contactNumber: json['contact_number'] ?? '',
      address: json['address'],
      mealSelection: json['meal_selection'],
      mealType: json['meal_type'],
      quantity: json['quantity'] ?? 0,
      status: json['status'] ?? 'pending',
      adminNotes: json['admin_notes'],
      rejectionReason: json['rejection_reason'],
      createdAt: json['created_at'],
      processedAt: json['processed_at'],
    );
  }
}

// ─── Invoice ────────────────────────────────────────────────────────────────

/// Parse API value (num or String from Django DecimalField) to double.
double _invoiceDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

/// Summary for Finance screen cards (from GET /invoices/summary/).
class InvoiceSummary {
  final double paidTotal;
  final double pendingTotal;
  final int totalCount;
  final int overdueCount;

  InvoiceSummary({
    this.paidTotal = 0,
    this.pendingTotal = 0,
    this.totalCount = 0,
    this.overdueCount = 0,
  });

  factory InvoiceSummary.fromJson(Map<String, dynamic> json) {
    return InvoiceSummary(
      paidTotal: _invoiceDouble(json['paid_total']),
      pendingTotal: _invoiceDouble(json['pending_total']),
      totalCount: json['total_count'] ?? 0,
      overdueCount: json['overdue_count'] ?? 0,
    );
  }
}

class InvoiceItem {
  final int id;
  final String invoiceNumber;
  final int? customerId;
  final String? customerName;
  final String? date;
  final String? dueDate;
  final double total;
  final String status;
  final String? notes;
  final List<InvoiceLineItem> items;
  final String? createdAt;

  InvoiceItem({
    required this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName,
    this.date,
    this.dueDate,
    this.total = 0,
    required this.status,
    this.notes,
    this.items = const [],
    this.createdAt,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      id: json['id'] ?? 0,
      invoiceNumber: json['invoice_number'] ?? '',
      customerId: json['customer'],
      customerName: json['customer_name'],
      date: json['date'],
      dueDate: json['due_date'],
      total: _invoiceDouble(json['total']),
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      items: (json['items'] as List? ?? [])
          .map((e) => InvoiceLineItem.fromJson(e))
          .toList(),
      createdAt: json['created_at'],
    );
  }
}

class InvoiceLineItem {
  final int id;
  final String? menuName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  InvoiceLineItem({
    required this.id,
    this.menuName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    final qty = json['quantity'];
    final quantity = qty is num ? qty.toInt() : (int.tryParse(qty?.toString() ?? '') ?? 0);
    return InvoiceLineItem(
      id: json['id'] ?? 0,
      menuName: json['menu_name'],
      quantity: quantity,
      unitPrice: _invoiceDouble(json['unit_price']),
      totalPrice: _invoiceDouble(json['total_price']),
    );
  }
}

// ─── Unit of Measure ────────────────────────────────────────────────────────

class UnitOfMeasure {
  final int id;
  final String name;
  final String abbreviation;
  final String category;
  final double conversionFactor;

  UnitOfMeasure({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.category,
    this.conversionFactor = 1.0,
  });

  factory UnitOfMeasure.fromJson(Map<String, dynamic> json) {
    return UnitOfMeasure(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      abbreviation: json['abbreviation'] ?? '',
      category: json['category'] ?? '',
      conversionFactor:
          double.tryParse('${json['conversion_factor']}') ?? 1.0,
    );
  }
}

// ─── Inventory Item ─────────────────────────────────────────────────────────

class InventoryItemModel {
  final int id;
  final String name;
  final String description;
  final int? unitId;
  final String? unitName;
  final String? unitAbbreviation;
  final double currentStock;
  final double minStockLevel;
  final double costPerUnit;
  final String? supplier;
  final bool isActive;
  final bool isLowStock;
  final String? createdAt;
  final String? updatedAt;

  InventoryItemModel({
    required this.id,
    required this.name,
    this.description = '',
    this.unitId,
    this.unitName,
    this.unitAbbreviation,
    this.currentStock = 0,
    this.minStockLevel = 0,
    this.costPerUnit = 0,
    this.supplier,
    this.isActive = true,
    this.isLowStock = false,
    this.createdAt,
    this.updatedAt,
  });

  factory InventoryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryItemModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      unitId: json['unit'],
      unitName: json['unit_name'],
      unitAbbreviation: json['unit_abbreviation'],
      currentStock: double.tryParse('${json['current_stock']}') ?? 0,
      minStockLevel: double.tryParse('${json['min_stock_level']}') ?? 0,
      costPerUnit: double.tryParse('${json['cost_per_unit']}') ?? 0,
      supplier: json['supplier'],
      isActive: json['is_active'] ?? true,
      isLowStock: json['is_low_stock'] ?? false,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      if (unitId != null) 'unit': unitId,
      'current_stock': currentStock.toString(),
      'min_stock_level': minStockLevel.toString(),
      'cost_per_unit': costPerUnit.toString(),
      'supplier': supplier ?? '',
      'is_active': isActive,
    };
  }
}

// ─── Delivery ───────────────────────────────────────────────────────────────

class DeliveryItem {
  final int id;
  final int? orderId;
  final int? driverId;
  final String? driverName;
  final String? customerName;
  final String? deliveryAddress;
  final String? pickupTime;
  final String? deliveryTime;
  final String status;
  final String? notes;
  final String? createdAt;

  DeliveryItem({
    required this.id,
    this.orderId,
    this.driverId,
    this.driverName,
    this.customerName,
    this.deliveryAddress,
    this.pickupTime,
    this.deliveryTime,
    required this.status,
    this.notes,
    this.createdAt,
  });

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    return DeliveryItem(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? json['order'],
      driverId: json['driver'],
      driverName: json['driver_name'],
      customerName: json['customer_name'],
      deliveryAddress: json['delivery_address'],
      pickupTime: json['pickup_time'],
      deliveryTime: json['delivery_time'],
      status: json['status'] ?? 'pending',
      notes: json['notes'],
      createdAt: json['created_at'],
    );
  }
}

// ─── Delivery Driver ────────────────────────────────────────────────────────

class DriverZoneBrief {
  final int id;
  final String name;

  DriverZoneBrief({required this.id, required this.name});

  factory DriverZoneBrief.fromJson(Map<String, dynamic> json) {
    return DriverZoneBrief(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class DriverRouteBrief {
  final int id;
  final String name;
  final int zoneId;
  final String? zoneName;

  DriverRouteBrief({
    required this.id,
    required this.name,
    required this.zoneId,
    this.zoneName,
  });

  factory DriverRouteBrief.fromJson(Map<String, dynamic> json) {
    return DriverRouteBrief(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      zoneId: json['zone'] ?? 0,
      zoneName: json['zone_name'],
    );
  }
}

class DeliveryDriver {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? vehicleNumber;
  final String? vehicleType;
  final bool isActive;
  final List<DriverZoneBrief> assignedZones;
  final List<DriverRouteBrief> assignedRoutes;
  final String? createdAt;

  DeliveryDriver({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.vehicleNumber,
    this.vehicleType,
    this.isActive = true,
    this.assignedZones = const [],
    this.assignedRoutes = const [],
    this.createdAt,
  });

  factory DeliveryDriver.fromJson(Map<String, dynamic> json) {
    return DeliveryDriver(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      vehicleNumber: json['vehicle_number'],
      vehicleType: json['vehicle_type'],
      isActive: json['is_active'] ?? true,
      assignedZones: (json['assigned_zones'] as List? ?? [])
          .map((e) => DriverZoneBrief.fromJson(e as Map<String, dynamic>))
          .toList(),
      assignedRoutes: (json['assigned_routes'] as List? ?? [])
          .map((e) => DriverRouteBrief.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (vehicleNumber != null) 'vehicle_number': vehicleNumber,
      if (vehicleType != null) 'vehicle_type': vehicleType,
      'is_active': isActive,
    };
  }
}

// ─── Delivery Zone ──────────────────────────────────────────────────────────

class DeliveryZone {
  final int id;
  final String name;
  final String? description;
  final double deliveryFee;
  final int estimatedDeliveryTime;
  final bool isActive;
  final int routeCount;
  final int assignedDriverCount;
  final String? createdAt;

  DeliveryZone({
    required this.id,
    required this.name,
    this.description,
    this.deliveryFee = 0,
    this.estimatedDeliveryTime = 30,
    this.isActive = true,
    this.routeCount = 0,
    this.assignedDriverCount = 0,
    this.createdAt,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      deliveryFee: double.tryParse('${json['delivery_fee']}') ?? 0,
      estimatedDeliveryTime: json['estimated_delivery_time'] ?? 30,
      isActive: json['is_active'] ?? true,
      routeCount: json['route_count'] ?? 0,
      assignedDriverCount: json['assigned_driver_count'] ?? 0,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description ?? '',
      'delivery_fee': deliveryFee.toStringAsFixed(2),
      'estimated_delivery_time': estimatedDeliveryTime,
      'is_active': isActive,
    };
  }
}

// ─── Delivery Route ─────────────────────────────────────────────────────────

class DeliveryRoute {
  final int id;
  final String name;
  final int zoneId;
  final String? zoneName;
  final String? description;
  final bool isActive;
  final int assignedDriverCount;
  final String? createdAt;

  DeliveryRoute({
    required this.id,
    required this.name,
    required this.zoneId,
    this.zoneName,
    this.description,
    this.isActive = true,
    this.assignedDriverCount = 0,
    this.createdAt,
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    return DeliveryRoute(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      zoneId: json['zone'] ?? 0,
      zoneName: json['zone_name'],
      description: json['description'],
      isActive: json['is_active'] ?? true,
      assignedDriverCount: json['assigned_driver_count'] ?? 0,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'zone': zoneId,
      'description': description ?? '',
      'is_active': isActive,
    };
  }
}

// ─── Staff User ─────────────────────────────────────────────────────────────

class StaffUser {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final bool isActive;
  final bool isStaff;
  final String role;
  final String? dateJoined;
  final String? lastLogin;

  StaffUser({
    required this.id,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.isActive = true,
    this.isStaff = true,
    required this.role,
    this.dateJoined,
    this.lastLogin,
  });

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? username : name;
  }

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      isActive: json['is_active'] ?? true,
      isStaff: json['is_staff'] ?? true,
      role: json['role'] ?? 'staff',
      dateJoined: json['date_joined'],
      lastLogin: json['last_login'],
    );
  }
}

// ─── Meal Slot ──────────────────────────────────────────────────────────────

class MealSlot {
  final int id;
  final String name;
  final String code;
  final String? cutoffTime;
  final int sortOrder;
  final bool isActive;
  final String? createdAt;

  MealSlot({
    required this.id,
    required this.name,
    required this.code,
    this.cutoffTime,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  factory MealSlot.fromJson(Map<String, dynamic> json) {
    return MealSlot(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      cutoffTime: json['cutoff_time'],
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'],
    );
  }
}

// ─── Subscription ───────────────────────────────────────────────────────────

class SubscriptionItem {
  final int id;
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final String status;
  final String startDate;
  final String endDate;
  final int? timeSlot;
  final String? timeSlotName;
  final int? mealPackageId;
  final String? mealPackageName;
  final List<String> selectedDays;
  final String paymentMode;
  final String dietType; // 'veg' or 'nonveg'
  final double costPerMeal;
  final double totalCost;
  final String? dietaryPreferences;
  final String? specialInstructions;
  final bool wantNotifications;
  final int? lunchAddress;
  final int? dinnerAddress;
  final Map<String, dynamic>? lunchAddressDetails;
  final Map<String, dynamic>? dinnerAddressDetails;
  final Map<String, dynamic>? timeSlotDetails;
  final int orderCount;
  final String? createdAt;

  SubscriptionItem({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.timeSlot,
    this.timeSlotName,
    this.mealPackageId,
    this.mealPackageName,
    this.selectedDays = const [],
    this.paymentMode = 'wallet',
    this.dietType = 'nonveg',
    this.costPerMeal = 0,
    this.totalCost = 0,
    this.dietaryPreferences,
    this.specialInstructions,
    this.wantNotifications = true,
    this.lunchAddress,
    this.dinnerAddress,
    this.lunchAddressDetails,
    this.dinnerAddressDetails,
    this.timeSlotDetails,
    this.orderCount = 0,
    this.createdAt,
  });

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) {
    return SubscriptionItem(
      id: json['id'] ?? 0,
      customerId: json['customer_id'] ?? json['customer'] ?? 0,
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'],
      status: json['status'] ?? 'pending',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      timeSlot: json['time_slot'],
      timeSlotName: json['time_slot_name'] ??
          (json['time_slot_details'] as Map<String, dynamic>?)?['name'],
      mealPackageId: json['meal_package'],
      mealPackageName: json['meal_package_name'] ??
          (json['meal_package_details'] as Map<String, dynamic>?)?['name'],
      selectedDays: (json['selected_days'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      paymentMode: json['payment_mode'] ?? 'wallet',
      dietType: json['diet_type'] ?? 'nonveg',
      costPerMeal: double.tryParse('${json['cost_per_meal']}') ?? 0,
      totalCost: double.tryParse('${json['total_cost']}') ?? 0,
      dietaryPreferences: json['dietary_preferences'],
      specialInstructions: json['special_instructions'],
      wantNotifications: json['want_notifications'] ?? true,
      lunchAddress: json['lunch_address'],
      dinnerAddress: json['dinner_address'],
      lunchAddressDetails: json['lunch_address_details'] as Map<String, dynamic>?,
      dinnerAddressDetails: json['dinner_address_details'] as Map<String, dynamic>?,
      timeSlotDetails: json['time_slot_details'] as Map<String, dynamic>?,
      orderCount: json['order_count'] ?? 0,
      createdAt: json['created_at'],
    );
  }
}

// ─── Daily Menu Item ────────────────────────────────────────────────────────

class DailyMenuItem {
  final int id;
  final int masterItemId;
  final String masterItemName;
  final double masterItemPrice;
  final String? masterItemImage;
  final String? categoryName;
  final double? overridePrice;
  final double effectivePrice;
  final String portionLabel;
  final int sortOrder;
  final String? createdAt;

  DailyMenuItem({
    required this.id,
    required this.masterItemId,
    required this.masterItemName,
    required this.masterItemPrice,
    this.masterItemImage,
    this.categoryName,
    this.overridePrice,
    required this.effectivePrice,
    this.portionLabel = '',
    this.sortOrder = 0,
    this.createdAt,
  });

  factory DailyMenuItem.fromJson(Map<String, dynamic> json) {
    return DailyMenuItem(
      id: json['id'] ?? 0,
      masterItemId: json['master_item'] ?? 0,
      masterItemName: json['master_item_name'] ?? '',
      masterItemPrice:
          double.tryParse('${json['master_item_price']}') ?? 0,
      masterItemImage: json['master_item_image'],
      categoryName: json['category_name'],
      overridePrice: json['override_price'] != null
          ? double.tryParse('${json['override_price']}')
          : null,
      effectivePrice:
          double.tryParse('${json['effective_price']}') ?? 0,
      portionLabel: json['portion_label'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toWriteJson() {
    return {
      'master_item': masterItemId,
      if (overridePrice != null) 'override_price': overridePrice.toString(),
      'portion_label': portionLabel,
      'sort_order': sortOrder,
    };
  }
}

// ─── Daily Menu ─────────────────────────────────────────────────────────────

class DailyMenu {
  final int id;
  final String menuDate;
  final int mealSlotId;
  final String mealSlotName;
  final String mealSlotCode;
  final String dietType; // 'veg' or 'nonveg'
  final String dietTypeDisplay;
  final String status;
  final int itemCount;
  final String notes;
  final List<DailyMenuItem> items;
  final String? createdAt;
  final String? updatedAt;

  DailyMenu({
    required this.id,
    required this.menuDate,
    required this.mealSlotId,
    required this.mealSlotName,
    required this.mealSlotCode,
    this.dietType = 'nonveg',
    this.dietTypeDisplay = 'Non-Vegetarian',
    required this.status,
    this.itemCount = 0,
    this.notes = '',
    this.items = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory DailyMenu.fromJson(Map<String, dynamic> json) {
    return DailyMenu(
      id: json['id'] ?? 0,
      menuDate: json['menu_date'] ?? '',
      mealSlotId: json['meal_slot'] ?? 0,
      mealSlotName: json['meal_slot_name'] ?? '',
      mealSlotCode: json['meal_slot_code'] ?? '',
      dietType: json['diet_type'] ?? 'nonveg',
      dietTypeDisplay: json['diet_type_display'] ?? 'Non-Vegetarian',
      status: json['status'] ?? 'draft',
      itemCount: json['item_count'] ?? 0,
      notes: json['notes'] ?? '',
      items: (json['items'] as List? ?? [])
          .map((e) => DailyMenuItem.fromJson(e))
          .toList(),
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

// ─── Menu Plan (bundle of menu items for MealPackage) ───────────────────────

class MenuPlan {
  final int id;
  final String name;
  final String? description;
  final double price;
  final List<int> menuItemIds;

  MenuPlan({
    required this.id,
    required this.name,
    this.description,
    this.price = 0,
    this.menuItemIds = const [],
  });

  factory MenuPlan.fromJson(Map<String, dynamic> json) {
    final rawItems = json['menu_items'] ?? json['menu_item_ids'];
    List<int> ids = [];
    if (rawItems is List) {
      for (final x in rawItems) {
        if (x is int) {
          ids.add(x);
        } else if (x is num) {
          ids.add(x.toInt());
        } else if (x is Map && x['id'] != null) {
          ids.add((x['id'] as num).toInt());
        }
      }
    }
    return MenuPlan(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      price: double.tryParse('${json['price']}') ?? 0,
      menuItemIds: ids,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description ?? '',
        'price': price.toStringAsFixed(2),
        'is_active': true,
        if (menuItemIds.isNotEmpty) 'menu_item_ids': menuItemIds,
      };
}

// ─── Meal Package (Subscription Tier) ───────────────────────────────────────

class MealPackage {
  final int id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final String dietType;
  final String dietTypeDisplay;
  final String duration;
  final String durationDisplay;
  final int durationDays;
  final int mealsPerDay;
  final String portionLabel;
  final List<MenuPlan> menus;
  final int sortOrder;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;

  MealPackage({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.currency = '',
    this.dietType = 'both',
    this.dietTypeDisplay = 'Both',
    this.duration = 'monthly',
    this.durationDisplay = 'Monthly',
    this.durationDays = 30,
    this.mealsPerDay = 2,
    this.portionLabel = '',
    this.menus = const [],
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory MealPackage.fromJson(Map<String, dynamic> json) {
    return MealPackage(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      currency: json['currency'] ?? '',
      dietType: json['diet_type'] ?? 'both',
      dietTypeDisplay: json['diet_type_display'] ?? 'Both',
      duration: json['duration'] ?? 'monthly',
      durationDisplay: json['duration_display'] ?? 'Monthly',
      durationDays: json['duration_days'] ?? 30,
      mealsPerDay: json['meals_per_day'] ?? 2,
      portionLabel: json['portion_label'] ?? '',
      menus: (json['menus'] as List? ?? [])
          .map((e) => MenuPlan.fromJson(e as Map<String, dynamic>))
          .toList(),
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price.toStringAsFixed(2),
      'currency': currency,
      'diet_type': dietType,
      'duration': duration,
      'duration_days': durationDays,
      'meals_per_day': mealsPerDay,
      'portion_label': portionLabel,
      if (menuIds.isNotEmpty) 'menu_ids': menuIds,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  /// IDs of menus in this package (for API write).
  List<int> get menuIds => menus.map((m) => m.id).toList();
}
