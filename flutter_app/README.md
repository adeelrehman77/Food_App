# Fun Adventure Kitchen — Admin Dashboard

Flutter-based admin dashboard for the Fun Adventure Kitchen platform. Provides kitchen staff and administrators with tools to manage menus, view orders, track deliveries, and oversee operations.

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

## Architecture

```
lib/
├── core/                    # Shared infrastructure
│   ├── config/              # Environment configuration
│   ├── network/             # API client with interceptors, tenant discovery
│   ├── providers/           # Auth and tenant state management (ChangeNotifier)
│   ├── router/              # GoRouter with auth-based redirect guards
│   └── theme/               # Material 3 light/dark themes (Google Fonts Inter)
├── features/
│   ├── auth/                # Two-step tenant login + staff login
│   ├── dashboard/           # Shell layout (sidebar, header, content area)
│   └── menu/                # Menu item CRUD (model, repository, screen, widgets)
└── main.dart                # Entry point, provider init, session restore
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

### Authentication Flow

1. User enters a **kitchen code** (tenant slug)
2. `TenantService` calls `POST /api/discover/` to resolve the tenant
3. Tenant info (name, API endpoint) is stored in secure storage
4. User enters **username** and **password**
5. `AuthService` calls `POST /api/v1/auth/login/` with tenant headers
6. JWT tokens are stored in secure storage
7. `AuthProvider` updates state, GoRouter redirects to `/dashboard`

Token refresh is handled transparently by `ApiClient` interceptors — if a 401 is received, the refresh token is used to obtain a new access token and the original request is retried.

### Route Guards

The router's `redirect` function checks `AuthProvider.isLoggedIn`:

- **Not logged in + accessing protected route** → redirected to `/login`
- **Logged in + on login page** → redirected to `/dashboard`

## Screens

| Route         | Screen              | Status     |
|---------------|---------------------|------------|
| `/login`      | Tenant Login        | Complete   |
| `/user-login` | Staff Login         | Complete   |
| `/dashboard`  | Dashboard Overview  | Placeholder|
| `/menu`       | Menu Management     | Complete   |
| `/orders`     | Orders              | Placeholder|
| `/inventory`  | Inventory           | Placeholder|
| `/delivery`   | Delivery            | Placeholder|
| `/customers`  | Customers           | Placeholder|
| `/finance`    | Finance             | Placeholder|

## Building for Production

```bash
# Web
flutter build web --release

# macOS
flutter build macos --release
```

The web build output is in `build/web/` and can be served by any static file server or CDN.
