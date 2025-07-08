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
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='backend'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER backend WITH PASSWORD 'securepass';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='user_data'" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE user_data OWNER backend;"

log "🔧 Installing RVM and Ruby 3.2..."
sudo yum install -y curl gpg
gpg2 --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys \
  409B6B1796C275462A1703113804BB82D39DC0E3 \
  7D2BAF1CF37B13E2069D6956105BD0E739499BDB

\curl -sSL https://get.rvm.io | bash -s stable --ruby=3.2.2
source /etc/profile.d/rvm.sh
rvm use 3.2.2 --default

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
sudo systemctl enable nginx
sudo systemctl restart nginx

log "🚀 Launching Puma server in background..."
pkill -f puma || true
nohup bundle exec puma -C puma.rb &

log "✅ Deployment completed!"