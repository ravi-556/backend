#!/bin/bash
set -e

echo "📦 Installing required packages..."
sudo dnf install -y ruby ruby-devel gcc make nginx postgresql-devel

echo "💎 Installing Bundler locally (no sudo)..."
gem install --user-install bundler

# Export GEM_PATH so bundler is found and used from local gems
export GEM_HOME="$HOME/.gem"
export PATH="$GEM_HOME/bin:$PATH"

APP_DIR="/home/ec2-user/backend"

echo "🌐 Starting NGINX..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "📂 Navigating to app directory..."
cd "$APP_DIR"

echo "💎 Installing app dependencies locally..."
bundle config set path 'vendor/bundle'
bundle install

echo "🗄️ Running DB migrations..."
bundle exec sequel -m db/migrations postgres://backend:securepass@localhost:5432/backend_db

echo "📄 Ensuring Puma config exists..."
cat > puma.rb <<EOF
port ENV.fetch("PORT") { 9292 }
environment ENV.fetch("RACK_ENV") { "development" }
stdout_redirect 'puma.log', 'puma_err.log', true
EOF

echo "🚀 Starting Puma..."
nohup bundle exec puma -C puma.rb &

echo "✅ Deployment complete."
