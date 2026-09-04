# User Growth Analytics - Frappe 自定义 App

演示用的用户增长与流失分析系统，包含：
1. **用户服务开通/流失单据** - `User Service Record` (含 30 条预设 Mock 数据)
2. **用户增长数据报表** - `User Growth Report` (Script Report，按月聚合新增/流失/ARR)
3. **用户增长数据大屏** - `/user-growth-dashboard` (ECharts 可视化大屏)

---

## 目录结构

```
user_growth_analytics/
├── hooks.py                      # App 根配置 (fixtures 自动导入)
├── setup.py                      # Python 包配置
├── pyproject.toml                # 现代打包配置
├── README.md                     # 本文件
├── user_growth_analytics/        # Python 包
│   ├── __init__.py
│   ├── hooks.py                  # App 详细配置 (路由、静态资源、Desktop)
│   ├── config/
│   │   ├── __init__.py
│   │   └── desktop.py            # Desk 模块入口
│   ├── doctype/
│   │   └── user_service_record/  # 单据定义
│   │       ├── __init__.py
│   │       ├── user_service_record.json
│   │       └── user_service_record.py
│   ├── fixtures/
│   │   ├── __init__.py
│   │   ├── create_mock_data.py   # 生成 Mock 数据脚本
│   │   └── user_service_record.json  # 预设 30 条数据
│   ├── report/
│   │   └── user_growth_report/   # Script Report
│   │       ├── __init__.py
│   │       ├── user_growth_report.json
│   │       └── user_growth_report.py
│   └── api/
│       ├── __init__.py
│       └── dashboard.py          # 大屏后端数据接口
├── www/
│   └── user-growth-dashboard.html  # 大屏页面入口
└── public/
    ├── css/
    │   └── dashboard.css         # 大屏样式
    └── js/
        └── dashboard.js          # 大屏渲染逻辑
```

---

## 快速部署

### 前置条件
- Frappe Bench 环境 (v14+)
- Python 3.10+
- Node.js 18+

### 安装步骤

```bash
# 1. 进入 bench 目录
cd /path/to/frappe-bench

# 2. 获取 App (如果是本地开发，可直接软链接)
bench get-app user_growth_analytics /path/to/user_growth_analytics

# 3. 创建站点并安装
bench new-site demo.localhost
bench --site demo.localhost install-app user_growth_analytics

# 4. (可选) 重新生成 Mock 数据
bench --site demo.localhost execute user_growth_analytics.fixtures.create_mock_data.create_mock_data

# 5. 导出 fixtures (之后重装会自动导入)
bench --site demo.localhost export-fixtures

# 6. 启动服务
bench start
```

---

## 访问入口

| 功能 | URL | 说明 |
|------|-----|------|
| 单据列表 | `/app/user-service-record` | Desk 界面，增删改查 30 条预设数据 |
| 报表 | `/app/query-report/User%20Growth%20Report` | 按月聚合的增长/流失/ARR 报表 |
| 大屏 | `/user-growth-dashboard` | 全屏可视化大屏，适合投屏展示 |

---

## Mock 数据说明

预设 30 条记录，覆盖：
- **时间跨度**：2025-10 至 2026-11 (约 13 个月)
- **状态分布**：Active 18、Churned 8、Pending 2、Expired 2
- **事件类型**：Activation 20、Renewal 5、Upgrade 3、Churn 2
- **渠道**：Direct、Marketing Campaign、Partner、Referral、SEO、Social Media
- **套餐**：Free、Standard、Enterprise
- **地区**：北京、上海、广州、深圳、杭州、成都、武汉、其他
- **ARR**：0 / 999 / 2,999 / 9,999 / 29,999 / 99,999

---

## 自定义开发指南

### 修改 Mock 数据
编辑 `user_growth_analytics/fixtures/create_mock_data.py`，运行：
```bash
bench --site demo.localhost execute user_growth_analytics.fixtures.create_mock_data.create_mock_data
bench --site demo.localhost export-fixtures
```

### 调整报表逻辑
修改 `user_growth_analytics/report/user_growth_report/user_growth_report.py` 中的 `get_data()`、`get_chart_data()`、`get_summary()`。

### 扩展大屏图表
1. 在 `api/dashboard.py` 的 `get_dashboard_data()` 增加新聚合字段
2. 在 `public/js/dashboard.js` 的 `renderDashboard()` 增加对应 ECharts 实例

### 样式主题
修改 `public/css/dashboard.css` 中的 CSS 变量：
```css
:root {
  --bg-primary: #0a0e27;
  --accent: #5eead4;
  --card-bg: rgba(15,23,42,.6);
  --border: rgba(94,234,212,.2);
}
```

---

## 生产环境构建

```bash
# 编译静态资源 (JS/CSS 压缩、打包)
bench build --app user_growth_analytics

# 重启服务
bench restart
```

---

## 许可证

MIT License - 可自由用于学习、演示、二次开发。
