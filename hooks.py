app_name = "user_growth_analytics"
app_title = "User Growth Analytics"
app_publisher = "Your Company"
app_description = "演示用 - 用户增长与流失分析大屏"
app_icon = "octicon octicon-graph"
app_color = "#3b82f6"
app_email = "dev@example.com"
app_version = "0.0.1"

# fixtures 列表:安装时自动导入这些数据
fixtures = [
    {
        "dt": "DocType",
        "filters": {"name": ["in", ["User Service Record"]]}
    },
    {
        "dt": "User Service Record",
    },
]
