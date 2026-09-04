import frappe


def after_install():
    """App 安装完成后自动生成演示数据"""
    # 仅在 developer_mode 或显式开启时生成
    if frappe.conf.get("developer_mode") or frappe.conf.get("auto_generate_mock_data"):
        frappe.enqueue(
            "user_growth_analytics.fixtures.create_mock_data.create_mock_data",
            queue="short",
            timeout=300,
            now=frappe.flags.in_test
        )
        frappe.msgprint("🎉 正在后台生成演示数据（约 1200 条），几秒后刷新即可查看。")
