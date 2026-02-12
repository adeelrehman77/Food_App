# Fun Adventure Kitchen - Backend & System Architecture

A comprehensive, production-ready system for managing Fun Adventure Kitchen's food delivery, kitchen operations, and inventory. This repository houses the Django REST Framework backend that powers the ecosystem, including the Customer Mobile App, Admin Dashboard, and Kitchen Display System (KDS).

## 🌍 Ecosystem Overview

The system is composed of the following integrated components:

1.  **Backend Core (This Repo)**: The central source of truth, managing data, business logic, and APIs.
2.  **Customer Mobile App (Android)**: Allows users to view menus, purchase subscriptions, and track deliveries.
3.  **Kitchen Display System (KDS)**: Interface for kitchen staff to view and manage incoming orders.
4.  **Admin Dashboard**: Web-based interface for management and reporting.

## 🏗️ Technical Architecture

### Backend Stack
-   **Framework**: Django 4.2+
-   **API**: Django REST Framework (DRF) with JWT Authentication.
-   **Database**: PostgreSQL 15+ (Production), SQLite (Test).
-   **Caching**: Redis (7+) used for caching and session storage.
-   **Asynchronous Tasks**: Celery & APScheduler for background jobs (e.g., daily order generation from subscriptions).
-   **Real-time**: Django Channels (WebSocket support for live order updates).

### Architecture Highlights
-   **Multi-Tenancy**: Built-in support for multiple organizations (`Tenants`) with domain-based routing (`Domain` model) and database isolation.
-   **Hexagonal / Modular Design**: Features are encapsulated in distinct apps (`kitchen`, `driver`, `inventory`) with clear boundaries.

### Mobile & Frontend Integration
-   **API Contract**: RESTful JSON APIs served to Android (Kotlin) and Web clients.
-   **Security**:
    -   **Play Integrity API**: Integration for verifying Android device integrity.
    -   **JWT**: Secure, stateless authentication for mobile clients.
    -   **API Keys**: Server-to-server authentication for internal tools.

## ✨ Key Features

### 🔐 Authentication & Security
-   **Multi-method Auth**: Support for standard login, social auth (if configured), and API keys.
-   **Role-Based Access Control (RBAC)**: Distinct permissions for `Admin`, `Kitchen Staff`, `Drivers`, and `Customers`.
-   **Security Middleware**: Content Security Policy (CSP), Rate Limiting (via `django-axes` and custom middleware), and SQL Injection protection.

### 🏢 Multi-Tenancy & Organizations
-   **Tenant Isolation**: Data segregation at the database or schema level (configurable).
-   **Subscription Plans**: Tenants can be subscribed to different plans (`SubscriptionPlan`) with varying limits (e.g., `max_orders_per_month`) and feature flags (`has_inventory_management`).
-   **Domain Management**: Custom domains can be mapped to specific tenants.

### 📦 Core Domain: Sales & Orders
-   **Subscriptions**: Logic for recurring food delivery. Subscriptions allow selecting **Multiple Menus**, specific **Time Slots**, and distinct **Lunch/Dinner Addresses**. Supports flexible scheduling with selected days and payment modes.
-   **Order Lifecycle**:
    1.  **Pending**: Order generated from active subscription.
    2.  **Confirmed**: Verified and scheduled.
    3.  **Preparing**: Kitchen has successfully claimed the order.
    4.  **Ready**: Food is prepared and packaged.
    5.  **Delivered**: Driver has completed the drop-off.
-   **Sales History**: Comprehensive tracking of all transactions and order states.

### 🚚 Driver & Delivery Management
-   **Zone & Route Planning**: logical grouping of deliveries into `Zones` and `Routes` for efficient logistics.
-   **Delivery Assignments**: Automated or manual assignment of `DeliveryStatus` to `DeliveryDriver`.
-   **Real-time Tracking**: Status updates (`pending` -> `picked_up` -> `delivered`) with timestamp logging.

### 🍳 Kitchen Operations
-   **Ticket Management**: `KitchenOrder` model tracks preparation times and assignments to specific staff.
-   **Digital KDS**: Real-time visibility into what needs to be cooked *now*, filtered by time slots.

### 📦 Inventory Management
-   **Stock Tracking**: Real-time tracking of ingredients via `InventoryItem`.
-   **Unit Conversion**: Robust `UnitOfMeasure` system handling weight, volume, and unit-based conversions.
-   **Low Stock Alerts**: Configurable `min_stock_level` triggers.

### 👥 User & Customer Management
-   **Detailed Profiles**: `UserProfile` with extended contact info.
-   **Customer Data**: `Customer` model links to `Tenants` and stores critical info like Emirates ID.
-   **Wallet System**: Built-in `WalletTransaction` for handling credits, debits, and refund processing.
-   **Invoicing**: Automated generation of `Invoice` records for subscriptions and services, linked to wallet transactions.
-   **Registration Requests**: `CustomerRegistrationRequest` workflow for managing new manual sign-ups.
-   **Address Book**: Multiple delivery addresses (`Address` model) per customer with "default" address logic.

## 📁 Project Structure

```
clean_backend/
├── apps/                    # Django applications
│   ├── main/               # Core domain (subscriptions, orders, wallet, addresses)
│   ├── kitchen/            # KDS and kitchen workflows
│   ├── delivery/           # Delivery logistics and planning
│   ├── inventory/          # Stock and ingredient management
│   ├── users/              # Auth, Tenants, and Profiles
│   ├── organizations/      # Subscription plans and tenant configuration
│   └── driver/             # Driver mobile app API and fleet management
├── config/                 # Django configuration
│   ├── settings/           # Settings files (base, dev, prod, test)
│   └── urls/               # URL configurations
├── core/                   # Shared utilities & middleware
│   ├── middleware/         # Security & Tenant middleware
│   ├── permissions/        # Custom DRF permissions
│   └── utils/              # Common helpers
├── requirements/           # Python dependencies
├── scripts/                # Management & setup scripts
├── static/                 # Static files
├── templates/              # HTML templates
├── media/                  # User uploaded files
├── logs/                   # Application logs
└── ssl/                    # SSL certificates
```

## 🚀 Quick Start

### Prerequisites

- Python 3.11+
- PostgreSQL 15+
- Redis 7+
- Docker & Docker Compose (optional)

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
   pip install -r requirements/requirements-dev.txt
   ```

4. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

5. **Run database setup**
   ```bash
   python scripts/setup_database.py
   ```

6. **Start development server**
   ```bash
   python manage.py runserver
   ```

### Docker Setup

1. **Build and start services**
   ```bash
   docker-compose up --build
   ```

2. **Run migrations**
   ```bash
   docker-compose exec web python manage.py migrate
   ```

3. **Create superuser**
   ```bash
   docker-compose exec web python manage.py createsuperuser
   ```

## 🔧 Configuration

### Environment Variables

Create a `.env` file with the following variables:

```bash
# Copy the example and fill in real values:
cp .env.example .env
```

See `.env.example` for the full list of variables with descriptions. Key variables:

```env
DJANGO_ENV=development
DJANGO_SECRET_KEY=          # Generate: python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
DATABASE_URL=               # e.g. postgresql://user:pass@localhost:5432/dbname
REDIS_URL=redis://localhost:6379/0
SYNC_TOKEN=                 # A strong random token
```

> **Important:** Never use default or example passwords. Always generate strong, unique credentials for each environment.

### Settings Files

- `config/settings/base.py` - Base settings for all environments
- `config/settings/development.py` - Development-specific settings
- `config/settings/production.py` - Production-specific settings
- `config/settings/test.py` - Test-specific settings

## 📊 API Documentation

Once the server is running, you can access:

- **Swagger UI**: http://localhost:8000/swagger/
- **ReDoc**: http://localhost:8000/redoc/
- **Admin Interface**: http://localhost:8000/admin/

## 🔐 Authentication

The application supports multiple authentication methods:

1. **JWT Authentication** - For API access
2. **API Key Authentication** - For service-to-service communication
3. **Session Authentication** - For web interface

### Creating API Keys

```bash
python scripts/create_api_key.py <username> <key_name> <days_valid>
```

Example:
```bash
python scripts/create_api_key.py admin production_key 90
```

## 🛡️ Security Features

- **Content Security Policy (CSP)** - Prevents XSS attacks
- **Rate Limiting** - Prevents abuse
- **Input Validation** - Sanitizes user input
- **SQL Injection Protection** - Django ORM protection
- **CSRF Protection** - Cross-site request forgery protection
- **Session Security** - Secure session management
- **Password Validation** - Strong password requirements

## 📈 Monitoring

### Health Checks

- **Application Health**: `GET /health/`
- **Database Health**: `GET /health/db/`
- **Cache Health**: `GET /health/cache/`

### Metrics

The application exposes metrics for:

- Request/response times
- Database query performance
- Memory usage
- Error rates
- API usage statistics

## 🧪 Testing

### Run Tests

```bash
# Run all tests
python manage.py test

# Run specific app tests
python manage.py test apps.main

# Run with coverage
coverage run --source='.' manage.py test
coverage report
```

### Test Settings

Tests use a separate settings file (`config/settings/test.py`) with:

- In-memory SQLite database
- Disabled security features
- Fast test execution

## 📝 Logging

Logs are stored in the `logs/` directory:

- `django.log` - General application logs
- `security.log` - Security-related events
- `api.log` - API request logs

## 🚀 Deployment

### Production Deployment

1. **Set environment variables**
   ```bash
   export DJANGO_SETTINGS_MODULE=config.settings.production
   export DJANGO_SECRET_KEY=your-production-secret-key
   export DATABASE_URL=your-production-database-url
   ```

2. **Collect static files**
   ```bash
   python manage.py collectstatic --noinput
   ```

3. **Run migrations**
   ```bash
   python manage.py migrate
   ```

4. **Start with Gunicorn**
   ```bash
   gunicorn --bind 0.0.0.0:8000 --workers 4 config.wsgi:application
   ```

### Docker Deployment

```bash
# Build and start production services
docker-compose -f docker-compose.prod.yml up --build -d

# Scale services
docker-compose -f docker-compose.prod.yml up --scale web=3 --scale celery=2 -d
```

## 🔧 Management Commands

### Available Commands

- `python manage.py setup_database` - Initialize database with sample data
- `python manage.py create_api_key` - Create API keys
- `python manage.py backup_data` - Backup database and media files
- `python manage.py restore_data` - Restore from backup

### Custom Commands

```bash
# Create API key
python scripts/create_api_key.py admin production_key 90

# Setup database
python scripts/setup_database.py
```

## 📚 API Endpoints

### Main Endpoints

- `GET /api/v1/menu/` - Get menu items
- `GET /api/v1/subscriptions/` - Get user subscriptions
- `POST /api/v1/subscriptions/` - Create subscription
- `GET /api/v1/deliveries/` - Get deliveries
- `POST /api/v1/deliveries/` - Create delivery

### Authentication Endpoints

- `POST /api/v1/auth/login/` - Login
- `POST /api/v1/auth/logout/` - Logout
- `POST /api/v1/auth/register/` - Register
- `POST /api/v1/auth/password/reset/` - Reset password

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Run the test suite
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:

- **Email**: support@kitchen.funadventure.ae
- **Documentation**: https://docs.kitchen.funadventure.ae
- **Issues**: GitHub Issues

## 🔄 Changelog

### Version 1.0.0
- Initial release
- Core functionality implemented
- Security features added
- API documentation complete 