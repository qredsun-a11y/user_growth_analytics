# Frappe 一键安装脚本使用指南

## 📋 问题诊断与解决方案

### 问题 1: Node.js 24.x 兼容性

**现状**：
- 系统已安装 Node 24.18.0
- Frappe v15 官方推荐：Node 18 LTS 或 20 LTS
- Node 24 可能包含 breaking changes

**解决方案**：
```bash
# 使用 nvm 安装 Node 18（脚本自动执行）
nvm install 18
nvm use 18
nvm alias default 18

# 验证
node --version  # 应显示 v18.x.x
```

**为什么这样做**：
- ✅ 保留系统 Node 24 不影响其他应用
- ✅ Frappe 使用稳定的 Node 18 LTS
- ✅ 可随时切换：`nvm use 24` 或 `nvm use 18`

---

### 问题 2: Python 3.12.x 兼容性

**现状**：
- Python 3.12 较新，部分包需要特殊处理
- pip 默认禁止在系统级安装（PEP 668）

**解决方案**：
```bash
# 使用 --break-system-packages 参数
pip3 install --break-system-packages frappe-bench

# 或使用 virtualenv（更推荐）
python3 -m venv frappe-env
source frappe-env/bin/activate
pip install frappe-bench
```

**脚本中的处理**：
- 自动添加 `--break-system-packages` 参数
- 使用 `python3-venv` 创建隔离环境
- 更新 apt 源中的 Python 依赖

---

### 问题 3: Root 用户运行

**现状**：
- 当前以 root 身份运行
- Bench/Frappe 不建议以 root 运行（安全风险）

**解决方案**：
```bash
# 方案 A：使用脚本创建的 frappe 用户
sudo useradd -m -s /bin/bash -G sudo frappe
su - frappe
cd ~/frappe-bench
bench start

# 方案 B：继续使用 root（开发环境可接受）
# 但生产部署前必须切换到普通用户
```

**脚本行为**：
- ✅ 允许 root 运行安装脚本
- ⚠️ 明确警告安全风险
- 🆕 自动询问是否创建 `frappe` 用户

---

## 🚀 推荐使用脚本

### 推荐使用 `install_v2.sh`

| 特性 | `install.sh` (v1.0) | `install_v2.sh` (v1.1) |
|------|---------------------|------------------------|
| Node 24 兼容 | ❌ 可能失败 | ✅ 使用 nvm 管理 |
| Python 3.12 | ⚠️ 权限警告 | ✅ 自动处理 |
| Root 用户 | ❌ 报错退出 | ✅ 允许 + 创建普通用户 |
| 错误回滚 | ❌ 无 | ✅ 有 |
| 彩色日志 | ❌ 无 | ✅ 有 |

---

## 📝 安装步骤

### 快速安装（推荐）

```bash
# 1. 进入脚本目录
cd /root/OpenClawWorkspace/dev-workspace/projects/user_growth_analytics/scripts

# 2. 执行 v2 脚本（自动处理所有兼容性问题）
./install_v2.sh

# 3. 或跳过确认直接运行
./install_v2.sh -y
```

### 自定义参数

```bash
# 指定密码和路径
./install_v2.sh \
  --db-pass MySecurePassword123 \
  --site myapp.local \
  --node-version 18 \
  -y
```

### 环境变量覆盖

```bash
# 使用环境变量（无需每次输入参数）
export DB_ROOT_PASSWORD=***
export BENCH_DIR=/opt/bench
export NODE_TARGET_VERSION=18

./install_v2.sh -y
```

---

## ✅ 安装后验证

### 1. 检查 Node 版本
```bash
node --version  # 应该是 v18.x.x (通过 nvm)
# 如果显示 v24.x.x，运行:
nvm use 18
```

### 2. 检查 Python 版本
```bash
python3 --version  # 3.12.x 正常
```

### 3. 检查服务状态
```bash
# MariaDB
sudo systemctl status mariadb

# Redis
redis-cli ping  # 应返回 PONG

# Bench
bench version
```

### 4. 启动开发服务器
```bash
cd ~/frappe-bench

# 方式 A：继续以 root 运行（仅开发环境）
bench start

# 方式 B：切换到 frappe 用户（推荐）
su - frappe
cd ~/frappe-bench
bench start
```

---

## 🔧 常见问题

### Q1: nvm 安装后 node 命令不可用
```bash
# 解决方案
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use 18
```

### Q2: 以 root 运行 bench 时报权限错误
```bash
# 解决方案：修改文件权限
sudo chown -R root:root ~/frappe-bench
sudo find ~/frappe-bench -type d -exec chmod 755 {} \;
sudo find ~/frappe-bench -type f -exec chmod 644 {} \;
```

### Q3: MariaDB 连接被拒绝
```bash
# 检查密码是否正确
sudo mysql -u root -padmin -e "SELECT 1"

# 重新设置密码
sudo mysql -u root
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

### Q4: Redis 未启动
```bash
sudo systemctl start redis-server
sudo systemctl enable redis-server
redis-cli ping  # 验证
```

---

## 📊 环境对比

| 项目 | 安装前 | 安装后 |
|------|--------|--------|
| Node.js | 24.18.0 | 18.x (nvm) + 24.x (系统) |
| Python | 3.12.3 | 3.12.3 + 虚拟环境 |
| MariaDB | 未安装 | 10.11 ✓ |
| Redis | 未安装 | 7.x ✓ |
| Bench | 未安装 | 最新版 ✓ |
| Frappe | 未安装 | version-15 ✓ |
| 普通用户 | 无 | frappe ✓ (可选) |

---

## 🔒 安全建议

### 开发环境（当前）
- 可以接受 root 运行
- 密码使用简单值（如 `admin`）
- 网络仅限本地

### 生产环境（未来）
- 必须创建并使用普通用户（如 `frappe`）
- 使用强密码
- 配置防火墙
- 启用 HTTPS

```bash
# 创建生产用户示例
sudo adduser frappe
sudo usermod -aG sudo frappe
sudo -i -u frappe
cd ~/frappe-bench
bench setup production
```

---

## 📚 相关文档

- [Frappe 官方文档](https://frappeframework.com/docs)
- [nvm GitHub](https://github.com/nvm-sh/nvm)
- [本项目 App 文档](../README.md)
- [安装脚本更新日志](./CHANGELOG.md)
