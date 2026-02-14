#!/bin/bash

# Exit on error
set -e

# Configuration
SERVER_USER="adeeladmin"
SERVER_IP="192.168.1.213"
SERVER_PATH="/home/adeeladmin/food_app/web-build"
LOCAL_BUILD_PATH="flutter_app/build/web/"

echo "🚀 Starting deployment..."

# 1. Build Flutter Web App
echo "🏗️ Building Flutter Web App..."
cd flutter_app
flutter build web --release
cd ..

# 2. Upload to Server
echo "📤 Uploading to server..."
# Ensure the target directory exists
ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${SERVER_PATH}"

# Sync files
rsync -avz --delete ${LOCAL_BUILD_PATH} ${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}

echo "✅ Deployment complete! Don't forget to restart nginx if needed."
