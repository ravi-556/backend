#!/bin/bash
set -e

echo "📦 Installing required packages..."
sudo dnf install -y ruby ruby-devel gcc make nginx

echo "💎 Installing Bundler..."
gem install bundler

APP_DIR="/home/ec2-user/backend"


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
