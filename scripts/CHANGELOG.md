# 安装脚本更新日志

## v1.1.0 (2026-09-03) - 适配 Node 24 + Python 3.12 + Root 用户

### 修复的问题

#### 1. Node.js 24 兼容性
**问题**：系统已安装 Node 24.18.0，但 Frappe v15 推荐 18/20 LTS，高版本可能存在 breaking changes。

**解决方案**：
- 使用 `nvm` (Node Version Manager) 安装 Node 18 LTS 作为 Frappe 的运行时
- 保留系统 Node 24 不变，避免影响其他应用
- 通过 nvm 切换版本：`nvm use 18` 或 `nvm alias default 18`

```bash
# 脚本自动执行的命令
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 18
nvm alias default 18
```

**验证**：
```bash
node --version  # 应显示 v18.x.x (if using nvm)
# 或检查所有版本
nvm ls
```

---

#### 2. Python 3.12 兼容性
**问题**：Python 3.12 是较新版本，某些依赖包（如 pycares、bcrypt）可能需要特殊处理。

**解决方案**：
- 安装时添加 `--break-system-packages` 参数绕过 pip 警告
- 使用 `python3-venv` 隔离环境（Bench 默认会创建）
- 更新 apt 源中的 Python 包

```bash
# 关键安装命令
pip3 install --user --break-system-packages frappe-bench
```

---

#### 3. Root 用户运行风险
**问题**：当前以 root 用户身份运行，存在安全风险且可能导致文件权限问题。

**解决方案**：
- **允许 root 运行安装**（方便开发环境快速搭建）
- **自动创建 `frappe` 用户**供后续使用
- **明确警告** root 用户不应在 production 中使用

```bash
# 脚本会提示是否创建用户
sudo useradd -m -s /bin/bash -G sudo frappe
```

**后续使用建议**：
```bash
# 切换到普通用户
su - frappe
cd ~/frappe-bench
bench start
```

---

### 环境变量支持

| 变量 | 说明 | 示例 |
|------|------|------|
| `NODE_TARGET_VERSION` | 通过 nvm 安装的 Node 版本 | `NODE_TARGET_VERSION=20` |
| `DB_ROOT_PASSWORD` | MariaDB root 密码 | `DB_ROOT_PASSWORD=mypassword` |
| `BENCH_DIR` | Bench 安装路径 | `BENCH_DIR=/opt/bench` |

---

### 使用示例

```bash
# 默认安装（自动处理 Node/Python/root）
./install_v2.sh

# 指定 Python 3.12 友好的配置
./install_v2.sh --node-version 18 -y

# 自定义路径和密钥
NODE_TARGET_VERSION=18 \
DB_ROOT_PASSWORD=*** \
BENCH_DIR=/home/frappe/bench \
./install_v2.sh -y
```

---

## v1.0.0 (2026-09-03) - 初始版本

### 已知限制
- 未处理 Node 24+ 版本兼容性问题
- 未处理 Python 3.12 的 pip 权限警告
- 仅支持非 root 用户运行

---

## 故障排查

### 问题 1: nvm 安装后 node 命令不可用
```bash
# 解决：手动加载 nvm
source ~/.nvm/nvm.sh
nvm install 18
nvm use 18
```

### 问题 2: MariaDB 连接失败
```bash
# 检查服务状态
sudo systemctl status mariadb
# 或尝试直接启动
sudo service mariadb start
```

### 问题 3: Bench init 超时
```bash
# 网络问题，使用国内镜像
pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
```

---

## 版本对照表

| 组件 | 原版本 (v1.0.0) | 当前版本 (v1.1.0) |
|------|-----------------|-------------------|
| Node.js 管理 | 系统版本 24 | nvm 管理的 18 LTS |
| Python 安装 | pip3 直接安装 | pip3 + `--break-system-packages` |
| Root 用户 | 报错退出 | 允许运行 + 创建普通用户 |
| 交互式确认 | 无 | 有 |
