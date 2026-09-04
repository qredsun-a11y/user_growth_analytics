# 🚀 Frappe 一键安装 - 快速开始

## ⚡ 3 分钟快速安装

```bash
# 1. 进入脚本目录
cd /root/OpenClawWorkspace/dev-workspace/projects/user_growth_analytics/scripts

# 2. 运行增强版脚本（自动处理 Node 24 + Python 3.12 + Root 用户）
./install_v2.sh -y

# 3. 启动服务
cd ~/frappe-bench && bench start
```

---

## 🔧 脚本对比

| 脚本 | 适合场景 | 特性 |
|------|----------|------|
| **`install_v2.sh`** | ⭐ **推荐使用** | 兼容 Node 24/Python 3.12/Root 用户 |
| `setup_frappe_dev.sh` | 普通用户环境 | 功能完整但需手动处理版本 |
| `install.sh` | 简单测试 | 最简版本，可能遇到兼容问题 |

---

## 📋 修复的问题

### 问题 1: Node.js 24.x 兼容性
```bash
# 原问题：Node 24 可能导致 Frappe 报错
# 解决方案：使用 nvm 管理多版本

# 脚本自动执行：
nvm install 18
nvm alias default 18

# 验证
node --version  # v18.x.x
```

### 问题 2: Python 3.12.x 权限问题
```bash
# 原问题：pip3 默认禁止系统级安装
# 解决方案：添加 --break-system-packages

# 脚本自动执行：
pip3 install --break-system-packages frappe-bench
```

### 问题 3: Root 用户运行风险
```bash
# 原问题：root 运行可能导致权限混乱
# 解决方案：允许运行 + 自动创建普通用户

# 脚本会自动询问：
# "Create a 'frappe' user for future use? [Y/n]"
```

---

## 🎯 自定义安装

### 方式 1: 命令行参数
```bash
./install_v2.sh \
  --db-pass MySecurePass123 \
  --site myapp.local \
  --node-version 18 \
  -y
```

### 方式 2: 环境变量
```bash
export DB_ROOT_PASSWORD=***
export BENCH_DIR=/opt/bench
export NODE_TARGET_VERSION=18

./install_v2.sh -y
```

---

## ✅ 安装后验证

```bash
# 1. 检查环境
node --version      # v18.x.x (通过 nvm)
python3 --version   # 3.12.x
bench version

# 2. 检查服务
sudo systemctl status mariadb
redis-cli ping      # PONG

# 3. 访问应用
# http://localhost:8000/app
# 账号: Administrator / admin
```

---

## 🔐 安全建议

### 开发环境（当前）
- 可以继续使用 root
- 密码使用简单值
- 仅限本地访问

### 生产环境（未来）
```bash
# 切换到普通用户
su - frappe
cd ~/frappe-bench
bench setup production
```

---

## 📚 详细文档

- [完整使用说明](./USAGE.md)
- [更新日志](./CHANGELOG.md)
- [App 项目文档](../README.md)

---

## ❓ 常见问题

**Q: 想回退到 Node 24？**
```bash
nvm use 24
nvm alias default 24
```

**Q: 忘记密码？**
```bash
sudo mysql -u root -padmin -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'newpass';"
```

**Q: 重新安装？**
```bash
rm -rf ~/frappe-bench
./install_v2.sh -y
```
