#!/bin/bash
set -euo pipefail

echo "📦 Updating packages..."
sudo dnf update -y

echo "🔧 Installing Ruby, PostgreSQL, Nginx, and dependencies..."
sudo dnf install -y ruby ruby-devel gcc make redhat-rpm-config nginx

echo "📦 Enabling PostgreSQL module and installing packages..."
sudo dnf install -y postgresql15 postgresql15-server postgresql15-devel

echo "🚀 Initializing PostgreSQL 15 manually..."
if [ ! -d "/var/lib/pgsql/15/data/base" ]; then
  sudo -u postgres /usr/bin/initdb -D /var/lib/pgsql/15/data
else
  echo "✅ PostgreSQL 15 already initialized"
fi

sudo systemctl enable postgresql-15
sudo systemctl start postgresql-15


echo "💎 Installing bundler..."
if ! command -v bundle &> /dev/null; then
  gem install bundler
fi

echo "📁 Installing Ruby gems..."
bundle install

echo "🛠️ Checking PostgreSQL user and database..."

# Check and create user if not exists
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='backend'" | grep -q 1; then
  echo "👤 Creating PostgreSQL user: backend"
  sudo -u postgres psql -c "CREATE USER backend WITH PASSWORD 'securepass';"
else
  echo "✅ PostgreSQL user 'backend' already exists"
fi

# Check and create DB if not exists
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='user_data'" | grep -q 1; then
  echo "🗄️ Creating PostgreSQL database: user_data"
  sudo -u postgres psql -c "CREATE DATABASE user_data OWNER backend;"
else
  echo "✅ PostgreSQL database 'user_data' already exists"
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

echo "🌀 Removing default Nginx config if exists..."
sudo rm -f /etc/nginx/conf.d/default.conf || true

echo "🔄 Restarting Nginx..."
sudo nginx -t && sudo systemctl restart nginx

echo "✅ Deployment complete. App is live at http://<EC2-PUBLIC-IP>"
