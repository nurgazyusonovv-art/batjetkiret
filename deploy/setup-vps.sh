#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
#  Batken Express — first-time VPS setup script (Ubuntu 22.04)
#  Run as root: bash setup-vps.sh yourdomain.com
# ═══════════════════════════════════════════════════════════════════════════
set -e

DOMAIN="${1:-yourdomain.com}"
APP_DIR="/var/www/batken"
REPO_URL="https://github.com/YOUR_USERNAME/batjetkiret-backend.git"  # <-- change
DB_NAME="batjetkiret"
DB_USER="batken"
DB_PASS="$(openssl rand -hex 16)"

echo "▶  Domain: $DOMAIN"
echo "▶  App dir: $APP_DIR"

# ── 1. System packages ────────────────────────────────────────────────────
apt-get update -q
apt-get install -y -q \
    git curl nginx certbot python3-certbot-nginx \
    python3.11 python3.11-venv python3-pip \
    postgresql postgresql-contrib \
    nodejs npm

# ── 2. PostgreSQL ─────────────────────────────────────────────────────────
echo "▶  Setting up PostgreSQL..."
sudo -u postgres psql <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
  END IF;
END \$\$;
CREATE DATABASE IF NOT EXISTS $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
SQL

# ── 3. App directory ──────────────────────────────────────────────────────
mkdir -p $APP_DIR
cd $APP_DIR

if [ ! -d "backend/.git" ]; then
    git clone $REPO_URL backend
fi
mkdir -p /var/www/batken/uploads/screenshots
mkdir -p /var/www/batken/web-client
mkdir -p /var/www/batken/admin-panel
mkdir -p /var/www/batken/enterprise-panel

# ── 4. Backend venv ───────────────────────────────────────────────────────
echo "▶  Installing Python dependencies..."
cd $APP_DIR/backend
python3.11 -m venv venv
venv/bin/pip install --quiet --upgrade pip
venv/bin/pip install --quiet -r requirements.txt

# ── 5. Backend .env ───────────────────────────────────────────────────────
SECRET_KEY="$(openssl rand -hex 32)"
cat > $APP_DIR/backend/.env <<ENV
DATABASE_URL=postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME
SECRET_KEY=$SECRET_KEY
DEBUG=False
ALLOW_ORDER_WITHOUT_BALANCE=False
BASE_URL=https://api.$DOMAIN
ALLOWED_ORIGINS=https://$DOMAIN,https://admin.$DOMAIN,https://enterprise.$DOMAIN
LOG_LEVEL=INFO
LOG_JSON=True
SERVICE_NAME=batken-express
ENV

echo ""
echo "  *** SAVE THESE CREDENTIALS ***"
echo "  DB password : $DB_PASS"
echo "  SECRET_KEY  : $SECRET_KEY"
echo ""

# ── 6. Run migrations ─────────────────────────────────────────────────────
echo "▶  Running database migrations..."
cd $APP_DIR/backend
venv/bin/alembic upgrade head

# ── 7. Systemd service ────────────────────────────────────────────────────
echo "▶  Installing systemd service..."
cp $APP_DIR/backend/deploy/batken-backend.service /etc/systemd/system/
sed -i "s|/var/www/batken/backend|$APP_DIR/backend|g" /etc/systemd/system/batken-backend.service
systemctl daemon-reload
systemctl enable batken-backend
systemctl restart batken-backend

# ── 8. Build frontends ────────────────────────────────────────────────────
echo "▶  Building web-client..."
cd $APP_DIR/backend/web-client
echo "VITE_API_URL=https://api.$DOMAIN" > .env.production
npm ci --silent
npm run build
cp -r dist/. /var/www/batken/web-client/

echo "▶  Building admin-panel..."
cd $APP_DIR/backend/admin-panel
echo "VITE_API_BASE_URL=https://api.$DOMAIN" > .env.production
npm ci --silent
npm run build
cp -r dist/. /var/www/batken/admin-panel/

echo "▶  Building enterprise-panel..."
cd $APP_DIR/backend/enterprise-panel
echo "VITE_API_URL=https://api.$DOMAIN" > .env.production
npm ci --silent
npm run build
cp -r dist/. /var/www/batken/enterprise-panel/

# ── 9. Nginx ──────────────────────────────────────────────────────────────
echo "▶  Configuring nginx..."
cp $APP_DIR/backend/nginx/production.conf /etc/nginx/sites-available/batken.conf
sed -i "s/yourdomain.com/$DOMAIN/g" /etc/nginx/sites-available/batken.conf
ln -sf /etc/nginx/sites-available/batken.conf /etc/nginx/sites-enabled/batken.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# ── 10. SSL (Certbot) ─────────────────────────────────────────────────────
echo "▶  Obtaining SSL certificates..."
certbot --nginx --non-interactive --agree-tos --email admin@$DOMAIN \
    -d $DOMAIN -d www.$DOMAIN \
    -d admin.$DOMAIN \
    -d enterprise.$DOMAIN \
    -d api.$DOMAIN

systemctl reload nginx

echo ""
echo "✅  Deploy complete!"
echo "   Web client    : https://$DOMAIN"
echo "   Admin panel   : https://admin.$DOMAIN"
echo "   Enterprise    : https://enterprise.$DOMAIN"
echo "   API           : https://api.$DOMAIN/docs"
