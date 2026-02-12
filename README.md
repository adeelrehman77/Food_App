# Fun Adventure Kitchen

A multi-tenant food delivery and kitchen management SaaS platform. The system supports subscription-based meal delivery with daily rotating menus, kitchen operations (KDS), driver fleet management, inventory tracking, customer management, and full admin dashboards — all with per-tenant database isolation.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Backend](#backend)
  - [Django Apps](#django-apps)
  - [API Endpoints](#api-endpoints)
  - [Authentication](#authentication)
  - [Multi-Tenancy](#multi-tenancy)
  - [Management Commands](#management-commands)
  - [Backend Setup](#backend-setup)
- [Frontend (Flutter)](#frontend-flutter)
  - [Layer 1 — SaaS Owner Dashboard](#layer-1--saas-owner-dashboard)
  - [Layer 2 — Tenant Admin Dashboard](#layer-2--tenant-admin-dashboard)
  - [Layer 3 — Customer App (Planned)](#layer-3--customer-app-planned)
  - [App Architecture](#app-architecture)
  - [Frontend Setup](#frontend-setup)
- [Docker Deployment](#docker-deployment)
- [Environment Variables](#environment-variables)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

---

## Architecture Overview

### 3-Layer SaaS Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    LAYER 1: SaaS Owner (Platform Admin)             │
│  /api/saas/* — Superuser only                                       │
│  Tenant provisioning, Plan management, Billing, Platform analytics  │
├─────────────────────────────────────────────────────────────────────┤
│                    LAYER 2: Tenant Admin (Kitchen Staff)             │
│  /api/v1/*  — Staff JWT + X-Tenant-Slug header                      │
│  Menu, Daily Menus, Meal Packages, Orders, Kitchen KDS, Inventory,  │
│  Delivery, Staff, Customers, Addresses, Finance                     │
├─────────────────────────────────────────────────────────────────────┤
│                    LAYER 3: B2C Customer                             │
│  /api/v1/customer/* — Customer JWT                                   │
│  Register, Login, Menu browse, Subscriptions, Orders, Wallet        │
└─────────────────────────────────────────────────────────────────────┘
```

### Infrastructure

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Nginx Reverse Proxy                         │
│                     (SSL termination, static)                      │
└─────────────┬──────────────────────────────────────┬────────────────┘
              │                                      │
              ▼                                      ▼
┌──────────────────────────┐     ┌────────────────────────────────────┐
│    Flutter Admin App     │     │     Django REST API (Gunicorn)     │
│   (Web / macOS / iOS)    │────▶│   /api/v1/, /api/saas/,            │
│                          │     │   /api/v1/customer/                │
│  • SaaS Admin (L1)       │     │                                    │
│  • Tenant Dashboard (L2) │     │  ┌──────────┐  ┌───────────────┐  │
│  • Customer App (L3)     │     │  │  Celery   │  │ Celery Beat   │  │
│                          │     │  │  Worker   │  │ (Scheduler)   │  │
└──────────────────────────┘     │  └─────┬────┘  └───────┬───────┘  │
                                 └────────┼───────────────┼──────────┘
                                          │               │
                                 ┌────────▼───────────────▼──────────┐
                                 │        Redis 7 (Cache/Queue)      │
                                 └───────────────────────────────────┘
                                 ┌───────────────────────────────────┐
                                 │    PostgreSQL 15 (Multi-tenant)   │
                                 │    ┌──────┐ ┌──────┐ ┌──────┐    │
                                 │    │shared│ │ t_1  │ │ t_2  │    │
                                 │    │  db  │ │  db  │ │  db  │    │
                                 │    └──────┘ └──────┘ └──────┘    │
                                 └───────────────────────────────────┘
```

### Multi-Tenant Database Isolation

```
TenantRouter
├── SAAS_ONLY_APPS → always route to 'default' DB
│   organizations, users, admin, sites, axes, django_apscheduler
│
└── ALL OTHER APPS → follow tenant context (thread-local DB alias)
    auth, contenttypes, sessions, main, kitchen, delivery,
    driver, inventory, account, authtoken

Each tenant DB contains:
  • auth_user (staff + customer users)
  • main models (menus, orders, customers, addresses, wallet)
  • kitchen, delivery, driver, inventory models
  → No cross-database foreign keys
  → Full data isolation per tenant
```

---

## Tech Stack

| Layer        | Technology                                                                  |
|--------------|-----------------------------------------------------------------------------|
| **Backend**  | Python 3.11+, Django 4.2+, Django REST Framework, Celery, Django Channels   |
| **Frontend** | Flutter (Dart 3.10+), Provider, GoRouter, Dio, Material Design 3            |
| **Database** | PostgreSQL 15+ (per-tenant database isolation)                              |
| **Cache**    | Redis 7+ (sessions, caching, Celery broker, Channels layer)               |
| **Auth**     | JWT (SimpleJWT), API Keys, Session-based, django-axes brute-force protection|
| **DevOps**   | Docker, Docker Compose, Nginx, Gunicorn, WhiteNoise                         |
| **Docs**     | Swagger / OpenAPI (drf-yasg), ReDoc                                         |

---

## Project Structure

```
Food_App/
├── clean_backend/                 # Django REST API
│   ├── apps/
│   │   ├── main/                  # Core domain (menu, daily menus, meal packages,
│   │   │                          #   orders, subscriptions, customers, wallet,
│   │   │                          #   invoicing, addresses, staff management);
│   │   │                          #   management/commands: seed_meal_slots,
│   │   │                          #   clean_tenant_orders, clean_tenant_subscriptions,
│   │   │                          #   auto_advance_today_orders
│   │   ├── users/                 # Tenant model, domain mapping, user profiles,
│   │   │                          #   tenant discovery, setup_tenant_defaults signal
│   │   ├── organizations/         # Service plans, SaaS models (subscriptions,
│   │   │                          #   invoices, usage), management commands
│   │   ├── kitchen/               # Kitchen Display System (KDS)
│   │   ├── delivery/              # Delivery logistics
│   │   ├── driver/                # Driver fleet management
│   │   └── inventory/             # Stock & ingredient tracking
│   ├── config/
│   │   ├── settings/              # base.py, development.py, production.py, test.py
│   │   ├── urls.py                # Root URL config
│   │   ├── wsgi.py / asgi.py
│   │   └── url_patterns/
│   ├── core/
│   │   ├── middleware/            # Security, tenant routing, performance monitoring
│   │   ├── permissions/           # Custom DRF permissions + plan-based limits
│   │   ├── db/                    # Multi-database TenantRouter
│   │   └── utils/                 # Validators and helpers
│   ├── scripts/                   # Provisioning, migration, API key scripts
│   ├── templates/                 # HTML templates
│   ├── requirements/              # Python dependencies (base, dev, prod)
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── .env.example               # Environment variable reference
│   └── manage.py
│
├── flutter_app/                   # Flutter Multi-Dashboard Application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/            # AppConfig (environment URLs)
│   │   │   ├── network/           # ApiClient (Dio + interceptors), TenantService
│   │   │   ├── providers/         # AuthProvider, TenantProvider
│   │   │   ├── router/            # GoRouter with auth guards
│   │   │   └── theme/             # Material 3 theming
│   │   ├── features/
│   │   │   ├── auth/              # Login screens, AuthService
│   │   │   ├── dashboard/         # Tenant admin shell layout
│   │   │   ├── admin/             # Tenant admin screens (all L2 features)
│   │   │   ├── menu/              # Menu CRUD (model, repository, screens)
│   │   │   └── saas_admin/        # SaaS owner dashboard (L1 features)
│   │   └── main.dart              # App entry point
│   └── pubspec.yaml
│
├── PLAN.md                        # Implementation plan and progress tracker
└── README.md                      # ← You are here
```

---

## Backend

### Django Apps

| App | Layer | Purpose |
|-----|-------|---------|
| `main` | L2 + L3 | Menu items, daily rotating menus, meal slots, meal packages, orders, subscriptions, customers, customer registration requests, wallet, invoicing, addresses, staff management, customer-facing APIs |
| `users` | Shared | Tenant model, domain mapping, user profiles, tenant discovery, `setup_tenant_defaults` signal |
| `organizations` | L1 | Service plans, tenant subscriptions, tenant invoices, usage tracking, SaaS analytics, provisioning management commands |
| `kitchen` | L2 | Kitchen Display System (KDS) — order queue, claim, preparation tracking |
| `delivery` | L2 | Delivery logistics and tracking |
| `driver` | L2 | Zones, routes, schedules, driver profiles, delivery assignments, driver-facing APIs |
| `inventory` | L2 | Inventory items, units of measure, stock tracking, low-stock alerts |

### API Endpoints

The API is organized into three layers matching the SaaS architecture:

#### Layer 1 — SaaS Owner (`/api/saas/`) — Superuser only

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/saas/analytics/` | Platform-wide metrics (MRR, tenant count) |
| `GET/POST` | `/api/saas/tenants/` | List / provision tenants |
| `GET/PATCH` | `/api/saas/tenants/{id}/` | Tenant detail / update |
| `GET` | `/api/saas/tenants/{id}/usage/` | Tenant usage metrics |
| `POST` | `/api/saas/tenants/{id}/suspend/` | Suspend tenant |
| `POST` | `/api/saas/tenants/{id}/activate/` | Activate tenant |
| `CRUD` | `/api/saas/plans/` | Service plan management |
| `CRUD` | `/api/saas/subscriptions/` | Tenant subscription management |
| `CRUD` | `/api/saas/invoices/` | Tenant invoice management |
| `POST` | `/api/saas/invoices/{id}/mark_paid/` | Mark invoice as paid |

#### Layer 2 — Tenant Admin (`/api/v1/`) — Staff JWT + X-Tenant-Slug

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/discover/` | Discover tenant by kitchen code |
| `GET` | `/api/v1/health/` | Health check |
| **Menu & Categories** | | |
| `CRUD` | `/api/v1/menu-items/` | Menu item management (with diet_type, optional calories) |
| `POST` | `/api/v1/menu-items/{id}/toggle_availability/` | Toggle availability |
| `CRUD` | `/api/v1/categories/` | Category management (inline creation supported) |
| **Daily Rotating Menus** | | |
| `CRUD` | `/api/v1/meal-slots/` | Meal slot management (Breakfast, Lunch, Dinner, etc.) |
| `CRUD` | `/api/v1/daily-menus/` | Daily menu management |
| `GET` | `/api/v1/daily-menus/week/?start=YYYY-MM-DD` | Get menus for a 7-day window |
| `POST` | `/api/v1/daily-menus/{id}/publish/` | Publish a draft menu |
| `POST` | `/api/v1/daily-menus/{id}/archive/` | Archive a menu |
| `CRUD` | `/api/v1/meal-packages/` | Meal package management (subscription tiers) |
| **Orders** | | |
| `CRUD` | `/api/v1/orders/` | Order management (filter by status) |
| `POST` | `/api/v1/orders/{id}/update_status/` | Update order status (preparing/ready only when delivery_date is today) |
| **Kitchen KDS** | | |
| `CRUD` | `/api/v1/kitchen/orders/` | Kitchen order queue |
| `POST` | `/api/v1/kitchen/orders/{id}/claim/` | Claim an order |
| `POST` | `/api/v1/kitchen/orders/{id}/start_preparation/` | Start cooking |
| `POST` | `/api/v1/kitchen/orders/{id}/mark_ready/` | Mark ready |
| **Subscriptions (Admin)** | | |
| `CRUD` | `/api/v1/subscriptions-admin/` | Subscription CRUD (creates orders on activate) |
| `POST` | `/api/v1/subscriptions-admin/{id}/activate/` | Activate subscription (auto-generates orders + invoice; cash/card → invoice paid) |
| `POST` | `/api/v1/subscriptions-admin/{id}/generate_orders/` | Generate orders for remaining delivery dates |
| **Delivery Management** | | |
| `CRUD` | `/api/v1/delivery/deliveries/` | Delivery tracking (Delivery auto-created when order becomes ready) |
| `CRUD` | `/api/v1/driver/zones/` | Delivery zones |
| `CRUD` | `/api/v1/driver/routes/` | Delivery routes |
| `CRUD` | `/api/v1/driver/drivers/` | Driver management |
| `CRUD` | `/api/v1/driver/schedules/` | Delivery schedules |
| `CRUD` | `/api/v1/driver/assignments/` | Delivery assignments |
| `GET` | `/api/v1/driver/deliveries/` | Driver's deliveries |
| `POST` | `/api/v1/driver/deliveries/{id}/update_status/` | Driver status update |
| `POST` | `/api/v1/driver/deliveries/{id}/add_note/` | Driver delivery note |
| **Inventory** | | |
| `CRUD` | `/api/v1/inventory/items/` | Inventory items |
| `POST` | `/api/v1/inventory/items/{id}/adjust_stock/` | Adjust stock |
| `GET` | `/api/v1/inventory/items/low_stock/` | Low stock alerts |
| `CRUD` | `/api/v1/inventory/units/` | Units of measure |
| **Customer Management** | | |
| `CRUD` | `/api/v1/customers/` | Customer profiles (admin can create User + Profile + Address) |
| `CRUD` | `/api/v1/registration-requests/` | Registration requests |
| `POST` | `/api/v1/registration-requests/{id}/approve/` | Approve (creates User + CustomerProfile) |
| `POST` | `/api/v1/registration-requests/{id}/reject/` | Reject request |
| `CRUD` | `/api/v1/customer-addresses/` | Admin address management (with approve/reject) |
| **Staff Management** | | |
| `CRUD` | `/api/v1/staff/` | Staff user management |
| `POST` | `/api/v1/staff/{id}/deactivate/` | Deactivate staff |
| `POST` | `/api/v1/staff/{id}/change_role/` | Change staff role |
| **Finance & Misc** | | |
| `GET` | `/api/v1/invoices/` | Invoice list (filter by status) |
| `GET` | `/api/v1/invoices/summary/` | Finance summary (paid_total, pending_total, total_count, overdue_count) |
| `POST` | `/api/v1/invoices/{id}/mark_paid/` | Mark invoice as paid |
| `GET` | `/api/v1/notifications/` | Notification management |
| `GET` | `/api/v1/subscriptions/` | Subscription list (read-only) |
| `GET` | `/api/v1/wallet/` | Wallet transactions |
| `GET` | `/api/v1/addresses/` | Address management |
| `GET` | `/api/v1/dashboard/summary/` | Aggregated dashboard metrics |

#### Layer 3 — B2C Customer (`/api/v1/customer/`) — Customer JWT

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/api/v1/customer/auth/register/` | None | Customer registration |
| `POST` | `/api/v1/customer/auth/login/` | None | Customer login (JWT) |
| `GET` | `/api/v1/customer/menu/` | None | Browse menu items |
| `GET` | `/api/v1/customer/menu/categories/` | None | List categories |
| `GET/PUT` | `/api/v1/customer/profile/` | JWT | View/update profile |
| `GET/POST` | `/api/v1/customer/subscriptions/` | JWT | Manage subscriptions |
| `GET` | `/api/v1/customer/orders/` | JWT | Order history |
| `GET` | `/api/v1/customer/orders/{id}/track/` | JWT | Delivery tracking |
| `GET` | `/api/v1/customer/wallet/` | JWT | Balance + transactions |
| `POST` | `/api/v1/customer/wallet/topup/` | JWT | Add funds to wallet |
| `GET` | `/api/v1/customer/invoices/` | JWT | View invoices |
| `GET` | `/api/v1/customer/notifications/` | JWT | List notifications |
| `POST` | `/api/v1/customer/notifications/{id}/mark_read/` | JWT | Mark notification read |
| `POST` | `/api/v1/customer/notifications/mark_all_read/` | JWT | Mark all read |
| `CRUD` | `/api/v1/customer/addresses/` | JWT | Delivery addresses |

#### Staff Authentication (via dj-rest-auth)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/v1/auth/login/` | Obtain JWT tokens |
| `POST` | `/api/v1/auth/logout/` | Invalidate session |
| `POST` | `/api/v1/auth/token/refresh/` | Refresh access token |
| `POST` | `/api/v1/auth/registration/` | Register new staff user |
| `POST` | `/api/v1/auth/password/reset/` | Request password reset |

#### Documentation

| URL | Description |
|-----|-------------|
| `/swagger/` | Swagger UI |
| `/redoc/` | ReDoc |
| `/admin/` | Django Admin Interface |

### Authentication

The backend supports three authentication methods:

1. **JWT (primary)** — `Authorization: Bearer <token>`. Access tokens expire in 60 minutes; refresh tokens in 24 hours. Token rotation is enabled.
2. **API Keys** — `X-Api-Key: <key>` header. Used for service-to-service calls. Keys have configurable expiry (default 90 days).
3. **Session** — Standard Django sessions (cache-backed in production, 30-minute timeout).

Brute-force protection is provided by `django-axes` (5 failures = 1 hour lockout).

### Multi-Tenancy

The platform uses a **multi-database** isolation strategy with per-tenant databases:

1. **Shared database** (`default`) stores `Tenant`, `Domain`, `UserProfile`, `ServicePlan`, `TenantSubscription`, `TenantInvoice`, and `TenantUsage` models.
2. **Tenant databases** (e.g., `tenant_acme`, `tenant_golden_kitchen`) store all domain-specific data including:
   - `auth.User` — tenant staff and customers (each tenant has its own user table)
   - Menu items, daily menus, meal slots, meal packages, categories
   - Orders, subscriptions, wallet transactions, invoices
   - Customer profiles, registration requests, addresses
   - Kitchen orders, delivery assignments, inventory items
3. The `MultiDbTenantMiddleware` reads the `X-Tenant-Slug` header to resolve the current tenant, dynamically registers the tenant database, and sets the thread-local database alias.
4. `TenantRouter` in `core/db/router.py` routes ORM queries:
   - **SAAS_ONLY_APPS** (`organizations`, `users`, `admin`, `sites`, `axes`, `django_apscheduler`) → always `default` database
   - **All other apps** (including `auth`, `contenttypes`, `sessions`, `main`, `kitchen`, etc.) → current tenant database

New tenants are provisioned with `python manage.py provision_tenant`, which creates the database, runs migrations, creates admin users, and sets up default data.

### Management Commands

| Command | Description |
|---------|-------------|
| `python manage.py provision_tenant` | Full tenant provisioning (creates DB, runs migrations, creates admin user, assigns plan) |
| `python manage.py migrate_all_tenants` | Migrate all tenant databases. Supports `--parallel` and `--tenant=<slug>` |
| `python manage.py seed_meal_slots` | Seed default meal slots (Lunch, Dinner) for a tenant (run with tenant context or pass DB) |
| `python manage.py clean_tenant_orders` | Delete all orders (and related Delivery/KitchenOrder) for `--tenant=<slug>` or `--all` |
| `python manage.py clean_tenant_subscriptions` | Delete all subscriptions (and related orders, delivery statuses) for `--tenant=<slug>` or `--all` |
| `python manage.py auto_advance_today_orders` | Advance today's orders to ready and create Delivery records for `--tenant=<slug>` or `--all` (for cron) |
| `python manage.py createsuperuser` | Create SaaS-level superuser in default DB |

### Backend Setup

#### Prerequisites

- Python 3.11+
- PostgreSQL 15+
- Redis 7+ (optional in development)

#### Quick Start

```bash
cd clean_backend

# Create and activate virtual environment
python -m venv venv
source venv/bin/activate    # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements/requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your values (DB_NAME, DB_USER, DB_PASSWORD, DB_HOST, DJANGO_SECRET_KEY)

# Run migrations (shared/default database)
python manage.py migrate

# Create SaaS superuser
python manage.py createsuperuser

# Provision a tenant (creates tenant DB, runs migrations, creates admin user)
python manage.py provision_tenant

# Start development server
python manage.py runserver
```

The API is now available at `http://localhost:8000/api/v1/` and docs at `http://localhost:8000/swagger/`.

---

## Frontend (Flutter)

The Flutter application serves as a multi-role dashboard targeting **web** and **macOS** (extensible to iOS/Android). It connects to the Django backend via the REST API and supports all three SaaS layers.

### Layer 1 — SaaS Owner Dashboard

| Feature                | Status    | Description                                                |
|------------------------|-----------|------------------------------------------------------------|
| Platform Analytics     | Complete  | MRR, ARR, tenant counts, invoice summaries                 |
| Tenant Management      | Complete  | Searchable list, create, suspend/activate, detail view     |
| Plan Management        | Complete  | Card grid with pricing, features, limits, create/edit      |
| SaaS Shell             | Complete  | Dark indigo sidebar, responsive with mobile drawer         |
| Router Integration     | Complete  | `/saas`, `/saas/tenants`, `/saas/tenants/:id`, `/saas/plans` |

### Layer 2 — Tenant Admin Dashboard

| Feature                | Status    | Description                                                |
|------------------------|-----------|------------------------------------------------------------|
| Tenant Discovery       | Complete  | Connect to a kitchen by entering its code/slug             |
| JWT Authentication     | Complete  | Two-step login flow with secure token storage              |
| Auth State Management  | Complete  | Persistent session with automatic route guards             |
| Token Refresh          | Complete  | Automatic 401 retry with refreshed access token            |
| Dashboard Overview     | Complete  | Metric cards (orders, deliveries, revenue, customers, etc.) |
| Menu Management        | Complete  | List, add, edit, toggle availability with diet type filter |
| Category Management    | Complete  | CRUD with inline creation from menu item dialog            |
| Daily Rotating Menus   | Complete  | Weekly calendar view, create/publish/archive daily menus   |
| Meal Packages          | Complete  | Subscription tiers with configurable naming and pricing    |
| Orders                 | Complete  | Tab-filtered list with status workflow; preparing/ready only on delivery day; cancel support |
| Inventory              | Complete  | CRUD with stock adjustment, low-stock filter               |
| Delivery               | Complete  | Tab-filtered list with driver info, status tracking        |
| Customer Management    | Complete  | Master-detail layout, add customer (User+Profile+Address), search |
| Registration Requests  | Complete  | Approve (creates account) / reject with reason             |
| Address Management     | Complete  | Structured fields (building, floor, flat, street, city)    |
| Finance                | Complete  | Invoice list with status tabs, summary cards (paid/pending/count), detail dialog with Mark paid |
| Staff Management       | Complete  | CRUD with role assignment, deactivation, change-role       |
| Dynamic Tenant Info    | Complete  | Header displays real tenant name and user info             |
| Logout                 | Complete  | Available in sidebar and header profile menu               |

### Layer 3 — Customer App (Planned)

| Feature                | Status    | Description                                                |
|------------------------|-----------|------------------------------------------------------------|
| Registration / Login   | Planned   | Customer JWT authentication                                |
| Menu Browsing          | Planned   | Browse daily menus and meal packages                       |
| Subscription Mgmt      | Planned   | Subscribe to meal plans                                    |
| Order Tracking         | Planned   | Real-time delivery tracking                                |
| Wallet / Payments      | Planned   | Fund wallet, pay for meals                                 |
| Push Notifications     | Planned   | Order updates, menu announcements                          |

### App Architecture

```
lib/
├── core/                          # Shared infrastructure
│   ├── config/
│   │   └── app_config.dart        # Environment URLs (dev / prod)
│   ├── network/
│   │   ├── api_client.dart        # Singleton Dio client with auth interceptors
│   │   └── tenant_service.dart    # Tenant discovery API calls
│   ├── providers/
│   │   ├── auth_provider.dart     # Auth state (ChangeNotifier)
│   │   └── tenant_provider.dart   # Tenant state (ChangeNotifier)
│   ├── router/
│   │   └── app_router.dart        # GoRouter with redirect-based auth guards
│   └── theme/
│       └── app_theme.dart         # Material 3 light/dark themes
│
├── features/                      # Feature modules
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_service.dart  # Login/logout API calls
│   │   └── presentation/
│   │       ├── tenant_login_screen.dart  # Two-step login (slug → credentials)
│   │       └── user_login_screen.dart    # Direct staff login
│   ├── dashboard/
│   │   └── presentation/
│   │       ├── dashboard_shell.dart      # Tenant admin layout wrapper
│   │       └── widgets/
│   │           ├── header.dart           # Top bar with tenant info, search, profile
│   │           └── sidebar.dart          # Navigation menu with logout
│   ├── admin/                           # Tenant admin features (Layer 2)
│   │   ├── data/
│   │   │   └── admin_repository.dart    # All /api/v1/ tenant admin endpoints
│   │   ├── domain/
│   │   │   └── models.dart              # DashboardSummary, OrderItem, CustomerItem,
│   │   │                                # InvoiceItem, InventoryItemModel, DeliveryItem,
│   │   │                                # StaffUser, DailyMenu, MealSlot, MealPackage,
│   │   │                                # CustomerAddress
│   │   └── presentation/
│   │       ├── dashboard_screen.dart    # Dashboard overview with metric cards
│   │       ├── orders_screen.dart       # Orders management with status workflow
│   │       ├── inventory_screen.dart    # Inventory management with stock adjustment
│   │       ├── delivery_screen.dart     # Delivery tracking with status filters
│   │       ├── customers_screen.dart    # Customer management (master-detail layout)
│   │       ├── finance_screen.dart      # Invoice listing with detail dialog
│   │       └── staff_screen.dart        # Staff CRUD with role management
│   ├── menu/
│   │   ├── data/
│   │   │   └── menu_repository.dart     # API calls for menu CRUD
│   │   ├── domain/
│   │   │   └── food_item.dart           # FoodItem model with JSON serialization
│   │   └── presentation/
│   │       ├── menu_screen.dart         # Grid view + daily menus + meal packages
│   │       └── widgets/
│   │           ├── food_item_card.dart   # Item display card
│   │           └── add_item_modal.dart   # Add/edit dialog (with inline category creation)
│   └── saas_admin/                      # SaaS owner features (Layer 1)
│       ├── data/
│       │   └── saas_repository.dart     # All /api/saas/ endpoints
│       ├── domain/
│       │   └── models.dart              # ServicePlan, Tenant, TenantDetail,
│       │                                # Subscription, Usage, Analytics
│       └── presentation/
│           ├── saas_shell.dart          # SaaS dashboard layout shell
│           ├── saas_overview_screen.dart # Analytics overview (home)
│           ├── tenants_screen.dart       # Tenant management list
│           ├── tenant_detail_screen.dart # Tenant detail view
│           ├── plans_screen.dart         # Service plan management
│           └── widgets/
│               ├── saas_sidebar.dart     # Dark sidebar navigation
│               └── saas_header.dart      # SaaS header bar
│
└── main.dart                      # Entry point, provider setup, session restore
```

**Key Design Decisions:**

- **State Management:** Provider (ChangeNotifier pattern) for simplicity and testability.
- **Routing:** GoRouter with `redirect` function that reads `AuthProvider.isLoggedIn` — unauthenticated users are sent to `/login`, authenticated users on `/login` are sent to `/dashboard`.
- **API Client:** Singleton `ApiClient` wrapping Dio with interceptors for automatic auth header injection, tenant header injection, and transparent token refresh on 401.
- **Environment Config:** `AppConfig` class with `development` and `production` presets. Switch by changing `AppConfig.current` in `main.dart`.
- **Master-Detail Pattern:** Customer management uses a responsive master-detail layout — list on the left, detail panel on the right for wide screens.

### Frontend Setup

#### Prerequisites

- Flutter SDK 3.10+
- Dart SDK 3.10+

#### Quick Start

```bash
cd flutter_app

# Install dependencies
flutter pub get

# Run on web (Chrome)
flutter run -d chrome

# Run on macOS
flutter run -d macos
```

#### Switching Environments

Edit `lib/core/config/app_config.dart`:

```dart
// For local development (default)
static AppConfig current = development;

// For production
static AppConfig current = production;
```

---

## Docker Deployment

The backend includes a full Docker Compose setup with PostgreSQL, Redis, Django, Celery, and Nginx.

```bash
cd clean_backend

# 1. Configure environment
cp .env.example .env
# Edit .env — set DB_PASSWORD, DJANGO_SECRET_KEY, SYNC_TOKEN, ENCRYPTION_KEY

# 2. Build and start all services
docker-compose up --build -d

# 3. Run migrations
docker-compose exec web python manage.py migrate

# 4. Create admin user
docker-compose exec web python manage.py createsuperuser

# 5. Provision a tenant
docker-compose exec web python manage.py provision_tenant

# 6. Collect static files
docker-compose exec web python manage.py collectstatic --noinput
```

Services and ports:

| Service      | Port  | Description                      |
|--------------|-------|----------------------------------|
| `db`         | 5432  | PostgreSQL database              |
| `redis`      | 6379  | Redis cache and message broker   |
| `web`        | 8000  | Django application (Gunicorn)    |
| `celery`     | —     | Background task worker           |
| `celery-beat`| —     | Periodic task scheduler          |
| `nginx`      | 80/443| Reverse proxy with SSL           |

---

## Environment Variables

All configuration is managed through environment variables. See `clean_backend/.env.example` for the full reference.

| Variable                         | Required | Default                  | Description                              |
|----------------------------------|----------|--------------------------|------------------------------------------|
| `DJANGO_ENV`                     | No       | `development`            | `development` or `production`            |
| `DJANGO_SECRET_KEY`              | Prod     | Auto-generated in dev    | Django secret key                        |
| `DATABASE_URL`                   | Prod     | —                        | PostgreSQL connection string             |
| `DB_NAME` / `DB_USER` / `DB_PASSWORD` / `DB_HOST` | Alt | —           | Alternative to `DATABASE_URL`            |
| `REDIS_URL`                      | Prod     | In-memory cache in dev   | Redis connection string                  |
| `SYNC_TOKEN`                     | Prod     | Dev token in debug       | Security token for sync operations       |
| `ENCRYPTION_KEY`                 | No       | Auto-generated           | Fernet key for field encryption          |
| `ALLOWED_HOSTS`                  | Prod     | `*` in dev               | Comma-separated allowed hosts            |
| `CORS_ALLOWED_ORIGINS`           | Prod     | All in dev               | Comma-separated allowed CORS origins     |
| `DEFAULT_TENANT_ADMIN_PASSWORD`  | No       | Random 24-char string    | Password for auto-created tenant admins  |
| `EMAIL_HOST` / `EMAIL_PORT` / etc. | Prod  | Console backend in dev   | SMTP configuration                       |
| `WHATSAPP_PHONE_ID` / `WHATSAPP_TOKEN` | No | Empty                  | WhatsApp Business API credentials        |

---

## Security

### Backend Security Layers

- **HTTPS enforcement** in production (HSTS, secure cookies, SSL redirect)
- **CORS** restricted to allowed origins in production, open only in development
- **CSRF protection** with trusted origins
- **Content Security Policy (CSP)** headers via `django-csp`
- **Brute-force protection** via `django-axes` (5 failures = 1 hour lockout)
- **Rate limiting** (anonymous: 100/hr, authenticated: 1000/hr; stricter in production)
- **Input sanitization** middleware (XSS prevention)
- **Password validators** (similarity, minimum length, common passwords, numeric-only)
- **Query optimization** middleware with N+1 detection
- **Performance monitoring** middleware (request time, query count, memory usage)
- **Plan-based permissions** — PlanLimitMenuItems, PlanLimitStaffUsers, PlanLimitCustomers enforce subscription limits

### Frontend Security

- JWT tokens stored in `FlutterSecureStorage` (Keychain on iOS/macOS, Keystore on Android, encrypted on web)
- Automatic token refresh on 401 with request retry
- Route guards prevent unauthenticated access to dashboard routes
- No secrets or API keys in client code — all URLs configured via `AppConfig`

### Important Notes

- **Never commit `.env` files** — they are excluded in `.gitignore`
- All default passwords have been removed from the codebase — use environment variables
- Tenant admin passwords are generated randomly if `DEFAULT_TENANT_ADMIN_PASSWORD` is not set
- Per-tenant database isolation ensures no data leakage between tenants

---

## Production readiness

The stack is **suitable for production deployment** for the current scope (tenant admin + SaaS owner dashboards, multi-tenant APIs, subscription/order/invoice flows), with the caveats below.

### What is production-ready

| Area | Status |
|------|--------|
| **Backend config** | Separate dev/test/production settings; production requires `DJANGO_SECRET_KEY`, `DATABASE_URL`, `REDIS_URL`, `SYNC_TOKEN`; `DEBUG=False`, SSL/HSTS/CSP, secure cookies, axes, rate limiting |
| **Deployment** | Docker Compose (PostgreSQL, Redis, Gunicorn, Celery, Celery Beat, Nginx), health checks, `.env.example` for required variables |
| **Multi-tenancy** | Per-tenant DB isolation, provisioning and migration commands, no cross-tenant data leakage |
| **Auth & security** | JWT (SimpleJWT), plan-based limits, CORS/CSRF configured for production origins |
| **Flutter** | Dev/prod config switch, secure token storage, release builds (`flutter build web --release` / `flutter build macos --release`) |
| **Operations** | Management commands for orders/subscriptions and daily automation (`auto_advance_today_orders`); health endpoint at `/api/v1/health/` |

### Gaps to address before “full” production hardening (see PLAN.md Phase 9)

- **Tests** — No automated test suite yet; add API and unit tests for critical paths (auth, orders, subscriptions, invoicing).
- **Celery tasks** — Worker/beat are in Docker but no application tasks are defined; usage collection and scheduled jobs are planned, not implemented.
- **Payments** — No Stripe/PayTabs (or other) integration; payments are recorded as cash/card/wallet only.
- **Notifications** — Email/WhatsApp sending not wired; placeholders exist.
- **Backups & monitoring** — Database backup strategy and alerting (e.g. Prometheus is enabled in production) need to be defined for your hosting environment.
- **Cron** — Schedule `auto_advance_today_orders` (e.g. daily) on the host or via a scheduler; document in runbooks.

**Bottom line:** You can run this in production for real tenants and daily use. For higher risk or compliance-heavy use, add tests, backup/monitoring runbooks, and (if needed) payment and notification integrations.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make changes and add tests
4. Run the test suite: `python manage.py test`
5. Commit with a descriptive message
6. Push and open a Pull Request

### Code Style

- **Backend:** Follow Django/PEP 8 conventions. Use `black` for formatting.
- **Frontend:** Follow Dart/Flutter conventions. Use `dart format` for formatting.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
