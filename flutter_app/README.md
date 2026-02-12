# Fun Adventure Kitchen — Flutter Dashboard

Multi-role Flutter dashboard application for the Fun Adventure Kitchen SaaS platform. Supports three layers: SaaS owner administration, tenant kitchen operations, and (planned) customer-facing features.

## Prerequisites

- Flutter SDK 3.10+
- Dart SDK 3.10+
- A running instance of the [Django backend](../clean_backend/README.md)

## Quick Start

```bash
# Install dependencies
flutter pub get

# Run on web (Chrome)
flutter run -d chrome

# Run on macOS
flutter run -d macos
```

## Environment Configuration

Edit `lib/core/config/app_config.dart` to switch between environments:

```dart
// Local development (default)
static AppConfig current = development;

// Production
static AppConfig current = production;
```

| Environment   | Discovery URL                                      | API Base URL                                      |
|---------------|----------------------------------------------------|----------------------------------------------------|
| Development   | `http://127.0.0.1:8000/api/discover/`              | `http://127.0.0.1:8000/api/v1/`                   |
| Production    | `https://api.kitchen.funadventure.ae/api/discover/` | `https://api.kitchen.funadventure.ae/api/v1/`      |

---

## Features

### Layer 1 — SaaS Owner Dashboard (`/saas/*`)

| Feature                | Status    | Description                                                |
|------------------------|-----------|------------------------------------------------------------|
| Platform Analytics     | Complete  | MRR, ARR, total/active/trial tenant counts, invoice summaries |
| Tenant Management      | Complete  | Searchable data table, create tenant, suspend/activate      |
| Tenant Detail          | Complete  | Subscription info, plan limits, latest usage metrics        |
| Plan Management        | Complete  | Card grid with pricing, feature limits, create/edit/toggle  |
| SaaS Shell             | Complete  | Dark indigo sidebar, dedicated header, responsive drawer    |

### Layer 2 — Tenant Admin Dashboard (`/dashboard/*`)

| Feature                | Status    | Description                                                |
|------------------------|-----------|------------------------------------------------------------|
| Tenant Discovery       | Complete  | Connect to a kitchen by entering its code/slug             |
| JWT Authentication     | Complete  | Two-step login flow with secure token storage              |
| Token Refresh          | Complete  | Automatic 401 retry with refreshed access token            |
| Dashboard Overview     | Complete  | Metric cards (orders, deliveries, revenue, customers, inventory, staff) + recent orders |
| Menu Management        | Complete  | List, add, edit, toggle availability, diet type filter     |
| Category Management    | Complete  | CRUD with inline creation from menu item dialog            |
| Daily Rotating Menus   | Complete  | Weekly calendar view, create/publish/archive daily menus   |
| Meal Packages          | Complete  | Subscription tiers with configurable naming and pricing    |
| Subscriptions          | Complete  | Subscription CRUD; activate auto-generates orders and invoice (meal_package supported) |
| Orders                 | Complete  | Tab-filtered list with status workflow; preparing/ready only on delivery day; hint for confirmed future orders |
| Inventory              | Complete  | CRUD with stock adjustment dialog, low-stock filter, cost/supplier tracking |
| Delivery               | Complete  | Tab-filtered list with driver info, status tracking, pickup/delivery times |
| Customer Management    | Complete  | Master-detail layout, add customer (creates User + Profile + Address), search by name/phone/email |
| Registration Requests  | Complete  | Approve (creates User + CustomerProfile) / reject with reason |
| Address Management     | Complete  | Structured fields (building, floor, flat, street, city) with default/active badges |
| Finance                | Complete  | Invoice list with status tabs, summary cards (paid/pending/count), detail dialog with Mark paid and line items |
| Staff Management       | Complete  | CRUD with role assignment (manager/kitchen_staff/driver/staff), deactivation, change-role |
| Dynamic Tenant Info    | Complete  | Header displays real tenant name and user info             |
| Logout                 | Complete  | Available in sidebar and header profile menu               |
| Platform Admin Link    | Complete  | Switch between tenant dashboard and SaaS owner dashboard   |

### Layer 3 — Customer App (Planned)

| Feature                | Status    | Description                                                |
|------------------------|-----------|------------------------------------------------------------|
| Registration / Login   | Planned   | Customer JWT authentication                                |
| Menu Browsing          | Planned   | Browse daily menus and meal packages                       |
| Subscription Mgmt      | Planned   | Subscribe to meal plans                                    |
| Order Tracking         | Planned   | Real-time delivery tracking                                |
| Wallet / Payments      | Planned   | Fund wallet, pay for meals                                 |
| Push Notifications     | Planned   | Order updates, menu announcements                          |

---

## Architecture

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
├── features/
│   ├── auth/                      # Two-step tenant login + staff login
│   │   ├── data/auth_service.dart
│   │   └── presentation/
│   │       ├── tenant_login_screen.dart
│   │       └── user_login_screen.dart
│   │
│   ├── dashboard/                 # Tenant admin shell layout
│   │   └── presentation/
│   │       ├── dashboard_shell.dart
│   │       └── widgets/ (header, sidebar)
│   │
│   ├── admin/                     # Tenant admin features (Layer 2)
│   │   ├── data/admin_repository.dart
│   │   ├── domain/models.dart     # All admin domain models
│   │   └── presentation/
│   │       ├── dashboard_screen.dart
│   │       ├── orders_screen.dart
│   │       ├── inventory_screen.dart
│   │       ├── delivery_screen.dart
│   │       ├── customers_screen.dart   # Master-detail layout
│   │       ├── finance_screen.dart
│   │       └── staff_screen.dart
│   │
│   ├── menu/                      # Menu CRUD + daily menus + packages
│   │   ├── data/menu_repository.dart
│   │   ├── domain/food_item.dart
│   │   └── presentation/
│   │       ├── menu_screen.dart   # Grid + weekly calendar + packages
│   │       └── widgets/ (food_item_card, add_item_modal)
│   │
│   └── saas_admin/                # SaaS owner features (Layer 1)
│       ├── data/saas_repository.dart
│       ├── domain/models.dart
│       └── presentation/
│           ├── saas_shell.dart
│           ├── saas_overview_screen.dart
│           ├── tenants_screen.dart
│           ├── tenant_detail_screen.dart
│           ├── plans_screen.dart
│           └── widgets/ (saas_sidebar, saas_header)
│
└── main.dart                      # Entry point, provider setup, session restore
```

### Key Packages

| Package                  | Purpose                                   |
|--------------------------|-------------------------------------------|
| `provider`               | State management (ChangeNotifier)         |
| `go_router`              | Declarative routing with auth guards      |
| `dio`                    | HTTP client with interceptors             |
| `flutter_secure_storage` | Encrypted token and session storage       |
| `equatable`              | Value equality for models                 |
| `google_fonts`           | Inter font family                         |
| `intl`                   | Date formatting                           |

### Authentication Flow

1. User enters a **kitchen code** (tenant slug)
2. `TenantService` calls `POST /api/discover/` to resolve the tenant
3. Tenant info (name, API endpoint) is stored in secure storage
4. User enters **username** and **password**
5. `AuthService` calls `POST /api/v1/auth/login/` with `X-Tenant-Slug` header
6. JWT tokens are stored in secure storage
7. `AuthProvider` updates state, GoRouter redirects to `/dashboard`

Token refresh is handled transparently by `ApiClient` interceptors — if a 401 is received, the refresh token is used to obtain a new access token and the original request is retried.

### Route Guards

The router's `redirect` function checks `AuthProvider.isLoggedIn`:

- **Not logged in + accessing protected route** → redirected to `/login`
- **Logged in + on login page** → redirected to `/dashboard`

---

## Screens

### SaaS Owner Routes

| Route                  | Screen              | Status     |
|------------------------|---------------------|------------|
| `/saas`                | Platform Overview   | Complete   |
| `/saas/tenants`        | Tenant Management   | Complete   |
| `/saas/tenants/:id`    | Tenant Detail       | Complete   |
| `/saas/plans`          | Plan Management     | Complete   |

### Tenant Admin Routes

| Route         | Screen              | Status     |
|---------------|---------------------|------------|
| `/login`      | Tenant Login        | Complete   |
| `/user-login` | Staff Login         | Complete   |
| `/dashboard`  | Dashboard Overview  | Complete   |
| `/menu`       | Menu Management     | Complete   |
| `/orders`     | Orders              | Complete   |
| `/inventory`  | Inventory           | Complete   |
| `/delivery`   | Delivery            | Complete   |
| `/customers`  | Customers           | Complete   |
| `/finance`    | Finance             | Complete   |
| `/staff`      | Staff               | Complete   |

---

## Design Decisions

- **State Management:** Provider (ChangeNotifier) for simplicity and testability.
- **Routing:** GoRouter with redirect-based auth guards and nested routes for SaaS/tenant dashboards.
- **API Client:** Singleton `ApiClient` wrapping Dio with interceptors for auth header injection, tenant slug injection, and transparent token refresh.
- **Master-Detail Pattern:** Customer management uses responsive master-detail layout (list + detail panel on wide screens).
- **Inline Creation:** Category creation available directly from menu item dialog without navigating away.

## Building for Production

```bash
# Web
flutter build web --release

# macOS
flutter build macos --release
```

The web build output is in `build/web/` and can be served by any static file server or CDN.

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.
