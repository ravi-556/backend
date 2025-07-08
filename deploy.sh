#!/bin/bash
set -e

echo "💡 Updating system packages..."
sudo dnf update -y

echo "📦 Installing dependencies: Ruby, PostgreSQL 15, Nginx, GCC, Make..."
sudo dnf install -y ruby ruby-devel gcc make postgresql15 postgresql15-server postgresql15-devel nginx

echo "🧹 Cleaning previous PostgreSQL data directory (if exists)..."
sudo rm -rf /var/lib/pgsql/15/data

echo "🔧 Initializing PostgreSQL 15..."
sudo /usr/pgsql-15/bin/initdb -D /var/lib/pgsql/15/data

echo "🔐 Configuring pg_hba.conf for password authentication..."
PG_HBA="/var/lib/pgsql/15/data/pg_hba.conf"
sudo sed -i "s/^host.*all.*all.*127.0.0.1\/32.*$/host all all 127.0.0.1\/32 md5/" "$PG_HBA"
sudo sed -i "s/^host.*all.*all.*::1\/128.*$/host all all ::1\/128 md5/" "$PG_HBA"

echo "🚀 Starting PostgreSQL 15..."
sudo /usr/pgsql-15/bin/pg_ctl -D /var/lib/pgsql/15/data -l logfile start
sleep 5

echo "👤 Creating PostgreSQL user and database..."
sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'backend') THEN
      CREATE ROLE backend LOGIN PASSWORD 'securepass';
   END IF;
END
\$do\$;

CREATE DATABASE backend_db OWNER backend;
EOF

echo "🌐 Starting NGINX..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "💎 Installing bundler and app dependencies..."
cd /home/ec2-user/backend
gem install bundler
bundle config set --local path 'vendor/bundle'
bundle install

echo "📄 Ensuring puma.rb exists..."
cat > puma.rb <<'EOPUMA'
port ENV.fetch("PORT") { 9292 }
environment ENV.fetch("RACK_ENV") { "development" }
stdout_redirect 'puma.log', 'puma_err.log', true
EOPUMA

echo "🚀 Starting Puma with nohup..."
pkill -f puma || true
nohup bundle exec puma -C puma.rb &