# 用户增长数据中心 - 部署问题汇总与解决方案

> 生成时间: 2026-09-04
> 项目路径: /home/frappe/bench/apps/user_growth_analytics

---

## 一、问题概述

在 Frappe v15 环境中部署 `user_growth_analytics` 应用时，遇到了一系列 Python 导入、模块路径、页面路由和样式问题。本文档记录所有问题的根因分析与解决方案。

---

## 二、问题列表与解决方案

### 问题 1: Python 模块导入失败

**现象**: `ModuleNotFoundError: No module named 'user_growth_analytics.user_growth_analytics'`

**根因**: 
- Frappe 的 `modules.txt` 定义了模块名 `user_growth_analytics`
- 代码尝试 `import user_growth_analytics.user_growth_analytics`
- 但 Python 路径中只有 `/home/frappe/bench/apps`，无法解析双层嵌套包

**解决方案**:
```bash
# 1. 确保 modules.txt 在 app 根目录（非嵌套）
# /home/frappe/bench/apps/user_growth_analytics/modules.txt
echo "user_growth_analytics" > modules.txt

# 2. 创建 .pth 文件指向 apps 目录
echo "/home/frappe/bench/apps" > /home/frappe/bench/env/lib/python3.12/site-packages/user_growth_analytics.pth

# 3. 添加根目录 __init__.py
echo '"""User Growth Analytics App."""' > /home/frappe/bench/apps/user_growth_analytics/__init__.py
```

---

### 问题 2: migration_hash 列重复错误

**现象**: `pymysql.err.OperationalError: (1060, "Duplicate column name 'migration_hash'")`

**根因**: Frappe v15 的 `migrate.py` 在添加 `migration_hash` 列时未检查列是否已存在

**解决方案**:
```python
# 手动删除重复列
cd /home/frappe/bench
sudo -u frappe bench --site site1.local console << 'EOF'
import frappe
cols = frappe.db.sql("SHOW COLUMNS FROM tabDocType LIKE 'migration_hash'", as_list=True)
if cols:
    frappe.db.sql_ddl("ALTER TABLE `tabDocType` DROP COLUMN migration_hash")
    print("✅ Dropped migration_hash")
frappe.db.commit()
EOF
```

---

### 问题 3: customer 字段类型错误

**现象**: `DoesNotExistError: DocType Customer not found`

**根因**: 
- DocType JSON 中 `customer` 字段定义为 `Link(Customer)`
- 但系统中不存在 `Customer` DocType
- Mock 数据生成器依赖不存在的 DocType

**解决方案**:
```json
// 修改 user_lifecycle_event.json
{
  "fieldname": "customer",
  "label": "客户",
  "fieldtype": "Data",  // 从 Link 改为 Data
  "reqd": 1,
  "in_list_view": 1
}
```

```python
# 修改 create_mock_data.py
# 移除 Customer DocType 依赖，使用随机 ID
cid = f"CUST-{i+1:04d}"  # 直接生成客户 ID
```

---

### 问题 4: churn_reason_dist 初始化错误

**现象**: `TypeError: 'list' object has no attribute 'most_common'`

**根因**: 
```python
churn_reason_dist = Counter(churn_reasons) if churn_reasons else []  # 错误：条件为 False 时返回 list
```

**解决方案**:
```python
# 修复为始终创建 Counter
churn_reason_dist = Counter(churn_reasons)  # 空列表也会创建空的 Counter
```

---

### 问题 5: API 调用路径错误

**现象**: 前端 JavaScript 调用 API 失败，返回 404 或模块未找到

**根因**: 
- JS 中使用的 API 路径: `user_growth_analytics.api.dashboard.get_dashboard_data`
- 实际模块路径: `user_growth_analytics.user_growth_analytics.api.dashboard.get_dashboard_data`

**解决方案**:
```javascript
// 修正 dashboard.js 中的 API 调用路径
frappe.call({
  method: "user_growth_analytics.user_growth_analytics.api.dashboard.get_dashboard_data",  // 修正路径
  // ...
});

// 或使用原生 fetch（不依赖 Frappe 框架）
fetch('/api/method/user_growth_analytics.user_growth_analytics.api.dashboard.get_dashboard_data', {
  method: 'GET',
  headers: { 'Accept': 'application/json' }
});
```

---

### 问题 6: 大屏页面样式异常（icon icon-lg）

**现象**: 大屏页面出现 Frappe 默认图标、侧边栏、导航栏，布局错乱

**根因**: 
- 使用 `{% extends "templates/web.html" %}` 继承 Frappe Web 模板
- Web 模板包含侧边栏、导航栏、页脚等元素
- 大屏需要全屏独立布局

**解决方案**: 创建独立 HTML 页面，不继承 Frappe 模板

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <title>用户增长指挥中心</title>
  <link rel="stylesheet" href="/assets/user_growth_analytics/css/dashboard.css">
  <script src="https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js"></script>
  <style>
    /* 重置 Frappe 默认样式 */
    body { margin: 0; padding: 0; }
    .navbar, .sidebar, .web-footer, .page-header, .breadcrumbs { display: none !important; }
  </style>
</head>
<body>
  <div class="dashboard-container">
    <!-- 大屏内容 -->
  </div>
  <script src="/assets/user_growth_analytics/js/dashboard.js"></script>
</body>
</html>
```

---

### 问题 7: 页面路由 404

**现象**: 访问 `/user-growth-dashboard` 返回 404

**根因**: 
- Frappe Desk Page（`page/` 目录）需要登录后才能访问
- Web Page（`www/` 目录）需要正确注册路由

**解决方案**: 同时提供两种访问方式

| 方式 | 路径 | 说明 |
|------|------|------|
| Web 页面 | `/user-growth-dashboard` | 无需登录，独立 HTML |
| Desk 页面 | `/desk#usergrowthdashboard` | 需要登录，Frappe 系统页 |

---

## 三、关键文件修改清单

### 3.1 Python 文件

| 文件 | 修改内容 |
|------|----------|
| `api/dashboard.py` | 添加 `allow_guest=True`；修复 `churn_reason_dist` 初始化 |
| `fixtures/create_mock_data.py` | 移除 Customer DocType 依赖；使用随机 ID |
| `doctype/user_lifecycle_event/user_lifecycle_event.json` | `customer` 字段从 `Link` 改为 `Data` |

### 3.2 前端文件

| 文件 | 修改内容 |
|------|----------|
| `public/js/dashboard.js` | 使用 `fetch()` 替代 `frappe.call()`；修正 API 路径 |
| `public/css/dashboard.css` | 深色主题样式（无需修改） |
| `www/user-growth-dashboard.html` | 独立 HTML，不继承 Frappe 模板 |

### 3.3 配置文件

| 文件 | 修改内容 |
|------|----------|
| `modules.txt` | 移到 app 根目录（非嵌套） |
| `hooks.py` | 更新 fixtures 配置 |

---

## 四、部署步骤

### 4.1 环境准备
```bash
# 1. 确保 Python 虚拟环境激活
source /home/frappe/bench/env/bin/activate

# 2. 安装依赖
pip install -e /home/frappe/bench/apps/user_growth_analytics
```

### 4.2 数据库初始化
```bash
# 1. 创建/重置 site
bench new-site site1.local --mariadb-root-password <密码>

# 2. 安装应用
bench --site site1.local install-app user_growth_analytics

# 3. 生成 mock 数据
bench --site site1.local console << 'EOF'
from user_growth_analytics.user_growth_analytics.fixtures.create_mock_data import create_mock_data
create_mock_data()
EOF
```

### 4.3 启动服务
```bash
# 启动 bench（后台运行）
cd /home/frappe/bench
sudo -u frappe bench --site site1.local serve &

# 或使用 supervisor 管理
```

---

## 五、访问地址

| 页面 | 地址 | 备注 |
|------|------|------|
| 大屏（公开） | http://localhost:8000/user-growth-dashboard | 无需登录 |
| Desk 页面 | http://localhost:8000/desk#usergrowthdashboard | 需要登录 |
| API | http://localhost:8000/api/method/user_growth_analytics.user_growth_analytics.api.dashboard.get_dashboard_data | JSON 数据 |

---

## 六、验证清单

- [ ] `modules.txt` 在 app 根目录，内容为 `user_growth_analytics`
- [ ] 根目录有 `__init__.py`
- [ ] `.pth` 文件指向 `/home/frappe/bench/apps`
- [ ] `customer` 字段类型为 `Data`（非 `Link`）
- [ ] API 返回 JSON 数据（含 kpi、trend、regions 等）
- [ ] 大屏页面无 Frappe 默认组件（无侧边栏、导航栏）
- [ ] ECharts 图表正常渲染
- [ ] 30 秒自动刷新数据

---

## 七、已知限制

1. **Desk 页面需要登录**：通过 `page/` 目录创建的页面需要 Frappe 用户登录
2. **构建失败**：`bench build` 可能因 Node.js 环境问题失败，但不影响核心功能
3. **缓存问题**：修改代码后需清除缓存：`bench --site site1.local clear-cache`

---

## 八、相关文件路径

```
/home/frappe/bench/apps/user_growth_analytics/
├── __init__.py                      # App 根模块
├── modules.txt                      # 模块定义（根目录）
├── hooks.py                         # Frappe hooks
├── www/
│   └── user-growth-dashboard.html   # 大屏 Web 页面
├── public/
│   ├── css/dashboard.css            # 大屏样式
│   └── js/dashboard.js              # 大屏逻辑
└── user_growth_analytics/
    ├── api/
    │   └── dashboard.py             # API 接口
    ├── doctype/
    │   └── user_lifecycle_event/
    │       ├── user_lifecycle_event.json
    │       └── user_lifecycle_event.py
    ├── fixtures/
    │   └── create_mock_data.py      # Mock 数据生成
    └── page/
        └── usergrowthdashboard/     # Desk 页面
            ├── usergrowthdashboard.html
            └── usergrowthdashboard.js
```

---

*文档结束*
