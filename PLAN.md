# Fun Adventure Kitchen — 3-Layer SaaS Implementation Plan

> **Status:** All backend phases + Phase 5 (SaaS Owner Dashboard) implemented. See below for what was built and the complete API reference.

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                    LAYER 1: SaaS Owner                          │
│  /api/saas/*  (Superuser only)                                  │
│  Tenant management, Plans, Billing, Analytics                    │
├─────────────────────────────────────────────────────────────────┤
│                    LAYER 2: Tenant Admin                         │
│  /api/v1/*  (Staff auth + X-Tenant-Slug header)                 │
│  Orders, Menu, Kitchen KDS, Inventory, Delivery,                │
│  Staff, Customers, Invoices, Notifications                      │
├─────────────────────────────────────────────────────────────────┤
│                    LAYER 3: B2C Customers                       │
│  /api/v1/customer/*  (Customer JWT auth)                        │
│  Register, Login, Menu browse, Subscriptions, Orders,           │
│  Wallet, Invoices, Notifications, Addresses                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Completed Phases

### Phase 1.1 — Fix Cross-Database FK ✅
- `CustomerProfile.tenant` → `tenant_id` IntegerField
- `InventoryItem.tenant` → `tenant_id` IntegerField
- Prevents cross-DB foreign key errors at runtime

### Phase 1.2 — Expand ServicePlan Model ✅
Added to `ServicePlan`:
- Pricing: `price_monthly`, `price_yearly`, `trial_days`
- Limits: `max_menu_items`, `max_staff_users`, `max_customers`, `max_orders_per_month`
- Features: `has_delivery_tracking`, `has_customer_app`, `has_analytics`, `has_whatsapp_notifications`, `has_multi_branch`
- JSON `features` field for extensible feature flags
- `tier` choices (free/basic/pro/enterprise)
- Helper methods: `has_feature()`, `check_limit()`

### Phase 1.3 — Plan Enforcement ✅
- `MultiDbTenantMiddleware` now attaches `request.tenant_plan`
- Created `PlanLimitMenuItems`, `PlanLimitStaffUsers`, `PlanLimitCustomers`
- Created `PlanFeatureInventory`, `PlanFeatureDeliveryTracking`, `PlanFeatureAnalytics`
- Permissions auto-check limits on `create` actions

### Phase 1.4 — Build Missing ViewSets ✅

| ViewSet | App | Endpoint |
|---------|-----|----------|
| `OrderViewSet` | main | `/api/v1/orders/` |
| `CustomerProfileViewSet` | main | `/api/v1/customers/` |
| `CustomerRegistrationRequestViewSet` | main | `/api/v1/registration-requests/` |
| `InvoiceViewSet` | main | `/api/v1/invoices/` |
| `NotificationViewSet` | main | `/api/v1/notifications/` |
| `CategoryViewSet` | main | `/api/v1/categories/` |
| `StaffUserViewSet` | main | `/api/v1/staff/` |
| `KitchenOrderViewSet` | kitchen | `/api/v1/kitchen/orders/` |
| `DeliveryViewSet` | delivery | `/api/v1/delivery/deliveries/` |
| `InventoryItemViewSet` | inventory | `/api/v1/inventory/items/` |
| `UnitOfMeasureViewSet` | inventory | `/api/v1/inventory/units/` |
| `ZoneViewSet` | driver | `/api/v1/driver/zones/` |
| `RouteViewSet` | driver | `/api/v1/driver/routes/` |
| `DeliveryDriverViewSet` | driver | `/api/v1/driver/drivers/` |
| `DeliveryScheduleViewSet` | driver | `/api/v1/driver/schedules/` |
| `DeliveryAssignmentAdminViewSet` | driver | `/api/v1/driver/assignments/` |

### Phase 1.5 — Customer-Facing APIs (B2C) ✅

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/v1/customer/auth/register/` | POST | None | Customer registration |
| `/api/v1/customer/auth/login/` | POST | None | Customer login (JWT) |
| `/api/v1/customer/menu/` | GET | None | Browse available menu |
| `/api/v1/customer/menu/categories/` | GET | None | List categories |
| `/api/v1/customer/profile/` | GET/PUT | JWT | View/update profile |
| `/api/v1/customer/subscriptions/` | GET/POST | JWT | Manage subscriptions |
| `/api/v1/customer/orders/` | GET | JWT | View order history |
| `/api/v1/customer/orders/{id}/track/` | GET | JWT | Delivery tracking |
| `/api/v1/customer/wallet/` | GET | JWT | Balance + transactions |
| `/api/v1/customer/wallet/topup/` | POST | JWT | Add funds |
| `/api/v1/customer/invoices/` | GET | JWT | View invoices |
| `/api/v1/customer/notifications/` | GET | JWT | List notifications |
| `/api/v1/customer/notifications/{id}/mark_read/` | POST | JWT | Mark read |
| `/api/v1/customer/notifications/mark_all_read/` | POST | JWT | Mark all read |
| `/api/v1/customer/addresses/` | CRUD | JWT | Manage addresses |

### Phase 3.1 — SaaS Owner Models ✅
- `TenantSubscription` — tracks plan, status, billing cycle, trial
- `TenantInvoice` — auto-numbered invoices with tax and status
- `TenantUsage` — monthly usage snapshots (orders, customers, revenue)

### Phase 3.2 — SaaS Owner API ✅

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/api/saas/analytics/` | GET | Superuser | Platform-wide metrics |
| `/api/saas/tenants/` | GET/POST | Superuser | List/create tenants |
| `/api/saas/tenants/{id}/` | GET/PATCH | Superuser | Detail/update |
| `/api/saas/tenants/{id}/usage/` | GET | Superuser | Usage metrics |
| `/api/saas/tenants/{id}/suspend/` | POST | Superuser | Suspend tenant |
| `/api/saas/tenants/{id}/activate/` | POST | Superuser | Activate tenant |
| `/api/saas/plans/` | CRUD | Superuser | Manage service plans |
| `/api/saas/subscriptions/` | CRUD | Superuser | Manage subscriptions |
| `/api/saas/invoices/` | CRUD | Superuser | Manage invoices |
| `/api/saas/invoices/{id}/mark_paid/` | POST | Superuser | Mark invoice paid |

---

## Files Created / Modified

### New Files
| File | Purpose |
|------|---------|
| `core/permissions/plan_limits.py` | Plan-based permission classes |
| `apps/main/serializers/__init__.py` | Serializer package init |
| `apps/main/serializers/admin_serializers.py` | Tenant-admin serializers |
| `apps/main/serializers/customer_api_serializers.py` | B2C customer serializers |
| `apps/main/views/admin_views.py` | Tenant-admin ViewSets |
| `apps/main/views/customer_api_views.py` | B2C customer ViewSets |
| `apps/main/urls_customer_api.py` | Customer API URL routing |
| `apps/kitchen/serializers.py` | Kitchen KDS serializers |
| `apps/delivery/serializers.py` | Delivery serializers |
| `apps/inventory/serializers.py` | Inventory serializers |
| `apps/driver/serializers/admin_serializers.py` | Zone/Route/Schedule serializers |
| `apps/driver/views/admin_views.py` | Delivery management ViewSets |
| `apps/organizations/models_saas.py` | SaaS owner models |
| `apps/organizations/serializers.py` | SaaS owner serializers |
| `apps/organizations/views_saas.py` | SaaS owner ViewSets |
| `apps/organizations/urls_saas.py` | SaaS owner URL routing |

### Modified Files
| File | Change |
|------|--------|
| `apps/main/models.py` | FK → IntegerField for `CustomerProfile.tenant` |
| `apps/main/admin.py` | Updated admin for new field |
| `apps/main/urls_api.py` | Registered new ViewSets |
| `apps/main/views/__init__.py` | Added new view exports |
| `apps/organizations/models.py` | Expanded ServicePlan |
| `apps/organizations/admin.py` | Admin for SaaS models |
| `apps/inventory/models.py` | FK → IntegerField, added fields |
| `apps/inventory/admin.py` | Updated admin |
| `apps/inventory/views.py` | Added ViewSets |
| `apps/inventory/urls_api.py` | Router-based URLs |
| `apps/kitchen/views.py` | Added KitchenOrderViewSet |
| `apps/kitchen/urls_api.py` | Router-based URLs |
| `apps/delivery/views.py` | Added DeliveryViewSet |
| `apps/delivery/urls_api.py` | Router-based URLs |
| `apps/driver/urls_api.py` | Added admin ViewSets |
| `apps/driver/views/__init__.py` | Added admin view exports |
| `core/middleware/multi_db_tenant.py` | Attaches `request.tenant_plan` |
| `core/permissions/__init__.py` | Imports plan_limits |
| `config/urls.py` | Added customer + SaaS URL routes |

---

## Remaining Work (Future Phases)

### Phase 2 — Flutter Admin Dashboard Screens ✅
- **Dashboard overview** — summary metric cards (orders, deliveries, revenue, customers, inventory, staff) with recent orders table
- **Orders screen** — tab-filtered list with status workflow (pending→confirmed→preparing→ready→delivered), cancel support
- **Inventory screen** — CRUD with stock adjustment dialog, low-stock filter, cost/supplier tracking
- **Delivery screen** — tab-filtered list with driver info, status tracking, pickup/delivery times
- **Customers screen** — customer list with search, registration request approval/rejection with reasons
- **Finance screen** — invoice list with status tabs, detail dialog with line items, paid/pending summary chips
- **Staff screen** — CRUD with role assignment (manager/kitchen_staff/driver/staff), deactivation, change-role dialog

#### Backend Addition (Phase 2)
- `GET /api/v1/dashboard/summary/` — aggregated tenant dashboard metrics (orders, customers, revenue, inventory, deliveries, staff)

#### Management Commands
- `python manage.py migrate_all_tenants` — migrate all tenant databases (supports `--parallel`, `--tenant=<slug>`)
- `python manage.py provision_tenant` — full tenant provisioning (DB create, migrate, admin user, plan assignment)

#### New Flutter Files (Phase 2)
| File | Purpose |
|------|---------|
| `features/admin/domain/models.dart` | Domain models (DashboardSummary, OrderItem, CustomerItem, InvoiceItem, InventoryItemModel, DeliveryItem, StaffUser) |
| `features/admin/data/admin_repository.dart` | Repository wrapping all `/api/v1/` tenant admin endpoints |
| `features/admin/presentation/dashboard_screen.dart` | Dashboard overview with metric cards and recent orders |
| `features/admin/presentation/orders_screen.dart` | Orders management with status workflow |
| `features/admin/presentation/inventory_screen.dart` | Inventory management with stock adjustment |
| `features/admin/presentation/delivery_screen.dart` | Delivery tracking with status filters |
| `features/admin/presentation/customers_screen.dart` | Customer + registration request management |
| `features/admin/presentation/finance_screen.dart` | Invoice listing with detail dialog |
| `features/admin/presentation/staff_screen.dart` | Staff CRUD with role management |

### Phase 4 — Flutter Customer App
- Customer registration / login
- Menu browsing
- Subscription management
- Order tracking
- Wallet / payments
- Push notifications

### Phase 5 — SaaS Owner Dashboard (Flutter) ✅
- **Overview screen** — platform-wide analytics cards (total/active/trial tenants, MRR, ARR, pending/overdue invoices)
- **Tenants screen** — searchable data table with status badges, suspend/activate actions, create-tenant dialog
- **Tenant detail screen** — subscription info, plan limits, latest usage metrics
- **Plans screen** — card-based grid with pricing, feature limits, create/edit/toggle active
- **SaaS Shell** — dark indigo sidebar, dedicated header, fully responsive with mobile drawer
- **Router integration** — `/saas`, `/saas/tenants`, `/saas/tenants/:id`, `/saas/plans` routes in GoRouter
- **Tenant sidebar** — "Platform Admin" link to switch between tenant admin and SaaS owner dashboards

#### New Flutter Files (Phase 5)
| File | Purpose |
|------|---------|
| `features/saas_admin/domain/models.dart` | Dart domain models (ServicePlan, Tenant, TenantDetail, Subscription, Usage, Analytics) |
| `features/saas_admin/data/saas_repository.dart` | Repository wrapping all `/api/saas/` endpoints |
| `features/saas_admin/presentation/saas_shell.dart` | SaaS dashboard layout shell |
| `features/saas_admin/presentation/saas_overview_screen.dart` | Analytics overview (home) |
| `features/saas_admin/presentation/tenants_screen.dart` | Tenant management list |
| `features/saas_admin/presentation/tenant_detail_screen.dart` | Tenant detail view |
| `features/saas_admin/presentation/plans_screen.dart` | Service plan management |
| `features/saas_admin/presentation/widgets/saas_sidebar.dart` | Dark sidebar navigation |
| `features/saas_admin/presentation/widgets/saas_header.dart` | SaaS header bar |

### Phase 6 — Production Hardening
- Celery tasks for usage collection
- Payment gateway integration (Stripe / PayTabs)
- Email / WhatsApp notification service
- Rate limiting per plan tier
- Comprehensive test suite
