#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting deployment..."

# 1. Pull latest changes
echo "📥 Pulling latest changes..."
git pull origin main

# 2. Build containers
echo "🏗️ Building containers..."
docker compose build

# 3. Apply database migrations
echo "🔄 Running database migrations..."
docker compose run --rm web python manage.py migrate

# 4. Collect static files
echo "🎨 Collecting static files..."
docker compose run --rm web python manage.py collectstatic --noinput

# 5. Restart services
echo "🚀 Restarting services..."
docker compose up -d

echo "✅ Deployment complete!"
