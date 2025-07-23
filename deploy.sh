#!/bin/bash
set -e
set -x

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

echo "postgres enable and start"
sudo systemctl enable postgresql
sudo systemctl start postgresql


echo "📂 Navigating to app directory..."
cd "$APP_DIR"

echo "💎 Installing app dependencies locally..."
bundle config set path 'vendor/bundle'
bundle install

echo "🔎 Testing DB connection before running migrations..."
PGPASSWORD=securepass psql -h localhost -U backend -d backend_db -c '\dt' || {
  echo "❌ Cannot connect to PostgreSQL. Is the DB and user setup done?";
  exit 1;
}

echo "🗄️ Running DB migrations..."
bundle exec sequel -m db/migrations postgres://backend:securepass@localhost:5432/backend_db || {
  echo "❌ DB migrations failed. Check your migration files.";
  exit 1;
}

echo "✅ Migrations complete."

PORT=9292
echo "🔍 Checking if port $PORT is in use..."
PID=$(ss -ltnp | grep ":9292" | awk '{print $6}' | cut -d',' -f2 | cut -d'=' -f2)

if [ -n "$PID" ]; then
  echo "🔪 Killing Puma running on port $PORT (PID=$PID)"
  kill -9 $PID
else
  echo "✅ No Puma process running on port $PORT"
fi


echo "📄 Ensuring Puma config exists..."
cat > puma.rb <<EOF
port ENV.fetch("PORT") { 9292 }
environment ENV.fetch("RACK_ENV") { "development" }
stdout_redirect 'puma.log', 'puma_err.log', true
EOF

echo "🚀 Starting Puma (logs: puma.log / puma_err.log)..."
nohup bundle exec puma -C puma.rb >> puma.log 2>> puma_err.log &

sleep 2
if lsof -i :9292 > /dev/null; then
  echo "✅ Puma is running on port 9292"
else
  echo "❌ Puma failed to start"
  tail -n 20 puma_err.log
fi