#!/bin/bash
# Frappe 15 Development Environment Auto-Installer for WSL2 (Ubuntu 22.04)

set -e

# Configuration
APP_NAME="user_growth_analytics"
BENCH_DIR="$HOME/frappe-bench"
DB_ROOT_PASSWORD="admin" # Default root password
SITE_NAME="demo.localhost"

echo "🚀 Starting Frappe v15 Development Environment Setup..."

# 1. Update and install dependencies
echo "📦 Installing system dependencies..."
sudo apt update && sudo apt install -y \
  git curl wget python3-pip python3-venv python3-dev \
  libmysqlclient-dev libssl-dev libffi-dev libjpeg-dev libzip-dev \
  redis-server xvfb libfontconfig wkhtmltopdf \
  build-essential libmariadb-dev software-properties-common

# 2. Setup MariaDB (10.6+)
echo "🗄️ Setting up MariaDB..."
sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
sudo add-apt-repository 'deb [arch=amd64] http://mariadb.mirror.globo.tech/repo/10.11/ubuntu jammy main' -y
sudo apt update
sudo apt install -y mariadb-server mariadb-client
sudo systemctl start mariadb
sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD'; FLUSH PRIVILEGES;"

# 3. Setup Node.js (18+)
echo "🌐 Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 4. Install Bench CLI
echo "🛠️ Installing Bench CLI..."
pip3 install frappe-bench --break-system-packages

# 5. Initialize Bench
echo "🏗️ Initializing Bench..."
if [ -d "$BENCH_DIR" ]; then rm -rf "$BENCH_DIR"; fi
bench init "$BENCH_DIR" --frappe-branch version-15
cd "$BENCH_DIR"

# 6. Create Site and setup
echo "🏗️ Creating site: $SITE_NAME..."
bench new-site "$SITE_NAME" --db-root-password "$DB_ROOT_PASSWORD" --admin-password "$DB_ROOT_PASSWORD"

# 7. Install our App (Assume it's in ~/OpenClawWorkspace/dev-workspace/projects/user_growth_analytics)
echo "📥 Installing app: $APP_NAME..."
bench get-app "$APP_NAME" ~/OpenClawWorkspace/dev-workspace/projects/"$APP_NAME"
bench --site "$SITE_NAME" install-app "$APP_NAME"

# 8. Setup Mock Data
echo "📊 Populating mock data..."
bench --site "$SITE_NAME" execute "$APP_NAME.fixtures.create_mock_data.create_mock_data"

echo "✅ Setup Complete!"
echo "👉 Run 'cd $BENCH_DIR && bench start' to launch your development environment."
