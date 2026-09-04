import frappe
from frappe import _
from frappe.query_builder import DocType
from frappe.query_builder.functions import Count, Sum
from collections import defaultdict


def execute(filters=None):
    columns = get_columns()
    data = get_data(filters)
    chart = get_chart_data(data)
    summary = get_summary(data)
    return columns, data, None, chart, summary


def get_columns():
    return [
        {"label": _("月份"), "fieldname": "month", "fieldtype": "Data", "width": 120},
        {"label": _("新增用户"), "fieldname": "activations", "fieldtype": "Int", "width": 120},
        {"label": _("流失用户"), "fieldname": "churns", "fieldtype": "Int", "width": 120},
        {"label": _("净增长"), "fieldname": "net_growth", "fieldtype": "Int", "width": 120},
        {"label": _("累计活跃"), "fieldname": "cumulative_active", "fieldtype": "Int", "width": 120},
        {"label": _("ARR 贡献 (¥)"), "fieldname": "arr_total", "fieldtype": "Currency", "width": 150},
    ]


def get_data(filters):
    """按月聚合：正确计算累计活跃 = 历史开通 - 历史流失"""
    Event = DocType("User Lifecycle Event")

    query = (
        frappe.qb.from_(Event)
        .select(
            Event.event_type,
            Event.event_date,
            Event.customer,
            Event.plan,
            Event.mrr,
            Event.region,
            Event.channel,
        )
    )

    # 过滤器支持
    if filters:
        if filters.get("from_date"):
            query = query.where(Event.event_date >= filters["from_date"])
        if filters.get("to_date"):
            query = query.where(Event.event_date <= filters["to_date"])
        if filters.get("region"):
            query = query.where(Event.region.isin(filters["region"] if isinstance(filters["region"], list) else [filters["region"]]))
        if filters.get("channel"):
            query = query.where(Event.channel.isin(filters["channel"] if isinstance(filters["channel"], list) else [filters["channel"]]))
        if filters.get("plan"):
            query = query.where(Event.plan.isin(filters["plan"] if isinstance(filters["plan"], list) else [filters["plan"]]))

    records = query.run(as_dict=True)

    # 先按客户聚合生命周期（取最早开通、最晚流失）
    user_lifecycle = {}
    for r in records:
        uid = r.customer
        if uid not in user_lifecycle:
            user_lifecycle[uid] = {
                "onboard_dates": [],
                "churn_dates": [],
                "plan": r.plan,
                "mrr": r.mrr,
                "region": r.region,
                "channel": r.channel,
            }

        if r.event_type == "Onboarding":
            user_lifecycle[uid]["onboard_dates"].append(r.event_date)
        elif r.event_type == "Churn":
            user_lifecycle[uid]["churn_dates"].append(r.event_date)

    # 按月统计
    monthly = defaultdict(lambda: {"act": 0, "chu": 0, "arr": 0})
    for uid, lc in user_lifecycle.items():
        if lc["onboard_dates"]:
            first_onboard = min(lc["onboard_dates"])
            m = first_onboard.strftime("%Y-%m")
            monthly[m]["act"] += 1
            monthly[m]["arr"] += (lc["mrr"] or 0) * 12  # ARR = MRR * 12
        if lc["churn_dates"]:
            last_churn = max(lc["churn_dates"])
            m = last_churn.strftime("%Y-%m")
            monthly[m]["chu"] += 1

    # 正确累计活跃：每月 active = 上月 active + 本月开通 - 本月流失
    sorted_months = sorted(monthly.keys())
    active = 0
    result = []
    for m in sorted_months:
        act = monthly[m]["act"]
        chu = monthly[m]["chu"]
        net = act - chu
        active = max(0, active + net)  # 不允许负数
        result.append({
            "month": m,
            "activations": act,
            "churns": chu,
            "net_growth": net,
            "cumulative_active": active,
            "arr_total": monthly[m]["arr"],
        })
    return result


def get_chart_data(data):
    return {
        "data": {
            "labels": [d["month"] for d in data],
            "datasets": [
                {"name": _("新增用户"), "values": [d["activations"] for d in data]},
                {"name": _("流失用户"), "values": [d["churns"] for d in data]},
                {"name": _("净增长"), "values": [d["net_growth"] for d in data], "chartType": "bar"},
            ],
        },
        "type": "line",
        "colors": ["#22c55e", "#ef4444", "#3b82f6"],
        "axisOptions": {
            "shortenYAxisNumbers": 1,
        },
    }


def get_summary(data):
    if not data:
        return []

    # 最近一个月的数据
    last_month = data[-1] if data else {}
    recent_act = last_month.get("activations", 0)
    recent_chu = last_month.get("churns", 0)

    total_act = sum(d["activations"] for d in data)
    total_chu = sum(d["churns"] for d in data)
    total_arr = sum(d["arr_total"] for d in data)
    current_active = data[-1]["cumulative_active"] if data else 0

    return [
        {"value": current_active, "label": _("当前活跃用户"), "datatype": "Int", "color": "#22c55e"},
        {"value": recent_act, "label": _("30天新增"), "datatype": "Int", "color": "#3b82f6"},
        {"value": recent_chu, "label": _("30天流失"), "datatype": "Int", "color": "#ef4444"},
        {"value": recent_act - recent_chu, "label": _("30天净增"), "datatype": "Int", "color": "#f59e0b"},
        {"value": total_arr, "label": _("总 ARR"), "datatype": "Currency", "color": "#a855f7"},
    ]
