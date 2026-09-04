from . import __version__ as app_version

app_name = "user_growth_analytics"
app_title = "User Growth Analytics"
app_publisher = "Your Company"
app_description = "用户增长与流失分析大屏"
app_icon = "octicon octicon-graph"
app_color = "#3b82f6"
app_email = "dev@example.com"
app_version = app_version

# ────────── Fixtures（安装自动导入） ──────────
fixtures = [
    {"dt": "DocType", "filters": [["module", "=", "User Growth Analytics"]]},
    {"dt": "User Lifecycle Event"},
    {"dt": "Report", "filters": [["module", "=", "User Growth Analytics"]]},
]

# ────────── 安装后自动跑 Mock 数据 ──────────
after_install = "user_growth_analytics.install.after_install"

# ────────── 静态资源（bench build 会打包） ──────────
app_include_js = [
    "/assets/user_growth_analytics/js/dashboard.js"
]
app_include_css = [
    "/assets/user_growth_analytics/css/dashboard.css"
]

# ────────── 网站路由 ──────────
website_route_rules = [
    {"from_route": "/user-growth-dashboard", "to_route": "user-growth-dashboard"},
]

# ────────── 定时任务：每小时刷新大屏缓存 ──────────
scheduler_events = {
    "hourly": [
        "user_growth_analytics.api.dashboard.clear_dashboard_cache"
    ]
}
