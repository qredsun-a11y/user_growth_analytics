from frappe import _


def get_data():
    return [
        {
            "module_name": "User Growth Analytics",
            "color": "#3b82f6",
            "icon": "octicon octicon-graph",
            "type": "module",
            "label": _("User Growth"),
            "items": [
                {
                    "type": "doctype",
                    "name": "User Lifecycle Event",
                    "label": _("Lifecycle Events"),
                    "description": _("用户开通/流失事件记录"),
                },
                {
                    "type": "report",
                    "name": "User Growth Report",
                    "label": _("Growth Report"),
                    "description": _("按月聚合的增长/流失/ARR 报表"),
                },
                {
                    "type": "page",
                    "name": "user-growth-dashboard",
                    "label": _("Growth Dashboard"),
                    "description": _("1920×1080 大屏可视化"),
                },
            ],
        }
    ]
