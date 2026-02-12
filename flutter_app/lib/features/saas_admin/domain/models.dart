// Domain models for the SaaS Owner dashboard.
// These map 1:1 to the /api/saas/ backend responses.

class ServicePlan {
  final int id;
  final String name;
  final String tier;
  final String description;
  final double priceMonthly;
  final double priceYearly;
  final int trialDays;
  final int maxMenuItems;
  final int maxStaffUsers;
  final int maxCustomers;
  final int maxOrdersPerMonth;
  final bool hasInventoryManagement;
  final bool hasDeliveryTracking;
  final bool hasCustomerApp;
  final bool hasAnalytics;
  final bool isActive;
  final int tenantCount;

  const ServicePlan({
    required this.id,
    required this.name,
    required this.tier,
    this.description = '',
    this.priceMonthly = 0,
    this.priceYearly = 0,
    this.trialDays = 14,
    this.maxMenuItems = 50,
    this.maxStaffUsers = 5,
    this.maxCustomers = 500,
    this.maxOrdersPerMonth = 1000,
    this.hasInventoryManagement = false,
    this.hasDeliveryTracking = false,
    this.hasCustomerApp = false,
    this.hasAnalytics = false,
    this.isActive = true,
    this.tenantCount = 0,
  });

  factory ServicePlan.fromJson(Map<String, dynamic> json) {
    return ServicePlan(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      tier: json['tier'] ?? 'basic',
      description: json['description'] ?? '',
      priceMonthly: double.tryParse('${json['price_monthly']}') ?? 0,
      priceYearly: double.tryParse('${json['price_yearly']}') ?? 0,
      trialDays: json['trial_days'] ?? 14,
      maxMenuItems: json['max_menu_items'] ?? 50,
      maxStaffUsers: json['max_staff_users'] ?? 5,
      maxCustomers: json['max_customers'] ?? 500,
      maxOrdersPerMonth: json['max_orders_per_month'] ?? 1000,
      hasInventoryManagement: json['has_inventory_management'] ?? false,
      hasDeliveryTracking: json['has_delivery_tracking'] ?? false,
      hasCustomerApp: json['has_customer_app'] ?? false,
      hasAnalytics: json['has_analytics'] ?? false,
      isActive: json['is_active'] ?? true,
      tenantCount: json['tenant_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'tier': tier,
        'description': description,
        'price_monthly': priceMonthly.toStringAsFixed(2),
        'price_yearly': priceYearly.toStringAsFixed(2),
        'trial_days': trialDays,
        'max_menu_items': maxMenuItems,
        'max_staff_users': maxStaffUsers,
        'max_customers': maxCustomers,
        'max_orders_per_month': maxOrdersPerMonth,
        'has_inventory_management': hasInventoryManagement,
        'has_delivery_tracking': hasDeliveryTracking,
        'has_customer_app': hasCustomerApp,
        'has_analytics': hasAnalytics,
        'is_active': isActive,
      };

  String get tierLabel {
    switch (tier) {
      case 'free':
        return 'Free / Trial';
      case 'basic':
        return 'Basic';
      case 'pro':
        return 'Professional';
      case 'enterprise':
        return 'Enterprise';
      default:
        return tier;
    }
  }
}

class Tenant {
  final int id;
  final String name;
  final String subdomain;
  final bool isActive;
  final String planName;
  final String subscriptionStatus;
  final String createdOn;

  const Tenant({
    required this.id,
    required this.name,
    required this.subdomain,
    this.isActive = true,
    this.planName = 'No Plan',
    this.subscriptionStatus = 'No Subscription',
    this.createdOn = '',
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      subdomain: json['subdomain'] ?? '',
      isActive: json['is_active'] ?? true,
      planName: json['plan_name'] ?? 'No Plan',
      subscriptionStatus: json['subscription_status'] ?? 'No Subscription',
      createdOn: json['created_on'] ?? '',
    );
  }
}

class TenantDetail extends Tenant {
  final ServicePlan? servicePlan;
  final TenantSubscription? subscription;
  final TenantUsage? latestUsage;

  const TenantDetail({
    required super.id,
    required super.name,
    required super.subdomain,
    super.isActive,
    super.planName,
    super.subscriptionStatus,
    super.createdOn,
    this.servicePlan,
    this.subscription,
    this.latestUsage,
  });

  factory TenantDetail.fromJson(Map<String, dynamic> json) {
    return TenantDetail(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      subdomain: json['subdomain'] ?? '',
      isActive: json['is_active'] ?? true,
      planName: json['service_plan']?['name'] ?? 'No Plan',
      createdOn: json['created_on'] ?? '',
      servicePlan: json['service_plan'] != null
          ? ServicePlan.fromJson(json['service_plan'])
          : null,
      subscription: json['subscription'] != null
          ? TenantSubscription.fromJson(json['subscription'])
          : null,
      latestUsage: json['latest_usage'] != null
          ? TenantUsage.fromJson(json['latest_usage'])
          : null,
    );
  }
}

class TenantSubscription {
  final int id;
  final String planName;
  final String status;
  final String billingCycle;
  final String currentPeriodStart;
  final String currentPeriodEnd;
  final String? trialEnd;
  final double currentPrice;

  const TenantSubscription({
    required this.id,
    required this.planName,
    required this.status,
    this.billingCycle = 'monthly',
    this.currentPeriodStart = '',
    this.currentPeriodEnd = '',
    this.trialEnd,
    this.currentPrice = 0,
  });

  factory TenantSubscription.fromJson(Map<String, dynamic> json) {
    return TenantSubscription(
      id: json['id'] ?? 0,
      planName: json['plan_name'] ?? '',
      status: json['status'] ?? '',
      billingCycle: json['billing_cycle'] ?? 'monthly',
      currentPeriodStart: json['current_period_start'] ?? '',
      currentPeriodEnd: json['current_period_end'] ?? '',
      trialEnd: json['trial_end'],
      currentPrice: double.tryParse('${json['current_price']}') ?? 0,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'trial':
        return 'Trial';
      case 'active':
        return 'Active';
      case 'past_due':
        return 'Past Due';
      case 'cancelled':
        return 'Cancelled';
      case 'suspended':
        return 'Suspended';
      default:
        return status;
    }
  }
}

class TenantUsage {
  final int orderCount;
  final int customerCount;
  final int staffCount;
  final int menuItemCount;
  final int subscriptionCount;
  final double revenue;
  final String period;

  const TenantUsage({
    this.orderCount = 0,
    this.customerCount = 0,
    this.staffCount = 0,
    this.menuItemCount = 0,
    this.subscriptionCount = 0,
    this.revenue = 0,
    this.period = '',
  });

  factory TenantUsage.fromJson(Map<String, dynamic> json) {
    return TenantUsage(
      orderCount: json['order_count'] ?? 0,
      customerCount: json['customer_count'] ?? 0,
      staffCount: json['staff_count'] ?? 0,
      menuItemCount: json['menu_item_count'] ?? 0,
      subscriptionCount: json['subscription_count'] ?? 0,
      revenue: double.tryParse('${json['revenue']}') ?? 0,
      period: json['period'] ?? '',
    );
  }
}

class PlatformAnalytics {
  final int totalTenants;
  final int activeTenants;
  final int trialTenants;
  final double totalRevenueMonthly;
  final double totalRevenueYearly;
  final int pendingInvoices;
  final int overdueInvoices;

  const PlatformAnalytics({
    this.totalTenants = 0,
    this.activeTenants = 0,
    this.trialTenants = 0,
    this.totalRevenueMonthly = 0,
    this.totalRevenueYearly = 0,
    this.pendingInvoices = 0,
    this.overdueInvoices = 0,
  });

  factory PlatformAnalytics.fromJson(Map<String, dynamic> json) {
    return PlatformAnalytics(
      totalTenants: json['total_tenants'] ?? 0,
      activeTenants: json['active_tenants'] ?? 0,
      trialTenants: json['trial_tenants'] ?? 0,
      totalRevenueMonthly:
          double.tryParse('${json['total_revenue_monthly']}') ?? 0,
      totalRevenueYearly:
          double.tryParse('${json['total_revenue_yearly']}') ?? 0,
      pendingInvoices: json['pending_invoices'] ?? 0,
      overdueInvoices: json['overdue_invoices'] ?? 0,
    );
  }
}
