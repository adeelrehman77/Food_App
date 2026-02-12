# Fun Adventure Kitchen — Backend API

A comprehensive, production-ready Django REST Framework backend powering the Fun Adventure Kitchen multi-tenant food delivery SaaS platform. Manages all three SaaS layers: platform administration, tenant operations, and customer-facing services — with full per-tenant database isolation.

## Ecosystem Overview

The system is composed of the following integrated components:

1. **Backend Core (This Repo)**: The central source of truth, managing data, business logic, and APIs.
2. **Flutter Admin Dashboard**: Multi-role dashboard for SaaS owners and tenant administrators.
3. **Customer Mobile App**: (Planned) Allows customers to view daily menus, subscribe to meal plans, and track deliveries.
4. **Kitchen Display System (KDS)**: Interface for kitchen staff to view and manage incoming orders.

## Technical Architecture

### Backend Stack
- **Framework**: Django 4.2+ with Django REST Framework
- **API**: RESTful JSON APIs with JWT Authentication (SimpleJWT)
- **Database**: PostgreSQL 15+ with per-tenant database isolation
- **Caching**: Redis 7+ for caching, session storage, and Celery broker
- **Asynchronous Tasks**: Celery & APScheduler for background jobs
- **Real-time**: Django Channels (WebSocket support for live order updates)
- **Docs**: Swagger/OpenAPI (drf-yasg) and ReDoc

### Architecture Highlights
- **3-Layer SaaS**: Platform admin (L1), Tenant admin (L2), B2C Customer (L3)
- **Multi-Tenancy**: Per-tenant database isolation via `TenantRouter` and `MultiDbTenantMiddleware`
- **Hexagonal / Modular Design**: Features encapsulated in distinct apps with clear boundaries
- **Plan Enforcement**: Subscription-based permission classes enforce limits automatically

### Multi-Tenant Database Strategy

```
TenantRouter
├── SAAS_ONLY_APPS → always route to 'default' DB
│   organizations, users, admin, sites, axes, django_apscheduler
│
└── ALL OTHER APPS → follow tenant context (thread-local DB alias)
    auth, contenttypes, sessions, main, kitchen, delivery,
    driver, inventory, account, authtoken
```

- **Shared DB (`default`)**: Tenant, Domain, UserProfile, ServicePlan, TenantSubscription, TenantInvoice, TenantUsage
- **Tenant DBs** (e.g., `tenant_acme`): auth.User, MenuItem, DailyMenu, Order, CustomerProfile, Address, etc.
- Each tenant has its own `auth_user` table — no cross-database FK hacks
- `X-Tenant-Slug` header determines which tenant DB to route to

## Key Features

### Authentication & Security
- **Multi-method Auth**: JWT (primary), API Keys (service-to-service), Session (admin interface)
- **Role-Based Access Control (RBAC)**: Distinct permissions for Admin, Kitchen Staff, Drivers, and Customers
- **Security Middleware**: CSP, Rate Limiting (django-axes + custom), Input Sanitization, SQL Injection protection
- **Plan-Based Permissions**: PlanLimitMenuItems, PlanLimitStaffUsers, PlanLimitCustomers enforce subscription limits

### Multi-Tenancy & Organizations
- **Per-Tenant Database Isolation**: Each tenant gets a dedicated PostgreSQL database
- **Service Plans**: Configurable tiers (free/basic/pro/enterprise) with pricing, limits, and feature flags
- **Tenant Provisioning**: Management command creates DB, runs migrations, creates admin user, assigns plan
- **Domain Management**: Custom domains mapped to specific tenants

### Menu & Daily Rotating Menus
- **Master Menu Items**: `MenuItem` with name, description, price, diet type (veg/nonveg/both), optional calories, category
- **Categories**: Tenant-configurable categories (inline creation supported)
- **Meal Slots**: Configurable time slots (Breakfast, Lunch, Dinner, etc.) with cutoff times and sort order
- **Daily Menus**: Date + meal slot + diet type combinations with status workflow (draft → published → archived)
- **Daily Menu Items**: Link master items to daily menus with optional price overrides, portion labels, sort order
- **Meal Packages**: Subscription tiers (e.g., Executive, Economy) with tenant-configurable names, pricing, duration

### Orders & Subscriptions
- **Order Lifecycle**: Pending → Confirmed → Preparing → Ready → Delivered
- **Subscriptions**: Recurring meal delivery with multiple menu selections, time slots, and delivery addresses
- **Wallet System**: Credits, debits, refund processing via WalletTransaction
- **Invoicing**: Automated Invoice generation linked to wallet transactions

### Customer Management
- **Customer Profiles**: User + CustomerProfile + Address created in tenant DB
- **Registration Requests**: Admin approval workflow creates User and CustomerProfile upon approval
- **Address Management**: Structured address fields (building, floor, flat, street, city) with default/active status
- **Admin Address CRUD**: AddressAdminViewSet with approve/reject actions

### Kitchen Operations (KDS)
- **Ticket Management**: KitchenOrder tracks preparation times and staff assignments
- **Digital KDS**: Real-time visibility into cooking queue, filtered by time slots

### Delivery & Driver Management
- **Zone & Route Planning**: Logical grouping of deliveries into Zones and Routes
- **Delivery Assignments**: Assignment of DeliveryStatus to DeliveryDriver
- **Real-time Tracking**: Status updates (pending → picked_up → delivered) with timestamps

### Inventory Management
- **Stock Tracking**: Real-time tracking via InventoryItem
- **Unit Conversion**: Robust UnitOfMeasure system (weight, volume, units)
- **Low Stock Alerts**: Configurable min_stock_level triggers

## Project Structure

```
clean_backend/
├── apps/                    # Django applications
│   ├── main/               # Core domain (menus, daily menus, meal packages, orders,
│   │   ├── models.py       #   subscriptions, customers, addresses, wallet, staff)
│   │   ├── serializers/    #   Admin + Customer API serializers
│   │   ├── views/          #   Admin + Customer API viewsets
│   │   ├── urls_api.py     #   Tenant admin URL routing
│   │   └── urls_customer_api.py  # Customer API URL routing
│   ├── kitchen/            # KDS and kitchen workflows
│   ├── delivery/           # Delivery logistics and planning
│   ├── inventory/          # Stock and ingredient management
│   ├── users/              # Tenant model, domain mapping, user profiles, signals
│   ├── organizations/      # Service plans, SaaS models, management commands
│   │   └── management/commands/
│   │       ├── provision_tenant.py
│   │       ├── migrate_all_tenants.py
│   │       └── seed_meal_slots.py
│   └── driver/             # Driver fleet management
├── config/                 # Django configuration
│   ├── settings/           # base, development, production, test
│   └── urls.py             # Root URL config (L1 + L2 + L3 routes)
├── core/                   # Shared utilities & middleware
│   ├── middleware/         # Security, MultiDbTenantMiddleware, performance
│   ├── permissions/        # Custom DRF permissions + plan_limits.py
│   ├── db/                # TenantRouter (multi-database routing)
│   └── utils/              # Common helpers
├── requirements/           # Python dependencies
├── scripts/                # Provisioning, migration, API key scripts
├── static/                 # Static files
├── templates/              # HTML templates
├── media/                  # User uploaded files
├── logs/                   # Application logs
└── ssl/                    # SSL certificates
```

## Quick Start

### Prerequisites

- Python 3.11+
- PostgreSQL 15+
- Redis 7+ (optional in development)

### Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd clean_backend
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements/requirements.txt
   ```

4. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env — set DB_NAME, DB_USER, DB_PASSWORD, DB_HOST, DJANGO_SECRET_KEY
   ```

5. **Run migrations (shared database)**
   ```bash
   python manage.py migrate
   ```

6. **Create SaaS superuser**
   ```bash
   python manage.py createsuperuser
   ```

7. **Provision a tenant**
   ```bash
   python manage.py provision_tenant
   ```

8. **Start development server**
   ```bash
   python manage.py runserver
   ```

### Docker Setup

```bash
docker-compose up --build -d
docker-compose exec web python manage.py migrate
docker-compose exec web python manage.py createsuperuser
docker-compose exec web python manage.py provision_tenant
```

## Management Commands

| Command | Description |
|---------|-------------|
| `python manage.py provision_tenant` | Full tenant provisioning: creates DB, runs migrations, creates admin user, assigns plan |
| `python manage.py migrate_all_tenants` | Migrate all tenant databases (supports `--parallel`, `--tenant=<slug>`) |
| `python manage.py seed_meal_slots` | Seed default meal slots (Lunch, Dinner) for a tenant |
| `python manage.py createsuperuser` | Create SaaS-level superuser (default DB) |

## Configuration

### Environment Variables

See `.env.example` for the full list. Key variables:

```env
DJANGO_ENV=development
DJANGO_SECRET_KEY=          # Generate with Django's get_random_secret_key()
DB_NAME=food_app            # PostgreSQL database name
DB_USER=postgres            # PostgreSQL user
DB_PASSWORD=                # PostgreSQL password
DB_HOST=localhost           # PostgreSQL host
REDIS_URL=redis://localhost:6379/0
```

> **Important:** Never use default or example passwords. Always generate strong, unique credentials.

### Settings Files

- `config/settings/base.py` — Base settings for all environments
- `config/settings/development.py` — Development-specific settings
- `config/settings/production.py` — Production-specific settings
- `config/settings/test.py` — Test-specific settings

## API Documentation

Once the server is running:

- **Swagger UI**: http://localhost:8000/swagger/
- **ReDoc**: http://localhost:8000/redoc/
- **Admin Interface**: http://localhost:8000/admin/

## Authentication

| Method | Header | Use Case |
|--------|--------|----------|
| JWT | `Authorization: Bearer <token>` | Primary API access (60min access, 24hr refresh) |
| API Key | `X-Api-Key: <key>` | Service-to-service communication |
| Session | Cookie | Django admin interface |

### Creating API Keys

```bash
python scripts/create_api_key.py <username> <key_name> <days_valid>
```

## Security Features

- **Content Security Policy (CSP)** — Prevents XSS attacks
- **Rate Limiting** — django-axes (5 failures = 1hr lockout) + custom middleware
- **Input Validation** — Sanitizes user input
- **SQL Injection Protection** — Django ORM protection
- **CSRF Protection** — Cross-site request forgery protection
- **Session Security** — Secure session management
- **Password Validation** — Strong password requirements
- **Plan-Based Limits** — Subscription tier enforcement on create actions

## Monitoring

### Health Checks
- **Application Health**: `GET /api/v1/health/`
- **Dashboard Summary**: `GET /api/v1/dashboard/summary/`

### Metrics
- Request/response times (performance middleware)
- Database query performance (N+1 detection)
- Memory usage
- Error rates

## Testing

```bash
# Run all tests
python manage.py test

# Run specific app tests
python manage.py test apps.main

# Run with coverage
coverage run --source='.' manage.py test
coverage report
```

## Deployment

### Production

```bash
export DJANGO_SETTINGS_MODULE=config.settings.production
python manage.py collectstatic --noinput
python manage.py migrate
gunicorn --bind 0.0.0.0:8000 --workers 4 config.wsgi:application
```

### Docker

```bash
docker-compose -f docker-compose.prod.yml up --build -d
docker-compose -f docker-compose.prod.yml up --scale web=3 --scale celery=2 -d
```

## Logging

Logs are stored in the `logs/` directory:
- `django.log` — General application logs
- `security.log` — Security-related events
- `api.log` — API request logs

## License

This project is licensed under the MIT License - see the LICENSE file for details.
