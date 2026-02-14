# Deploy Food App on ryzen

This repo has two deployable parts:

- **clean_backend** — Django REST API + admin. Deploy on ryzen (Docker) and expose as **api.kitchen.funadventure.ae** only, so web, Android, and iOS share one API base URL.
- **flutter_app** — Flutter dashboard (SaaS + tenant admin). Deploy as **web** (e.g. kitchen.funadventure.ae) and/or **mobile** (APK/IPA); all use **api.kitchen.funadventure.ae** for the API.

---

## Recommendation: use Docker (backend)

Ryzen already runs most services in Docker (Nextcloud, Grafana, Portainer, etc.), and this repo has a production Dockerfile. Deploying as a container:

- Fits your existing ops pattern
- Keeps app dependencies and Python version isolated
- Makes updates a simple image rebuild and container swap
- Uses host PostgreSQL and Redis from the container (see env below)

Use **system Python** only if you explicitly want no Docker for this app.

---

## Server check (done)

- **OS:** Ubuntu (Linux 6.8), user `adeeladmin`
- **Python:** 3.12.3 — OK for Django 4.2
- **PostgreSQL:** 16, active — OK
- **Redis:** active, `redis-cli ping` → PONG — OK
- **Nginx:** active — OK for reverse proxy
- **Docker:** 28.2 — OK
- **Disk:** ~572G free — OK
- **RAM:** ~6GB available — OK

**Verdict: Yes, you can deploy this project on ryzen.**

---

## Step-by-step: Docker deploy

All commands below are to be run **on ryzen** (e.g. via SSH).

### 1. Clone (or copy) the repo

Clone the full **Food_App** repo so you have both `clean_backend` and `flutter_app`:

```bash
cd ~
git clone <YOUR_REPO_URL> Food_App
# or: rsync/scp the project from your machine
# You should have: Food_App/clean_backend/ and Food_App/flutter_app/
```

### 2. Create production env file

Create `~/Food_App/clean_backend/.env.production` (or `.env`) with at least:

```bash
cd ~/Food_App/clean_backend

# Required — generate and paste:
# - DJANGO_SECRET_KEY: python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
# - ENCRYPTION_KEY:    python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
# - SYNC_TOKEN:        any long random string (e.g. openssl rand -hex 32)

DJANGO_SETTINGS_MODULE=config.settings.production
DJANGO_SECRET_KEY=<paste-generated-secret-key>
ENCRYPTION_KEY=<paste-generated-fernet-key>
SYNC_TOKEN=<paste-or-generate-long-token>

# DB/Redis on host — from inside Docker use host.docker.internal (Docker 20.10+ on Linux)
DATABASE_URL=postgresql://food_app_user:YOUR_DB_PASSWORD@host.docker.internal:5432/food_app_db
REDIS_URL=redis://host.docker.internal:6379/1

# Hosts (comma-separated)
ALLOWED_HOSTS=kitchen.funadventure.ae,www.kitchen.funadventure.ae,api.kitchen.funadventure.ae,localhost,127.0.0.1
```

Create the PostgreSQL database and user on ryzen (once):

```bash
sudo -u postgres psql -c "CREATE USER food_app_user WITH PASSWORD 'YOUR_DB_PASSWORD';"
sudo -u postgres psql -c "CREATE DATABASE food_app_db OWNER food_app_user;"
```

### 3. Build and run with host network access

So the container can reach PostgreSQL and Redis on the host, use `host.docker.internal` in the env (as above). On Linux you may need to add the host gateway at run time:

```bash
cd ~/Food_App/clean_backend

docker build -t food-app-backend .

# Allow container to resolve host.docker.internal to host (Linux)
docker run -d \
  --name food-app \
  --add-host=host.docker.internal:host-gateway \
  -p 8000:8000 \
  --env-file .env.production \
  --restart unless-stopped \
  food-app-backend
```

If the **build** fails at `collectstatic` (because production settings require env vars), either build with build-args for dummy `DATABASE_URL`/`REDIS_URL`/etc., or use an entrypoint script that runs `collectstatic` and `migrate` at container start (see “Optional: entrypoint” below).

### 4. Run migrations (first time)

```bash
docker exec food-app python manage.py migrate --noinput
# If you use tenant provisioning:
# docker exec food-app python manage.py provision_tenant ...
```

### 5. Point Nginx at the backend (api.kitchen.funadventure.ae)

We keep the **API on a dedicated subdomain** (`api.kitchen.funadventure.ae`) so that:

- Flutter web (e.g. on `kitchen.funadventure.ae`) and future **Android/iOS** apps all use the same API base URL.
- One Nginx server block for the API; dashboard can be served from a different host or block.

Use **Option A** below for the API host. Use Option B only if you later serve the Flutter web dashboard from the same Nginx host as the API (e.g. single domain with path-based routing).

**Option A — API only (recommended)** — Nginx server block for `api.kitchen.funadventure.ae`:

```nginx
server {
    server_name api.kitchen.funadventure.ae;
    # ... SSL, listen 443, etc. ...

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Reload: `sudo systemctl reload nginx`

**Option B — Same host: Flutter web + API** (only if you serve the dashboard from this host too):

```nginx
# API and Django admin → backend container
location /api/ {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
location /admin/ {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
location /static/ { proxy_pass http://127.0.0.1:8000; }
location /media/  { proxy_pass http://127.0.0.1:8000; }

# Flutter web dashboard (SPA: serve index.html for non-file requests)
root /home/adeeladmin/Food_App/flutter_app/build/web;
index index.html;
location / {
    try_files $uri $uri/ /index.html;
}
```

### 6. Quick checks

```bash
curl -s http://127.0.0.1:8000/api/v1/health/
# expect: {"status":"healthy"}
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/admin/
# expect: 200 or 302
```

---

## Deploy Flutter app (flutter_app)

The Flutter app is the dashboard client (SaaS admin + tenant admin). It talks to the backend using URLs in `flutter_app/lib/core/config/app_config.dart`. **Production uses the dedicated API subdomain** `https://api.kitchen.funadventure.ae` for both discovery and API, so the same base URL works for web, Android, and iOS.

### Flutter web (dashboard in the browser)

Build the web app **on your machine** (or in CI) where Flutter is installed; then upload the built files to ryzen and serve them with Nginx.

**1. Build for production (on your Mac/laptop):**

```bash
cd /path/to/Food_App/flutter_app

# Ensure production URLs (app_config.dart: AppConfig.current = production)
# Then build:
flutter pub get
flutter build web --release
```

Output is in `build/web/` (static files: `index.html`, JS, assets).

**2. Copy the web build to ryzen:**

```bash
# From your machine (replace ryzen and path as needed):
rsync -avz --delete flutter_app/build/web/ ryzen:~/Food_App/flutter_app/build/web/
# Or scp -r flutter_app/build/web ryzen:~/Food_App/flutter_app/build/
```

**3. On ryzen, serve the Flutter web app with Nginx** (see “Nginx: backend + Flutter web” below). Nginx will serve the files from e.g. `~/Food_App/flutter_app/build/web` and proxy `/api/` to the Django container.

### Flutter mobile (Android / iOS)

- No deployment on ryzen. Build the app with **production** config (`AppConfig.current = production` in `app_config.dart`, or use build flavours if you add them).
- Point the app at your deployed backend; production config already uses `https://kitchen.funadventure.ae`.
- Distribute via Play Store / App Store or direct APK/IPA.

---

### Optional: entrypoint (if build fails at collectstatic)

Create `~/Food_App/clean_backend/docker-entrypoint.sh`:

```bash
#!/bin/sh
set -e
python manage.py collectstatic --noinput
python manage.py migrate --noinput
exec gunicorn --bind 0.0.0.0:8000 --workers 4 --timeout 120 config.wsgi:application
```

Make it executable, then in the Dockerfile copy it and use it as ENTRYPOINT (with CMD as the gunicorn args). Rebuild and run; then migrations run at start.

---

## Alternative: System Python + gunicorn

If you choose not to use Docker:

1. Clone/copy repo; create venv and install deps:
   ```bash
   cd ~/Food_App/clean_backend
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements/requirements.txt -r requirements/requirements-prod.txt
   ```
2. Create `.env.production` with the same variables as above, but use `localhost` (not `host.docker.internal`) for `DATABASE_URL` and `REDIS_URL`.
3. Run migrations, collectstatic, then gunicorn:
   ```bash
   python manage.py migrate --noinput
   python manage.py collectstatic --noinput
   gunicorn --bind 0.0.0.0:8000 --workers 4 config.wsgi:application
   ```
4. Use systemd to keep gunicorn running and put Nginx in front.

---

## Required environment variables (production)

Set these before running with `DJANGO_SETTINGS_MODULE=config.settings.production`:

| Variable | Description |
|----------|-------------|
| `DJANGO_SECRET_KEY` | Secret key (e.g. from `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`) |
| `DATABASE_URL` | PostgreSQL URL, e.g. `postgresql://USER:PASSWORD@localhost:5432/DBNAME` |
| `REDIS_URL` | Redis URL, e.g. `redis://127.0.0.1:6379/1` |
| `SYNC_TOKEN` | API sync token (generate a secure random string) |
| `ENCRYPTION_KEY` | Fernet key: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` |

Optional but recommended: `ALLOWED_HOSTS`, `CSRF_TRUSTED_ORIGINS`, and email-related vars (`EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `DEFAULT_FROM_EMAIL`). See `config/settings/production.py` and `config/settings/base.py` for full list.

---

## Database (PostgreSQL)

- App uses **django-tenants** and a shared “master” DB; tenant DBs can be on the same server or another.
- Create a DB and user for the app, then set `DATABASE_URL` to that database.
- Run migrations after first deploy: `python manage.py migrate` (and any tenant provisioning commands you use).

---

## Nginx

- Add a server block that proxies to `http://127.0.0.1:8000` (or the port you run gunicorn/Docker on).
- Set `Host` and, if using HTTPS behind a proxy, `X-Forwarded-Proto` (production settings already use `SECURE_PROXY_SSL_HEADER`).

---

## Quick test after deploy

```bash
curl -s http://127.0.0.1:8000/api/v1/health/  # or your health URL
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/admin/
```

Expected: health returns 200 OK; admin may redirect to login (also OK).
