#!/bin/bash
set -e

APP_DIR="/home/ec2-user/backend"
PGDATA_DIR="/var/lib/pgsql/15/data"
PG_VERSION_FILE="$PGDATA_DIR/PG_VERSION"
PG_HBA="$PGDATA_DIR/pg_hba.conf"
DB_NAME="backend_db"
DB_USER="backend"
DB_PASS="securepass"

echo "📦 Installing dependencies..."
sudo dnf install -y ruby3.2 ruby3.2-devel gcc make nginx postgresql15 postgresql15-server

echo "📂 Setting up PostgreSQL 15..."
if [ ! -f "$PG_VERSION_FILE" ]; then
  echo "🔧 Initializing PostgreSQL 15 database..."
  sudo /usr/pgsql-15/bin/postgresql-15-setup initdb
fi

echo "🔐 Configuring pg_hba.conf for md5 password authentication..."
sudo tee "$PG_HBA" > /dev/null <<EOF
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF

echo "🚀 Starting PostgreSQL 15..."
sudo systemctl enable postgresql-15
sudo systemctl restart postgresql-15

echo "📊 Creating user and database if they don’t exist..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

echo "📂 Installing backend gems..."
cd "$APP_DIR"
bundle config set --local path 'vendor/bundle'
bundle install

echo "🗃️ Running database migrations..."
./vendor/bundle/ruby*/bin/sequel -m db/migrations postgres://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME

echo "🌐 Setting up Nginx reverse proxy..."
sudo tee /etc/nginx/conf.d/backend.conf > /dev/null <<EOF
server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://localhost:9292;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

echo "🔄 Restarting Nginx..."
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "🐾 Creating puma.rb if missing..."
if [ ! -f puma.rb ]; then
  cat > puma.rb <<'EOF'
port ENV.fetch("PORT") { 9292 }
environment ENV.fetch("RACK_ENV") { "development" }
stdout_redirect 'puma.log', 'puma_err.log', true
EOF
  echo "✅ Created puma.rb"
fi

echo "🚀 Starting Puma using nohup..."
pkill -f puma || true
nohup bundle exec puma -C puma.rb > log.out 2>&1 &

echo "✅ Deployment complete!"
