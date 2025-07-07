#!/bin/bash
set -euo pipefail

echo "📦 Updating packages..."
sudo dnf update -y

echo "🔧 Installing dependencies: Ruby, PostgreSQL 14, Nginx..."
sudo dnf install -y ruby ruby-devel gcc make redhat-rpm-config postgresql postgresql-server postgresql-devel nginx

echo "💎 Installing bundler (if not present)..."
if ! command -v bundle &> /dev/null; then
  sudo gem install bundler
fi

echo "📁 Installing Ruby gems locally..."
bundle config set --local path 'vendor/bundle'
bundle install

PGDATA_DIR="/var/lib/pgsql/data"
PG_HBA="$PGDATA_DIR/pg_hba.conf"

echo "🚀 Initializing PostgreSQL 14 if needed..."
if [ ! -f "$PGDATA_DIR/PG_VERSION" ]; then
  sudo /usr/bin/postgresql-setup --initdb
fi

echo "🔧 Updating pg_hba.conf to use md5 authentication..."
sudo sed -i 's/^\(local\s\+all\s\+all\s\+\)\(peer\|ident\|trust\)/\1md5/' "$PG_HBA"

if ! grep -q "^host\s\+all\s\+all\s\+127.0.0.1\/32\s\+md5" "$PG_HBA"; then
  echo "host    all             all             127.0.0.1/32            md5" | sudo tee -a "$PG_HBA" > /dev/null
fi

sudo systemctl enable postgresql
sudo systemctl restart postgresql

echo "🛠️ Creating PostgreSQL user and database if not present..."
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='backend'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE USER backend WITH PASSWORD 'securepass';"
else
  echo "✅ PostgreSQL user 'backend' already exists"
fi

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='appdb'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE DATABASE appdb OWNER backend;"
else
  echo "✅ PostgreSQL database 'appdb' already exists"
fi

echo "📄 Ensuring Puma config file exists..."
if [ ! -f puma.rb ]; then
  cat > puma.rb <<'EOF'
port ENV.fetch("PORT") { 9292 }
environment ENV.fetch("RACK_ENV") { "development" }
EOF
  echo "✅ Created puma.rb"
else
  echo "✅ puma.rb already exists"
fi

echo "🚀 Starting Puma using nohup in background..."
pkill -f puma || true
nohup bundle exec puma -C puma.rb > puma.log 2> puma_err.log &
echo "✅ Puma started. Logs: puma.log, puma_err.log"

echo "🌐 Setting up Nginx reverse proxy..."
sudo tee /etc/nginx/conf.d/myapp.conf > /dev/null <<EOF
server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://localhost:9292;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo rm -f /etc/nginx/conf.d/default.conf || true
sudo nginx -t && sudo systemctl enable nginx && sudo systemctl restart nginx

echo "✅ Deployment complete!"
echo "🔗 Visit: http://<your-ec2-public-ip>"
