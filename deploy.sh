#!/bin/bash
set -euo pipefail

echo "📦 Updating system packages..."
sudo dnf update -y

echo "🔧 Installing dependencies: Ruby, PostgreSQL 15, Nginx..."
sudo dnf install -y ruby ruby-devel gcc make redhat-rpm-config \
  postgresql15 postgresql15-server postgresql15-devel nginx

echo "💎 Installing bundler (if not present)..."
if ! command -v bundle &> /dev/null; then
  sudo gem install bundler
fi

echo "📁 Installing Ruby gems to vendor/bundle..."
bundle config set --local path 'vendor/bundle'
bundle install


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

echo "🚀 Starting Puma (daemon mode)..."
pkill -f puma || true
bundle exec puma -C puma.rb --daemon --redirect-stdout puma.log --redirect-stderr puma_err.log
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

PGDATA_DIR="/var/lib/pgsql/15/data"

if [ ! -f "$PGDATA_DIR/PG_VERSION" ]; then
  echo "📂 Initializing PostgreSQL..."
  cd /tmp
  if sudo -u postgres /usr/bin/initdb -D "$PGDATA_DIR"; then
    echo "✅ PostgreSQL initialized"
  else
    echo "⚠️  PostgreSQL initdb failed (possibly already initialized or partially set up)"
  fi
else
  echo "✅ PostgreSQL already initialized"
fi

echo "⚙️ Setting up custom systemd service for PostgreSQL 15..."
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
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='backend'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE USER backend WITH PASSWORD 'securepass';"
else
  echo "✅ User 'backend' already exists"
fi

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='appdb'" | grep -q 1; then
  sudo -u postgres psql -c "CREATE DATABASE appdb OWNER backend;"
else
  echo "✅ Database 'appdb' already exists"
fi


echo "✅ Deployment completed successfully!"
echo "🔗 Visit: http://<your-ec2-public-ip>"
