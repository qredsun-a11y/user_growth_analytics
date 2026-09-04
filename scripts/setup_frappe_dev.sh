#!/bin/bash
# ============================================================
# Frappe v15 Development Environment One-Click Setup for WSL2
# 支持参数、彩色日志、错误回滚、环境检测
# ============================================================

set -euo pipefail

# ────────────────────── 配置变量 ──────────────────────
readonly SCRIPT_VERSION="1.0.0"
readonly APP_NAME="user_growth_analytics"
readonly DEFAULT_BENCH_DIR="$HOME/frappe-bench"
readonly DEFAULT_DB_PASS="admin"
readonly DEFAULT_SITE="demo.localhost"
readonly APP_SOURCE_DIR="/root/OpenClawWorkspace/dev-workspace/projects/user_growth_analytics"

# 可通过环境变量或参数覆盖
BENCH_DIR="${BENCH_DIR:-$DEFAULT_BENCH_DIR}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-$DEFAULT_DB_PASS}"
SITE_NAME="${SITE_NAME:-$DEFAULT_SITE}"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"
NODE_VERSION="${NODE_VERSION:-18}"
PYTHON_VERSION="${PYTHON_VERSION:-3.10}"

# ────────────────────── 颜色 & 工具函数 ──────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[⚠]${NC} $*"; }
log_error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
log_step()    { echo -e "\n${BLUE}▶${NC} $*"; }

show_banner() {
  cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║  Frappe v15 Development Environment Auto-Installer (WSL2)   ║
║  App: user_growth_analytics                                  ║
║  Version: 1.0.0                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
}

# 检查是否在 WSL2 中运行
check_wsl2() {
  log_step "Checking WSL environment..."
  if ! grep -qi microsoft /proc/version 2>/dev/null; then
    log_warn "Not running inside WSL. Script still works but may need manual adjustments."
    return 0
  fi

  if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -q "WSL2" /proc/version 2>/dev/null; then
    log_success "WSL 2 detected: ${WSL_DISTRO_NAME:-Ubuntu}"
  else
    log_error "WSL 1 detected. Please upgrade: wsl --set-version <distro> 2"
    exit 1
  fi
}

# 检查是否为 root（不建议用 root 运行）
check_not_root() {
  if [[ $EUID -eq 0 ]]; then
    log_warn "Running as root. This works but not recommended for Frappe development."
    read -rp "Continue anyway? [y/N] " -n 1 ans
    echo
    [[ $ans =~ ^[Yy]$ ]] || exit 1
  fi
}

# 显示配置摘要
show_config() {
  cat <<EOF
Configuration:
  Bench Directory : $BENCH_DIR
  Site Name       : $SITE_NAME
  DB Root Password: $DB_ROOT_PASSWORD
  Frappe Branch   : $FRAPPE_BRANCH
  Node Version    : $NODE_VERSION
  App Source      : $APP_SOURCE_DIR
EOF
  echo
  read -rp "Proceed with installation? [Y/n] " -n 1 confirm
  echo
  [[ $confirm =~ ^[Nn]$ ]] && exit 0
}

# 清理函数（失败时回滚）
cleanup_on_error() {
  log_error "Installation failed. Cleaning up..."
  cd "$HOME" 2>/dev/null || true
  [[ -d "$BENCH_DIR" ]] && rm -rf "$BENCH_DIR"
  exit 1
}
trap cleanup_on_error ERR

# ────────────────────── 安装步骤 ──────────────────────
install_system_deps() {
  log_step "Installing system dependencies..."
  export DEBIAN_FRONTEND=noninteractive
  sudo apt update -qq
  sudo apt install -y -qq \
    git curl wget python3-pip python3-venv python3-dev \
    libmysqlclient-dev libssl-dev libffi-dev libjpeg-dev libzip-dev \
    redis-server xvfb libfontconfig wkhtmltopdf \
    build-essential libmariadb-dev software-properties-common \
    python3.10-venv 2>/dev/null || python3-venv
  log_success "System dependencies installed"
}

setup_mariadb() {
  log_step "Setting up MariaDB 10.11..."
  sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc' 2>/dev/null
  sudo add-apt-repository 'deb [arch=amd64] http://mariadb.mirror.globo.tech/repo/10.11/ubuntu jammy main' -y
  sudo apt update -qq
  sudo apt install -y -qq mariadb-server mariadb-client
  sudo systemctl start mariadb
  sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD'; FLUSH PRIVILEGES;"
  log_success "MariaDB configured (root pwd: $DB_ROOT_PASSWORD)"
}

setup_nodejs() {
  log_step "Installing Node.js $NODE_VERSION..."
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash -
  sudo apt install -y -qq nodejs
  log_success "Node.js $(node --version) ready"
}

install_bench_cli() {
  log_step "Installing Bench CLI..."
  pip3 install --user --break-system-packages frappe-bench --quiet
  export PATH="$HOME/.local/bin:$PATH"
  log_success "Bench CLI installed"
}

init_bench() {
  log_step "Initializing Frappe Bench ($FRAPPE_BRANCH)..."
  if [[ -d "$BENCH_DIR" ]]; then
    log_warn "Bench directory exists. Removing..."
    rm -rf "$BENCH_DIR"
  fi
  bench init "$BENCH_DIR" --frappe-branch "$FRAPPE_BRANCH" --skip-redis-config-generation --verbose
  cd "$BENCH_DIR"
  log_success "Bench initialized at $BENCH_DIR"
}

create_site() {
  log_step "Creating site: $SITE_NAME..."
  bench new-site "$SITE_NAME" \
    --db-root-password "$DB_ROOT_PASSWORD" \
    --admin-password "$DB_ROOT_PASSWORD" \
    --mariadb-root-host "localhost" \
    --no-mariadb-socket
  bench use "$SITE_NAME"
  log_success "Site created and set as default"
}

install_app() {
  log_step "Installing app: $APP_NAME..."
  if [[ ! -d "$APP_SOURCE_DIR" ]]; then
    log_error "App source not found at $APP_SOURCE_DIR"
    exit 1
  fi
  bench get-app "$APP_NAME" "$APP_SOURCE_DIR"
  bench --site "$SITE_NAME" install-app "$APP_NAME"
  log_success "App installed"
}

populate_mock_data() {
  log_step "Populating mock data..."
  bench --site "$SITE_NAME" execute "$APP_NAME.fixtures.create_mock_data.create_mock_data"
  log_success "Mock data created (30 records)"
}

final_message() {
  cat <<EOF

${GREEN}╔══════════════════════════════════════════════════════════════╗
║  🎉 Installation Complete!                                  ║
╚══════════════════════════════════════════════════════════════╝${NC}

Next steps:
  1. Start development server:
     ${BLUE}cd $BENCH_DIR && bench start${NC}

  2. Access in browser (Windows):
     ${BLUE}http://localhost:8000${NC}

  3. Key URLs:
     • Desk (Admin UI)        : http://localhost:8000/app
     • User Service Records   : http://localhost:8000/app/user-service-record
     • Growth Report          : http://localhost:8000/app/query-report/User%20Growth%20Report
     • Growth Dashboard       : http://localhost:8000/user-growth-dashboard

  4. Default credentials:
     • Administrator / $DB_ROOT_PASSWORD

Useful commands:
  • Bench console     : bench --site $SITE_NAME console
  • Run migrations    : bench --site $SITE_NAME migrate
  • Backup            : bench --site $SITE_NAME backup --with-files
  • Re-generate mock  : bench --site $SITE_NAME execute $APP_NAME.fixtures.create_mock_data.create_mock_data

EOF
}

# ────────────────────── 主流程 ──────────────────────
main() {
  show_banner
  check_wsl2
  check_not_root
  show_config

  install_system_deps
  setup_mariadb
  setup_nodejs
  install_bench_cli
  init_bench
  create_site
  install_app
  populate_mock_data
  final_message
}

# ────────────────────── 参数解析 ──────────────────────
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  -b, --bench-dir DIR      Bench directory (default: ~/frappe-bench)
  -s, --site NAME          Site name (default: demo.localhost)
  -p, --db-pass PASS       MariaDB root password (default: admin)
  -f, --frappe-branch BR   Frappe branch (default: version-15)
  -n, --node-version VER   Node.js version (default: 18)
  -a, --app-dir DIR        App source directory
  -h, --help               Show this help
  -y, --yes                Skip confirmation

Environment variables:
  BENCH_DIR, DB_ROOT_PASSWORD, SITE_NAME, FRAPPE_BRANCH, NODE_VERSION

Examples:
  $0 --bench-dir /home/user/my-bench --site test.local
  $0 -y  # Non-interactive with defaults
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -b|--bench-dir)     BENCH_DIR="$2"; shift 2 ;;
      -s|--site)          SITE_NAME="$2"; shift 2 ;;
      -p|--db-pass)       DB_ROOT_PASSWORD="$2"; shift 2 ;;
      -f|--frappe-branch) FRAPPE_BRANCH="$2"; shift 2 ;;
      -n|--node-version)  NODE_VERSION="$2"; shift 2 ;;
      -a|--app-dir)       APP_SOURCE_DIR="$2"; shift 2 ;;
      -y|--yes)           exec 0</dev/null; show_config() { :; }; shift ;;
      -h|--help)          usage; exit 0 ;;
      *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
}

# ────────────────────── 入口 ──────────────────────
parse_args "$@"
main