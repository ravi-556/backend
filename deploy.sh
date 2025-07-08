#!/bin/bash
set -e

echo "📦 Installing required packages..."
sudo dnf install -y ruby ruby-devel gcc make postgresql15 postgresql15-server nginx

echo "💎 Installing Bundler..."
gem install bundler

APP_DIR="/home/ec2-user/backend"
PGDATA_DIR="/var/lib/pgsql/data"
DB_USER="backend"
DB_PASS="securepass"
DB_NAME="backend_db"

echo "🧹 Cleaning previous PostgreSQL data directory (if exists)..."
if [ -d "$PGDATA_DIR" ] && [ ! -f "$PGDATA_DIR/PG_VERSION" ]; then
  sudo rm -rf "$PGDATA_DIR"
fi

echo "🔧 Initializing PostgreSQL 15..."
if [ ! -f "$PGDATA_DIR/PG_VERSION" ]; then
  sudo postgresql-setup --initdb
fi

echo "🔐 Configuring pg_hba.conf for password authentication..."
sudo sed -i "s/^host.*all.*all.*127.0.0.1.*ident/host all all 127.0.0.1\/32 md5/" "$PGDATA_DIR/pg_hba.conf"
sudo sed -i "s/^host.*all.*all.*::1.*ident/host all all ::1\/128 md5/" "$PGDATA_DIR/pg_hba.conf"

echo "🚀 Starting PostgreSQL..."
sudo systemctl enable postgresql
sudo systemctl start postgresql

echo "🗄️ Creating DB user and database if not exists..."
sudo -u postgres psql <<EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = '${DB_USER}') THEN
      CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASS}';
   END IF;
END
\$\$;
CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};
EOF

echo "🌐 Starting NGINX..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "📂 Navigating to app directory..."
cd "$APP_DIR"

echo "💎 Installing app dependencies..."
bundle install --path vendor/bundle

echo "📄 Ensuring Puma config exists..."
cat > puma.rb <<EOF
port ENV.fetch("PORT") { 9292 }
environment ENV.fetch("RACK_ENV") { "development" }
stdout_redirect 'puma.log', 'puma_err.log', true
EOF

echo "🚀 Starting Puma..."
nohup bundle exec puma -C puma.rb &

echo "✅ Deployment complete."
