import frappe
from collections import Counter


@frappe.whitelist(allow_guest=True)
def get_dashboard_data():
    """获取大屏数据（生产环境请勿使用 allow_guest）"""
    records = frappe.get_all(
        "User Lifecycle Event",
        fields=["event_type", "event_date", "customer",
                "channel", "plan", "mrr", "region"]
    )

    if not records:
        return _empty_payload()

    # ---- KPI ----
    # 计算当前活跃用户数
    user_status = {}
    for r in records:
        cust = r.customer
        if cust not in user_status:
            user_status[cust] = {"onboard": False, "churned": False}

        if r.event_type == "Onboarding":
            user_status[cust]["onboard"] = True
            user_status[cust]["plan"] = r.plan
            user_status[cust]["mrr"] = r.mrr
        elif r.event_type == "Churn":
            user_status[cust]["churned"] = True

    active_users = sum(1 for s in user_status.values() if s["onboard"] and not s["churned"])
    churned_users = sum(1 for s in user_status.values() if s["onboard"] and s["churned"])
    total_mrr = sum(r.mrr for r in records if r.event_type == "Onboarding")

    # ---- Trend (按月) ----
    monthly = {}
    for r in records:
        m = r.event_date.strftime("%Y-%m")
        monthly.setdefault(m, {"act": 0, "chu": 0})
        if r.event_type == "Onboarding":
            monthly[m]["act"] += 1
        elif r.event_type == "Churn":
            monthly[m]["chu"] += 1

    labels = sorted(monthly.keys())
    trend = {
        "labels": labels,
        "activations": [monthly[m]["act"] for m in labels],
        "churns": [monthly[m]["chu"] for m in labels],
    }

    # ---- Distribution ----
    regions = Counter(r.region or "其他" for r in records if r.event_type == "Onboarding")
    channels = Counter(r.channel or "Direct" for r in records if r.event_type == "Onboarding")
    tiers = Counter(r.plan or "Standard" for r in records if r.event_type == "Onboarding")

    # ---- Funnel ----
    activations = sum(1 for r in records if r.event_type == "Onboarding")
    churns = sum(1 for r in records if r.event_type == "Churn")
    funnel = [
        {"name": "新开通", "value": activations},
        {"name": "流失", "value": churns},
    ]

    # ---- Churn reasons ----
    churn_reasons = []
    for r in records:
        if r.event_type == "Churn" and r.get("churn_reason"):
            churn_reasons.append(r.churn_reason)

    churn_reason_dist = Counter(churn_reasons)

    # ---- Event feed (最近10条) ----
    sorted_recs = sorted(records, key=lambda x: x.event_date, reverse=True)[:10]
    events = [{
        "event_type": r.event_type,
        "customer": r.customer,
        "region": r.region,
        "event_date": str(r.event_date),
    } for r in sorted_recs]

    return {
        "kpi": {
            "active": active_users,
            "churned": churned_users,
            "total_mrr": total_mrr,
            "retention": round(active_users / (active_users + churned_users) * 100, 1) if (active_users + churned_users) else 0
        },
        "trend": trend,
        "regions": [{"name": k, "value": v} for k, v in regions.most_common()],
        "channels": [{"name": k, "value": v} for k, v in channels.most_common()],
        "tiers": [{"name": k, "value": v} for k, v in tiers.most_common()],
        "funnel": funnel,
        "churn_reasons": [{"name": k, "value": v} for k, v in churn_reason_dist.most_common()],
        "events": events,
    }


def _empty_payload():
    return {
        "kpi": {"active": 0, "churned": 0, "total_mrr": 0, "retention": 0},
        "trend": {"labels": [], "activations": [], "churns": []},
        "regions": [], "channels": [], "tiers": [], "funnel": [],
        "churn_reasons": [], "events": []
    }


@frappe.whitelist()
def clear_dashboard_cache():
    """清除大屏缓存"""
    frappe.cache().delete_keys("uga:")
