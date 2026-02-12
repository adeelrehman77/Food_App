# Fun Adventure Kitchen

A multi-tenant food delivery and kitchen management platform. The system supports subscription-based meal delivery, kitchen operations (KDS), driver fleet management, inventory tracking, and a full admin dashboard — all with per-tenant data isolation.

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
  - [Backend Setup](#backend-setup)
- [Frontend (Flutter Admin Dashboard)](#frontend-flutter-admin-dashboard)
  - [Features](#features)
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
│  Menu, Orders, Kitchen KDS, Inventory, Delivery, Staff, Finance     │
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
└─────────────┬──────────────────────────────────┬────────────────────┘
              │                                  │
              ▼                                  ▼
┌──────────────────────────┐     ┌────────────────────────────────────┐
│    Flutter Admin App     │     │     Django REST API (Gunicorn)     │
│   (Web / macOS / iOS)    │────▶│   /api/v1/, /api/saas/,            │
│                          │     │   /api/v1/customer/                │
│  • Tenant Discovery      │     │                                    │
│  • JWT Auth              │     │  ┌──────────┐  ┌───────────────┐  │
│  • Dashboard (L2)        │     │  │  Celery   │  │ Celery Beat   │  │
│  • Customer App (L3)     │     │  │  Worker   │  │ (Scheduler)   │  │
│  • SaaS Admin (L1)       │     │  └─────┬────┘  └───────┬───────┘  │
└──────────────────────────┘     └────────┼───────────────┼──────────┘
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

---

## Tech Stack

| Layer        | Technology                                                                  |
|--------------|-----------------------------------------------------------------------------|
| **Backend**  | Python 3.11+, Django 4.2+, Django REST Framework, Celery, Django Channels   |
| **Frontend** | Flutter (Dart 3.10+), Provider, GoRouter, Dio, Material Design 3            |
| **Database** | PostgreSQL 15+ (production), SQLite (development fallback)                  |
| **Cache**    | Redis 7+ (sessions, caching, Celery broker, Channels layer)                |
| **Auth**     | JWT (SimpleJWT), API Keys, Session-based, django-axes brute-force protection|
| **DevOps**   | Docker, Docker Compose, Nginx, Gunicorn, WhiteNoise                         |
| **Docs**     | Swagger / OpenAPI (drf-yasg), ReDoc                                         |

---

## Project Structure

```
Food_App/
├── clean_backend/                 # Django REST API
│   ├── apps/
│   │   ├── main/                  # Core domain (menu, orders, subscriptions, wallet)
│   │   ├── users/                 # Auth, tenants, user profiles
│   │   ├── organizations/         # Tenant discovery, service plans
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
│   │   ├── permissions/           # Custom DRF permissions
│   │   ├── db/                    # Multi-database tenant router
│   │   └── utils/                 # Validators and helpers
│   ├── scripts/                   # Provisioning, migration, API key scripts
│   ├── templates/                 # HTML templates
│   ├── requirements/              # Python dependencies (base, dev, prod)
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── .env.example               # Environment variable reference
│   └── manage.py
│
├── flutter_app/                   # Flutter Admin Dashboard
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/            # AppConfig (environment URLs)
│   │   │   ├── network/           # ApiClient (Dio + interceptors), TenantService
│   │   │   ├── providers/         # AuthProvider, TenantProvider
│   │   │   ├── router/            # GoRouter with auth guards
│   │   │   └── theme/             # Material 3 theming
│   │   ├── features/
│   │   │   ├── auth/              # Login screens, AuthService
│   │   │   ├── dashboard/         # Shell layout, header, sidebar
│   │   │   └── menu/              # Menu CRUD (model, repository, screens)
│   │   └── main.dart              # App entry point
│   └── pubspec.yaml
│
└── README.md                      # ← You are here
```

---

## Backend

### Django Apps

| App | Layer | Purpose |
|-----|-------|---------|
| `main` | L2 + L3 | Menu, orders, subscriptions, customers, wallet, invoicing, addresses, staff management, customer-facing APIs |
| `users` | Shared | Tenant model, domain mapping, user profiles, tenant discovery |
| `organizations` | L1 | Service plans, tenant subscriptions, tenant invoices, usage tracking, SaaS analytics |
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
| `CRUD` | `/api/v1/menu-items/` | Menu item management |
| `POST` | `/api/v1/menu-items/{id}/toggle_availability/` | Toggle availability |
| `CRUD` | `/api/v1/categories/` | Category management |
| **Orders** | | |
| `CRUD` | `/api/v1/orders/` | Order management |
| `POST` | `/api/v1/orders/{id}/update_status/` | Update order status |
| **Kitchen KDS** | | |
| `CRUD` | `/api/v1/kitchen/orders/` | Kitchen order queue |
| `POST` | `/api/v1/kitchen/orders/{id}/claim/` | Claim an order |
| `POST` | `/api/v1/kitchen/orders/{id}/start_preparation/` | Start cooking |
| `POST` | `/api/v1/kitchen/orders/{id}/mark_ready/` | Mark ready |
| **Delivery Management** | | |
| `CRUD` | `/api/v1/delivery/deliveries/` | Delivery tracking |
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
| `CRUD` | `/api/v1/customers/` | Customer profiles |
| `CRUD` | `/api/v1/registration-requests/` | Registration requests |
| `POST` | `/api/v1/registration-requests/{id}/approve/` | Approve request |
| `POST` | `/api/v1/registration-requests/{id}/reject/` | Reject request |
| **Staff Management** | | |
| `CRUD` | `/api/v1/staff/` | Staff user management |
| `POST` | `/api/v1/staff/{id}/deactivate/` | Deactivate staff |
| `POST` | `/api/v1/staff/{id}/change_role/` | Change staff role |
| **Finance** | | |
| `GET` | `/api/v1/invoices/` | Invoice list |
| `GET` | `/api/v1/notifications/` | Notification management |
| `GET` | `/api/v1/subscriptions/` | Subscription list |
| `GET` | `/api/v1/wallet/` | Wallet transactions |
| `GET` | `/api/v1/addresses/` | Address management |

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

The platform uses a **multi-database** isolation strategy:

1. **Shared database** (`default`) stores `Tenant`, `Domain`, `UserProfile`, and `ServicePlan` models.
2. **Tenant databases** (e.g., `tenant_1`, `tenant_2`) store all domain-specific data (menus, orders, subscriptions, inventory).
3. The `MultiDbTenantMiddleware` reads the `X-Tenant-ID` header or subdomain to resolve the current tenant and sets the database alias for the request.
4. `TenantRouter` in `core/db/router.py` routes ORM queries to the correct database.

New tenants are provisioned with `scripts/provision_tenant.py`, which creates the database, runs migrations, and sets up default data.

### Backend Setup

#### Prerequisites

- Python 3.11+
- PostgreSQL 15+ (or use SQLite in development)
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
# Edit .env with your values

# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Start development server
python manage.py runserver
```

The API is now available at `http://localhost:8000/api/v1/` and docs at `http://localhost:8000/swagger/`.

---

## Frontend (Flutter Admin Dashboard)

The admin dashboard is a Flutter application targeting **web** and **macOS** (extensible to iOS/Android). It connects to the Django backend via the REST API.

### Features

| Feature                | Status          | Description                                                |
|------------------------|-----------------|------------------------------------------------------------|
| Tenant Discovery       | Complete        | Connect to a kitchen by entering its code/slug             |
| JWT Authentication     | Complete        | Two-step login flow with secure token storage              |
| Auth State Management  | Complete        | Persistent session with automatic route guards             |
| Token Refresh          | Complete        | Automatic 401 retry with refreshed access token            |
| Menu Management        | Complete        | List, add, toggle availability (connected to real API)     |
| Dashboard Shell        | Complete        | Responsive layout with sidebar and header                  |
| Dynamic Tenant Info    | Complete        | Header displays real tenant name and user info             |
| Logout                 | Complete        | Available in sidebar and header profile menu               |
| Orders                 | Placeholder     | UI shell ready, API integration pending                    |
| Inventory              | Placeholder     | UI shell ready, API integration pending                    |
| Delivery               | Placeholder     | UI shell ready, API integration pending                    |
| Customers              | Placeholder     | UI shell ready, API integration pending                    |
| Finance                | Placeholder     | UI shell ready, API integration pending                    |

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
│   │       ├── dashboard_shell.dart      # Layout wrapper (sidebar + header + content)
│   │       └── widgets/
│   │           ├── header.dart           # Top bar with tenant info, search, profile
│   │           └── sidebar.dart          # Navigation menu with logout
│   └── menu/
│       ├── data/
│       │   └── menu_repository.dart      # API calls for menu CRUD
│       ├── domain/
│       │   └── food_item.dart            # FoodItem model with JSON serialization
│       └── presentation/
│           ├── menu_screen.dart          # Grid view with error/empty/loading states
│           └── widgets/
│               ├── food_item_card.dart   # Item display card
│               └── add_item_modal.dart   # Add/edit dialog
│
└── main.dart                      # Entry point, provider setup, session restore
```

**Key Design Decisions:**

- **State Management:** Provider (ChangeNotifier pattern) for simplicity and testability.
- **Routing:** GoRouter with `redirect` function that reads `AuthProvider.isLoggedIn` — unauthenticated users are sent to `/login`, authenticated users on `/login` are sent to `/dashboard`.
- **API Client:** Singleton `ApiClient` wrapping Dio with interceptors for automatic auth header injection, tenant header injection, and transparent token refresh on 401.
- **Environment Config:** `AppConfig` class with `development` and `production` presets. Switch by changing `AppConfig.current` in `main.dart`.

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

# 5. Collect static files
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
| `DATABASE_URL`                   | Prod     | SQLite in dev            | PostgreSQL connection string             |
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

### Frontend Security

- JWT tokens stored in `FlutterSecureStorage` (Keychain on iOS/macOS, Keystore on Android, encrypted on web)
- Automatic token refresh on 401 with request retry
- Route guards prevent unauthenticated access to dashboard routes
- No secrets or API keys in client code — all URLs configured via `AppConfig`

### Important Notes

- **Never commit `.env` files** — they are excluded in `.gitignore`
- All default passwords have been removed from the codebase — use environment variables
- The `fix_tenant.py` script requires the password as a CLI argument
- Tenant admin passwords are generated randomly if `DEFAULT_TENANT_ADMIN_PASSWORD` is not set

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
