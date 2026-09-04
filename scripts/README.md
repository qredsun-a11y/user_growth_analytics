# Frappe 一键安装脚本

本目录包含两个 WSL2 环境下的 Frappe v15 自动安装脚本。

---

## 脚本对比

| 特性 | `install.sh` | `setup_frappe_dev.sh` |
|------|-------------|------------------------|
| 复杂度 | 简单直接 | 完整健壮 |
| 错误处理 | 无 | 自动回滚 |
| 彩色日志 | 无 | ✅ |
| 参数自定义 | ❌ | ✅ (路径、密码、版本) |
| WSL 检测 | ❌ | ✅ |
| 交互式确认 | ❌ | ✅ |
| 适合场景 | 新手快速尝试 | 正式开发环境 |

---

## 使用方法

### 方式 A：一键快速安装（推荐新手）
```bash
# 下载并运行（默认参数）
chmod +x setup_frappe_dev.sh
./setup_frappe_dev.sh
```

### 方式 B：自定义参数
```bash
# 指定自定义路径和密码
BENCH_DIR=/home/user/my_bench \
DB_ROOT_PASSWORD=mysecurepass \
SITE_NAME=mydemo.local \
./setup_frappe_dev.sh -y
```

### 方式 C：命令行参数
```bash
# 查看帮助
./setup_frappe_dev.sh -h

# 使用自定义参数
./setup_frappe_dev.sh \
  --bench-dir ~/my-bench \
  --site mysite.local \
  --db-pass SuperSecret123 \
  --frappe-branch version-15 \
  -y
```

---

## 环境变量覆盖

以下环境变量可覆盖默认值：
- `BENCH_DIR` - Bench 安装目录（默认：`~/frappe-bench`）
- `DB_ROOT_PASSWORD` - MariaDB root 密码（默认：`admin`）
- `SITE_NAME` - 站点名称（默认：`demo.localhost`）
- `FRAPPE_BRANCH` - Frappe 版本分支（默认：`version-15`）
- `NODE_VERSION` - Node.js 版本（默认：`18`）

---

## 安装后访问

脚本完成后，执行以下命令启动服务：
```bash
cd $BENCH_DIR
bench start
```

在 Windows 浏览器中打开：
- **Desk UI**：http://localhost:8000/app
- **用户服务单据**：http://localhost:8000/app/user-service-record
- **增长报表**：http://localhost:8000/app/query-report/User%20Growth%20Report
- **数据大屏**：http://localhost:8000/user-growth-dashboard

**默认账号**：Administrator / `admin`（或你设置的密码）

---

## 失败排查

### 1. 网络问题
```bash
# 配置国内镜像
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
```

### 2. MariaDB 启动失败
```bash
sudo systemctl status mariadb
sudo journalctl -xeu mariadb
```

### 3. Redis 连接被拒
```bash
sudo systemctl restart redis-server
redis-cli ping
```

### 4. 检查 WSL 版本
```powershell
# 在 PowerShell 中执行
wsl.exe -l -v
# 确认 VERSION 列是 2
```

---

## 手动安装（如脚本失败）

如果脚本有问题，可手动执行：
```bash
# 1. 更新系统
sudo apt update && sudo apt upgrade -y

# 2. 安装依赖
sudo apt install -y git curl python3-pip python3-venv python3-dev \
  libmysqlclient-dev libssl-dev redis-server wkhtmltopdf \
  build-essential libmariadb-dev mariadb-server mariadb-client

# 3. 配置 MariaDB
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'admin';"

# 4. 安装 Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 5. 安装 Bench
pip3 install frappe-bench

# 6. 初始化并安装 App
bench init ~/frappe-bench --frappe-branch version-15
cd ~/frappe-bench
bench new-site demo.localhost --db-root-password admin
bench get-app /path/to/user_growth_analytics
bench --site demo.localhost install-app user_growth_analytics
bench --site demo.localhost execute user_growth_analytics.fixtures.create_mock_data.create_mock_data
```

---

## 注意事项

1. **必须在 WSL2 中运行**，WSL1 不支持
2. **不要以 root 身份运行**，除非必要
3. **首次安装需要约 15-30 分钟**，取决于网络速度
4. **密码请修改默认值**，尤其是生产部署前
5. **App 源代码必须存在**于 `APP_SOURCE_DIR`（默认：`/root/OpenClawWorkspace/dev-workspace/projects/user_growth_analytics`）

---

## 许可证

MIT License - 可自由修改和分发。
