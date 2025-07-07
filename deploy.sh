#!/bin/bash
set -euo pipefail

echo "📦 Updating packages..."
sudo dnf update -y

echo "🔧 Installing Ruby, PostgreSQL 15, Nginx, and dependencies..."
sudo dnf install -y ruby ruby-devel gcc make redhat-rpm-config \
  postgresql15 postgresql15-server postgresql15-devel nginx

echo "💎 Installing bundler..."
if ! command -v bundle &> /dev/null; then
  gem install bundler
fi

echo "📁 Installing Ruby gems..."
bundle install

PGDATA_DIR="/var/lib/pgsql/15/data"

echo "🚀 Initializing PostgreSQL 15 manually..."
if [ ! -d "$PGDATA_DIR/base" ]; then
  sudo -u postgres /usr/bin/initdb -D "$PGDATA_DIR"
else
  echo "✅ PostgreSQL already initialized"
fi

echo "⚙️ Creating custom systemd service for PostgreSQL 15..."
sudo tee /etc/systemd/system/postgresql15-custom.service > /dev/null <<EOF
[Unit]
Description=PostgreSQL 15 Custom Database Server
After=network.target

[Service]
Type=forking
User=postgres
ExecStart=/usr/bin/pg_ctl -D $PGDATA_DIR -l $PGDATA_DIR/logfile start
ExecStop=/usr/bin/pg_ctl -D $PGDATA_DIR stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable postgresql15-custom
sudo systemctl start postgresql15-custom

echo "🛠️ Creating PostgreSQL user and database..."
# Create user 'backend' and database 'appdb' only if not exists
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='backend'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE USER backend WITH PASSWORD 'securepass';"
else
  echo "✅ User 'backend' already exists"
fi

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='user_data'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE DATABASE user_data OWNER backend;"
else
  echo "✅ Database 'user_data' already exists"
fi

echo "📄 Ensuring Puma config exists..."
if [ ! -f puma.rb ]; then
  cat > puma.rb <<'EOF'
port ENV.fetch("PORT") { 9292 }
environment ENV.fetch("RACK_ENV") { "development" }
daemonize true
stdout_redirect 'puma.log', 'puma_err.log', true
EOF
  echo "✅ Created puma.rb"
else
  echo "✅ Puma config already exists"
fi

echo "🚀 Starting Puma in daemon mode..."
pkill -f puma || true
puma -C puma.rb

echo "🌐 Configuring Nginx as reverse proxy..."
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
sudo nginx -t && sudo systemctl restart nginx

echo "✅ Deployment complete. Visit your app at http://<your-ec2-ip>"
