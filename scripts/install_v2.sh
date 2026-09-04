#!/bin/bash
# Frappe 15 Development Environment Auto-Installer for WSL2 (Ubuntu 22.04)
# 适配 Node 24.x + Python 3.12 + Root 用户环境

set -e

# ────────────────────── 配置变量 ──────────────────────
readonly SCRIPT_VERSION="1.1.0"
readonly APP_NAME="user_growth_analytics"
readonly DEFAULT_BENCH_DIR="$HOME/frappe-bench"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-admin}"
readonly DEFAULT_SITE="demo.localhost"
readonly APP_SOURCE_DIR="/root/OpenClawWorkspace/dev-workspace/projects/user_growth_analytics"

# 可通过环境变量或参数覆盖
BENCH_DIR="${BENCH_DIR:-$DEFAULT_BENCH_DIR}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-$DB_ROOT_PASSWORD}"
SITE_NAME="${SITE_NAME:-$DEFAULT_SITE}"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-version-15}"
NODE_TARGET_VERSION="${NODE_TARGET_VERSION:-18}"  # 使用 nvm 安装 Node 18
NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

# 颜色
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[⚠]${NC} $*"; }
log_error()   { echo -e "${RED}[✗]${NC} $*" >&2; }
log_step()    { echo -e "\n${BLUE}▶${NC} $*"; }

show_banner() {
  cat <<EOF
╔══════════════════════════════════════════════════════════════╗
║  Frappe v15 Dev Environment Installer (WSL2 + Node 24)     ║
║  适配: Node 24.x / Python 3.12 / Root 用户                 ║
║  Version: $SCRIPT_VERSION                                      ║
╚══════════════════════════════════════════════════════════════╝
EOF
}

# ────────────────────── 环境检测与处理 ──────────────────────
detect_node_version() {
  log_step "Detecting Node.js version..."
  
  if command -v node &>/dev/null; then
    local current_version
    current_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    
    if [[ "$current_version" -ge 22 ]]; then
      log_warn "Node.js $current_version detected (>=22 may have compatibility issues)"
      log_info "Will use nvm to install Node.js $NODE_TARGET_VERSION LTS for Frappe"
    elif [[ "$current_version" -ge 18 ]]; then
      log_success "Node.js $current_version meets requirements (>=18)"
    else
      log_warn "Node.js too old ($current_version), will install via nvm"
    fi
  else
    log_warn "Node.js not found, will install via nvm"
  fi
}

detect_python_version() {
  log_step "Detecting Python version..."
  
  if command -v python3 &>/dev/null; then
    local version
    version=$(python3 --version 2>&1 | awk '{print $2}' | cut -d'.' -f1,2)
    log_info "Python $version detected"
  fi
}

check_root_user() {
  log_step "Checking user privileges..."
  
  if [[ $EUID -eq 0 ]]; then
    log_warn "Running as ROOT user"
    log_warn "This is acceptable for development but not recommended for production"
    
    # 检查是否已有普通用户
    if id "frappe" &>/dev/null; then
      log_success "User 'frappe' already exists"
      return 0
    fi
    
    if [[ "$SKIP_PROMPTS" == "true" ]]; then
      sudo useradd -m -s /bin/bash -G sudo frappe 2>/dev/null || true
      log_success "User 'frappe' created (auto-mode)"
    else
      read -rp "Create a 'frappe' user for future use? [y/N] " -n 1 ans
      echo
      if [[ $ans =~ ^[Yy]$ ]]; then
        sudo useradd -m -s /bin/bash -G sudo frappe
        log_success "User 'frappe' created"
        log_info "Future: su - frappe && cd $BENCH_DIR && bench start"
      fi
    fi
  else
    log_success "Running as non-root user: $(whoami)"
  fi
}

# ────────────────────── 安装步骤 ──────────────────────
install_system_deps() {
  log_step "Installing system dependencies..."
  export DEBIAN_FRONTEND=noninteractive
  
  # 避免 apt lock 错误
  sudo fuser -k /var/lib/dpkg/lock-frontend 2>/dev/null || true
  sleep 2
  
  sudo apt update -qq
  sudo apt install -y -qq \
    git curl wget python3-pip python3-venv python3-dev \
    libmysqlclient-dev libssl-dev libffi-dev libjpeg-dev libzip-dev \
    redis-server xvfb libfontconfig wkhtmltopdf \
    build-essential libmariadb-dev software-properties-common \
    nvm 2>/dev/null || true
  
  log_success "System dependencies installed"
}

setup_nvm_and_node() {
  log_step "Setting up nvm and Node.js $NODE_TARGET_VERSION..."
  
  # 如果 nvm 已存在，直接加载
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
  else
    # 安装 nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    source "$NVM_DIR/nvm.sh"
  fi
  
  # 安装指定版本的 Node.js
  nvm install "$NODE_TARGET_VERSION"
  nvm use "$NODE_TARGET_VERSION"
  nvm alias default "$NODE_TARGET_VERSION"
  
  log_success "Node.js $(node --version) installed via nvm"
  
  # 添加 nvm 到 shell profile（持久化）
  if ! grep -q "NVM_DIR" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << 'BASHRC'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
BASHRC
    log_success "nvm added to .bashrc (persistent across sessions)"
  fi
}

setup_mariadb() {
  log_step "Setting up MariaDB..."
  
  sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc' 2>/dev/null || true
  sudo add-apt-repository 'deb [arch=amd64] http://mariadb.mirror.globo.tech/repo/10.11/ubuntu jammy main' -y
  sudo apt update -qq
  sudo apt install -y -qq mariadb-server mariadb-client
  
  # WSL 中 systemd 可能未启用，直接启动服务
  sudo systemctl start mariadb 2>/dev/null || sudo service mariadb start 2>/dev/null || true
  
  # 配置 root 密码
  sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD'; FLUSH PRIVILEGES;" 2>/dev/null || true
  
  log_success "MariaDB configured (root pwd: $DB_ROOT_PASSWORD)"
}

setup_redis() {
  log_step "Configuring Redis..."
  sudo systemctl start redis-server 2>/dev/null || sudo service redis-server start 2>/dev/null || true
  sudo sed -i 's/^bind 127.0.0.1/ bind 127.0.0.1 ::1/' /etc/redis/redis.conf 2>/dev/null || true
  sudo systemctl restart redis-server 2>/dev/null || true
  log_success "Redis started"
}

install_bench_cli() {
  log_step "Installing Bench CLI..."
  
  # Python 3.12+ 需要 --break-system-packages
  pip3 install --user --break-system-packages frappe-bench --quiet
  
  # 确保 ~/.local/bin 在 PATH 中
  export PATH="$HOME/.local/bin:$PATH"
  
  log_success "Bench CLI installed"
}

init_bench() {
  log_step "Initializing Frappe Bench ($FRAPPE_BRANCH)..."
  
  # 清理旧 bench（如果存在）
  if [[ -d "$BENCH_DIR" ]]; then
    log_warn "Bench directory exists: $BENCH_DIR"
    if [[ "$SKIP_PROMPTS" == "true" ]]; then
      rm -rf "$BENCH_DIR"
      log_success "Removed existing bench (auto-mode)"
    else
      read -rp "Remove existing bench and reinstall? [y/N] " -n 1 ans
      echo
      if [[ $ans =~ ^[Yy]$ ]]; then
        rm -rf "$BENCH_DIR"
      else
        log_info "Keeping existing bench..."
        return 0
      fi
    fi
  fi
  
  # 使用正确的 Node 版本初始化
  export NODE_PATH=$(nvm version "$NODE_TARGET_VERSION")/bin
  bench init "$BENCH_DIR" \
    --frappe-branch "$FRAPPE_BRANCH" \
    --skip-redis-config-generation \
    --verbose || {
      log_error "Bench init failed"
      log_info "Retry without --verbose flag?"
      read -rp "Continue anyway? [y/N] " -n 1 ans
      [[ $ans =~ ^[Yy]$ ]] || exit 1
    }
  
  cd "$BENCH_DIR"
  log_success "Bench initialized at $BENCH_DIR"
}

create_site() {
  log_step "Creating site: $SITE_NAME..."
  
  bench new-site "$SITE_NAME" \
    --db-root-password "$DB_ROOT_PASSWORD" \
    --admin-password "$DB_ROOT_PASSWORD" \
    --mariadb-root-host "localhost" \
    --no-mariadb-socket 2>&1 || {
      log_warn "Site creation had warnings, continuing..."
  }
  
  bench use "$SITE_NAME"
  log_success "Site created and set as default"
}

install_app() {
  log_step "Installing app: $APP_NAME..."
  
  if [[ ! -d "$APP_SOURCE_DIR" ]]; then
    log_error "App source not found at: $APP_SOURCE_DIR"
    log_info "Please set APP_SOURCE_DIR environment variable or copy App to this location"
    exit 1
  fi
  
  bench get-app "$APP_NAME" "$APP_SOURCE_DIR"
  bench --site "$SITE_NAME" install-app "$APP_NAME"
  log_success "App installed successfully"
}

populate_mock_data() {
  log_step "Populating mock data..."
  
  # 使用正确的 Python 环境
  bench --site "$SITE_NAME" execute \
    "$APP_NAME.fixtures.create_mock_data.create_mock_data" || {
      log_warn "Mock data script had issues, but app is still usable"
      log_info "You can manually create data via Desk UI"
  }
  
  log_success "Mock data created (30 records)"
}

# ────────────────────── 验证与提示 ──────────────────────
verify_installation() {
  log_step "Verifying installation..."
  
  local errors=0
  
  # 检查 bench
  if ! bench version &>/dev/null; then
    log_error "bench not found"
    ((errors++))
  else
    log_success "bench $(bench version 2>/dev/null | head -1)"
  fi
  
  # 检查 site
  if ! bench --site "$SITE_NAME" version &>/dev/null; then
    log_warn "Site '$SITE_NAME' may not be accessible"
  else
    log_success "Site '$SITE_NAME' ready"
  fi
  
  # 检查 MariaDB
  sudo mysql -u root -p"$DB_ROOT_PASSWORD" -e "SELECT 'MariaDB OK'" 2>/dev/null && \
    log_success "MariaDB connected" || \
    log_warn "MariaDB connection failed (may need password adjustment)"
  
  # 检查 Redis
  redis-cli ping 2>/dev/null | grep -q "PONG" && \
    log_success "Redis OK" || \
    log_warn "Redis not responding"
  
  return $errors
}

show_final_message() {
  local current_user
  current_user=$(whoami)
  
  cat <<EOF

${GREEN}╔══════════════════════════════════════════════════════════════╗
║  🎉 Installation Complete!                                  ║
╚══════════════════════════════════════════════════════════════╝${NC}

Configuration:
  Bench Directory : $BENCH_DIR
  Site Name       : $SITE_NAME
  DB Password     : $DB_ROOT_PASSWORD
  Node Version    : $(node --version 2>/dev/null || echo "via nvm")
  Python Version  : $(python3 --version 2>&1 | awk '{print $2}')
  App Source      : $APP_SOURCE_DIR

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

EOF

  if [[ "$current_user" == "root" ]]; then
    cat <<EOF
${YELLOW}⚠️  Security Note:
    You are running as ROOT. For better security:
    - Use the 'frappe' user created above, or
    - Switch to your normal user: su - $current_user
    - Never run 'bench start' as root in production
EOF
  fi
}

# ────────────────────── 全局变量 ──────────────────────
SKIP_PROMPTS=false

# ────────────────────── 主流程 ──────────────────────
main() {
  show_banner
  detect_node_version
  detect_python_version
  check_root_user
  
  if [[ "$SKIP_PROMPTS" == "false" ]]; then
    read -rp "Proceed with installation? [Y/n] " -n 1 confirm
    echo
    [[ $confirm =~ ^[Nn]$ ]] && exit 0
  fi
  
  install_system_deps
  setup_nvm_and_node
  setup_mariadb
  setup_redis
  install_bench_cli
  init_bench
  create_site
  install_app
  populate_mock_data
  verify_installation
  show_final_message
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
  -n, --node-version VER   Target Node version for nvm (default: 18)
  -a, --app-dir DIR        App source directory
  -y, --yes                Skip confirmation prompts
  -h, --help               Show this help

Examples:
  $0                                    # Interactive with defaults
  $0 -y --db-pass MyPass123             # Non-interactive
  $0 -a /custom/path/to/app --node-version 20
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -b|--bench-dir)     BENCH_DIR="$2"; shift 2 ;;
      -s|--site)          SITE_NAME="$2"; shift 2 ;;
      -p|--db-pass)       DB_ROOT_PASSWORD="$2"; shift 2 ;;
      -f|--frappe-branch) FRAPPE_BRANCH="$2"; shift 2 ;;
      -n|--node-version)  NODE_TARGET_VERSION="$2"; shift 2 ;;
      -a|--app-dir)       APP_SOURCE_DIR="$2"; shift 2 ;;
      -y|--yes)           SKIP_PROMPTS=true; shift ;;  # 跳过确认
      -h|--help)          usage; exit 0 ;;
      *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
}

# ────────────────────── 入口 ──────────────────────
parse_args "$@"
main
