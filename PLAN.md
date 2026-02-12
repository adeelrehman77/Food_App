# Fun Adventure Kitchen — 3-Layer SaaS Implementation Plan

> **Status:** All backend phases + Phase 5 (SaaS Owner Dashboard) + Phase 6 (Daily Rotating Menu) + Phase 7 (Customer Management) implemented. See below for what was built and the complete API reference.

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
│  Staff, Customers, Invoices, Notifications,                     │
│  Daily Menus, Meal Packages, Addresses                          │
├─────────────────────────────────────────────────────────────────┤
│                    LAYER 3: B2C Customers                       │
│  /api/v1/customer/*  (Customer JWT auth)                        │
│  Register, Login, Menu browse, Subscriptions, Orders,           │
│  Wallet, Invoices, Notifications, Addresses                     │
└─────────────────────────────────────────────────────────────────┘
```

### Multi-Tenant Database Routing

```
┌─────────────────────────────────────────────────────────────────┐
│                     TenantRouter                                 │
│                                                                  │
│  SAAS_ONLY_APPS → always route to 'default' DB                  │
│    organizations, users, admin, sites, axes, django_apscheduler  │
│                                                                  │
│  ALL OTHER APPS → follow tenant context (thread-local alias)     │
│    auth, contenttypes, sessions, main, kitchen, delivery,        │
│    driver, inventory, account, authtoken                         │
│                                                                  │
│  Each tenant DB has its own auth_user table                      │
│  → DailyMenu.created_by = FK(User) is same-DB                   │
│  → CustomerProfile.user = OneToOneField(User) is same-DB         │
│  → No cross-database FK hacks needed                             │
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

### Phase 2 — Flutter Admin Dashboard Screens ✅
- **Dashboard overview** — summary metric cards (orders, deliveries, revenue, customers, inventory, staff) with recent orders table
- **Orders screen** — tab-filtered list with status workflow; preparing/ready only on delivery day; cancel support
- **Inventory screen** — CRUD with stock adjustment dialog, low-stock filter, cost/supplier tracking
- **Delivery screen** — tab-filtered list with driver info, status tracking, pickup/delivery times
- **Customers screen** — customer list with search, registration request approval/rejection with reasons
- **Finance screen** — invoice list with status tabs, summary cards (paid/pending/count), detail dialog with Mark paid and line items
- **Staff screen** — CRUD with role assignment (manager/kitchen_staff/driver/staff), deactivation, change-role dialog

#### Backend Addition (Phase 2)
- `GET /api/v1/dashboard/summary/` — aggregated tenant dashboard metrics (orders, customers, revenue, inventory, deliveries, staff)

#### Management Commands
- `python manage.py migrate_all_tenants` — migrate all tenant databases (supports `--parallel`, `--tenant=<slug>`)
- `python manage.py provision_tenant` — full tenant provisioning (DB create, migrate, admin user, plan assignment)
- `python manage.py seed_meal_slots` — seed default meal slots (Lunch, Dinner) for a tenant
- `python manage.py clean_tenant_orders` — delete all orders for `--tenant=<slug>` or `--all`
- `python manage.py clean_tenant_subscriptions` — delete all subscriptions for `--tenant=<slug>` or `--all`
- `python manage.py auto_advance_today_orders` — advance today's orders to ready and create Deliveries; for cron use `--no-input`

### Phase 5 — SaaS Owner Dashboard (Flutter) ✅
- **Overview screen** — platform-wide analytics cards (total/active/trial tenants, MRR, ARR, pending/overdue invoices)
- **Tenants screen** — searchable data table with status badges, suspend/activate actions, create-tenant dialog
- **Tenant detail screen** — subscription info, plan limits, latest usage metrics
- **Plans screen** — card-based grid with pricing, feature limits, create/edit/toggle active
- **SaaS Shell** — dark indigo sidebar, dedicated header, fully responsive with mobile drawer
- **Router integration** — `/saas`, `/saas/tenants`, `/saas/tenants/:id`, `/saas/plans` routes in GoRouter
- **Tenant sidebar** — "Platform Admin" link to switch between tenant admin and SaaS owner dashboards

### Phase 6 — Daily Rotating Menu System ✅

#### Backend Models
| Model | Purpose |
|-------|---------|
| `MealSlot` | Configurable meal time slots (Lunch, Dinner, Breakfast, etc.) with cutoff times and sort order |
| `DailyMenu` | A menu for a specific date + meal slot + diet type (veg/nonveg/both), with status (draft/published/archived) |
| `DailyMenuItem` | Links a `MenuItem` (master item) to a `DailyMenu` with optional price override, portion label, sort order |
| `MealPackage` | Subscription tiers (e.g. Executive, Economy) with tenant-configurable naming, pricing, duration, and meals per day |

#### Backend Endpoints
| Method | Endpoint | Description |
|--------|----------|-------------|
| `CRUD` | `/api/v1/meal-slots/` | Meal slot management |
| `CRUD` | `/api/v1/daily-menus/` | Daily menu management |
| `GET` | `/api/v1/daily-menus/week/?start=YYYY-MM-DD` | Get menus for a 7-day window |
| `POST` | `/api/v1/daily-menus/{id}/publish/` | Publish a draft menu |
| `POST` | `/api/v1/daily-menus/{id}/archive/` | Archive a menu |
| `CRUD` | `/api/v1/meal-packages/` | Meal package management |

#### Menu Item Enhancements
- `diet_type` field on `MenuItem` — veg / nonveg / both
- Inline category creation from the "Add Menu Item" dialog
- Calories made optional (not mandatory)

#### Flutter UI
- Weekly calendar view with meal slot columns
- Create/edit daily menu dialog with item selection
- Publish/archive actions on menus
- Meal package management tab
- Inline "Add Category" dialog when creating menu items

### Phase 7 — Customer Management System ✅

#### Backend Changes
| Feature | Description |
|---------|-------------|
| `CustomerProfileCreateSerializer` | Admin directly creates User + CustomerProfile + Address in tenant DB |
| Registration approval creates accounts | `POST /approve/` now creates User + CustomerProfile (was status-only before) |
| `AddressAdminViewSet` | Admin CRUD for customer addresses at `/api/v1/customer-addresses/` |
| `AddressAdminSerializer` / `AddressCreateSerializer` | Serializers for structured address management |
| Structured address fields | `building_name`, `floor_number`, `flat_number`, `street`, `city` (replaces single text blob) |
| Admin-created addresses auto-approved | Status set to `active` automatically |

#### Flutter UI
- **Master-detail layout** — customer list on left, detail panel on right (wide screens)
- **Add Customer dialog** — form with Personal Information (name, phone, email, Emirates ID, preferred contact) and Delivery Address (building, floor, flat, street, city, zone)
- **Customer detail panel** — Contact, Identity & Location, Delivery Addresses (with Default/Active badges), Account info (wallet, loyalty, tier)
- **Registration request management** — approve creates account, reject with reason
- **Search** — by name, email, phone across customer list

### Phase 8 — Multi-Tenant Database Router Overhaul ✅

#### Architecture Changes
| Change | Description |
|--------|-------------|
| `TenantRouter` redesigned | `SAAS_ONLY_APPS` (organizations, users, admin, sites, axes) → always `default`. All other apps (including `auth`, `contenttypes`, `sessions`) → follow tenant context |
| `auth.User` per tenant | Each tenant DB has its own `auth_user` table. Tenant staff and customers are created in the tenant DB |
| No cross-DB FK hacks | `DailyMenu.created_by = FK(User)` and `CustomerProfile.user = OneToOneField(User)` are same-database references |
| SaaS superusers isolated | SaaS-level superusers live in `default` DB only, used through Django admin |
| `provision_tenant` updated | Admin users now created in tenant DB using thread-local routing context |
| `setup_tenant_defaults` signal | Creates `kitchen_admin` user and default category in tenant DB |

### Recent Additions (Operational & Finance)

| Area | Change |
|------|--------|
| **Order status** | Transition to Preparing or Ready allowed only when `delivery_date` is today; otherwise API returns 400 with a clear message. |
| **Delivery auto-creation** | When an order is marked Ready, a `Delivery` record is auto-created so it appears in Delivery Management. |
| **Subscription activate** | On activate: orders are auto-generated for all delivery dates in range; an Invoice is created (cash/card → paid, wallet → pending). Due date = start_date + 7 days. |
| **Subscription create/update** | When saving with status `active`, `update_delivery_schedule()` and `generate_orders()` are called. Meal package FK is set on create/update. |
| **Invoice** | `invoice_number` optional (auto-generated INV-YYYYMM-0001 if blank). `GET /api/v1/invoices/summary/` (paid_total, pending_total, total_count, overdue_count). `POST /api/v1/invoices/{id}/mark_paid/`. |
| **Management commands** | `clean_tenant_orders`, `clean_tenant_subscriptions`, `auto_advance_today_orders` (for cron) in `apps/main/management/commands/`. |
| **Flutter** | Orders: preparing/ready only on delivery day + hint; Finance: summary cards + Mark paid in invoice detail. |

---

## Files Created / Modified

### New Files
| File | Purpose |
|------|---------|
| `core/permissions/plan_limits.py` | Plan-based permission classes |
| `apps/main/serializers/__init__.py` | Serializer package init |
| `apps/main/serializers/admin_serializers.py` | Tenant-admin serializers (orders, customers, addresses, menus, packages) |
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
| `apps/organizations/management/commands/provision_tenant.py` | Full tenant provisioning command |
| `apps/organizations/management/commands/migrate_all_tenants.py` | Migrate all tenant databases |
| `apps/main/management/commands/seed_meal_slots.py` | Seed meal slots for a tenant |
| `apps/main/management/commands/clean_tenant_orders.py` | Delete all orders for tenant(s) |
| `apps/main/management/commands/clean_tenant_subscriptions.py` | Delete all subscriptions for tenant(s) |
| `apps/main/management/commands/auto_advance_today_orders.py` | Advance today's orders to ready and create Delivery records |

### Modified Files
| File | Change |
|------|--------|
| `apps/main/models.py` | FK → IntegerField for tenant refs; MealSlot, DailyMenu, DailyMenuItem, MealPackage models; diet_type field; calories optional |
| `apps/main/admin.py` | Updated admin for new models |
| `apps/main/urls_api.py` | Registered meal-slots, daily-menus, meal-packages, customer-addresses |
| `apps/main/views/__init__.py` | Added new view exports |
| `apps/organizations/models.py` | Expanded ServicePlan |
| `core/db/router.py` | Complete TenantRouter redesign — SAAS_ONLY_APPS + tenant-context routing |
| `core/middleware/multi_db_tenant.py` | Attaches `request.tenant_plan`, dynamic DB registration |
| `apps/users/signals.py` | setup_tenant_defaults uses thread-local routing |
| `scripts/provision_tenant.py` | Updated for new router context |

---

## Remaining Work (Future Phases)

### Phase 4 — Flutter Customer App
- Customer registration / login
- Menu browsing (daily menus, packages)
- Subscription management
- Order tracking
- Wallet / payments
- Push notifications

### Phase 9 — Production Hardening
- Celery tasks for usage collection
- Payment gateway integration (Stripe / PayTabs)
- Email / WhatsApp notification service
- Rate limiting per plan tier
- Comprehensive test suite

### Phase 10 — Advanced Features
- Multi-branch support per tenant
- Customer loyalty program automation
- Analytics dashboard per tenant
- Bulk operations (menu copy, customer import)
- Delivery route optimization

### Phase 11 — Accounting-Style Entries (Double-Entry Bookkeeping) — Future
Professional accounting-style ledger so tenant cash, customer wallet, and revenue are tracked with balanced debits/credits.

**Target flow (conceptual):**
1. **Customer pays (cash/card) at signup** → Tenant credit (revenue/cash received).
2. **Tenant transfers amount into customer wallet** → Tenant debit, Wallet credit (liability to customer increases).
3. **Daily delivery done / auto-invoice** → Wallet debit (customer balance used), Tenant credit (revenue recognized for that delivery).

**Implementation outline:**
- **Models:** `JournalEntry` (date, reference_type, reference_id, memo) and `JournalLine` (entry, account, amount, debit_credit `dr`/`cr`). Optional: `Account` or fixed account codes (e.g. Tenant Cash, Tenant Revenue, Customer Wallet liability, Unearned revenue).
- **Rules:** Every transaction posts balanced entries (sum of dr = sum of cr). Hook into: subscription activate + payment (cash/card), wallet top-up, “transfer to wallet”, delivery completed / invoice generated.
- **Revenue recognition:** Decide policy (e.g. recognize at payment vs at delivery); may use Unearned revenue until delivery.
- **Integration:** Reuse existing `Invoice`, `WalletTransaction`; journal entries can reference them for audit trail.

**Phased approach:**
- **Phase 11a:** Simple payment/event log (who paid what, when, method, linked subscription/invoice) for reporting; no full double-entry.
- **Phase 11b:** Full double-entry ledger with chart of accounts, journal entries on payment, wallet transfer, and delivery; basic trial balance / reports.
