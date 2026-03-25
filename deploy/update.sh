#!/bin/bash
# Run on VPS to pull latest code and redeploy: bash deploy/update.sh
set -e

APP_DIR="/var/www/batken/backend"
DOMAIN="${1:-yourdomain.com}"

echo "▶  Pulling latest code..."
cd $APP_DIR
git pull origin main

echo "▶  Updating Python dependencies..."
venv/bin/pip install --quiet -r requirements.txt

echo "▶  Running migrations..."
venv/bin/alembic upgrade head

echo "▶  Restarting backend..."
systemctl restart batken-backend

echo "▶  Rebuilding frontends..."
cd $APP_DIR/web-client
npm ci --silent && npm run build
cp -r dist/. /var/www/batken/web-client/

cd $APP_DIR/admin-panel
npm ci --silent && npm run build
cp -r dist/. /var/www/batken/admin-panel/

cd $APP_DIR/enterprise-panel
npm ci --silent && npm run build
cp -r dist/. /var/www/batken/enterprise-panel/

systemctl reload nginx
echo "✅  Update complete!"
