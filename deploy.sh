#!/bin/bash

set -euo pipefail

APP_DIR="/home/ec2-user/backend"
PGDATA_DIR="/var/lib/pgsql/data"

log() {
  echo -e "\n🔧 $1"
}

log "📦 Updating system and installing dependencies..."
sudo yum update -y
sudo yum install -y ruby ruby-devel gcc make git \
  postgresql postgresql-server postgresql-devel nginx

log "🚀 Initializing PostgreSQL if not already..."
if [ ! -f "$PGDATA_DIR/PG_VERSION" ]; then
  sudo postgresql-setup initdb
fi

log "🔧 Updating pg_hba.conf for md5 auth..."
sudo sed -i "s/ident/md5/g" "$PGDATA_DIR/pg_hba.conf"

log "🚀 Starting PostgreSQL..."
sudo systemctl enable postgresql
sudo systemctl restart postgresql

log "🗄️ Creating DB user and DB if not exists..."
sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'backend') THEN
      CREATE USER backend WITH PASSWORD 'securepass';
   END IF;
END
\$do\$;

CREATE DATABASE backend_db OWNER backend;
EOF

log "💎 Installing bundler and app dependencies..."
gem install bundler
cd "$APP_DIR"
bundle install --path vendor/bundle

log "📝 Creating Puma config if missing..."
if [ ! -f puma.rb ]; then
  cat > puma.rb <<EOF
port ENV.fetch("PORT") { 9292 }
environment ENV.fetch("RACK_ENV") { "development" }
stdout_redirect 'puma.log', 'puma_err.log', true
EOF
fi

log "🌐 Configuring and starting Nginx..."
sudo cp nginx.conf /etc/nginx/nginx.conf || true
sudo systemctl enable nginx
sudo systemctl restart nginx

log "🚀 Launching Puma server in background..."
pkill -f puma || true
nohup bundle exec puma -C puma.rb &

log "✅ Deployment completed!"