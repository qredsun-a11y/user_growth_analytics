import frappe
import random
from datetime import date, timedelta
from collections import defaultdict

# 固定种子，保证可复现
random.seed(42)

# ────────────────── 常量配置 ──────────────────
REGIONS = [
    ("华北", ["北京", "天津", "石家庄", "太原", "呼和浩特"]),
    ("华东", ["上海", "南京", "杭州", "合肥", "济南", "福州", "南昌"]),
    ("华南", ["广州", "深圳", "珠海", "佛山", "东莞", "中山", "海口"]),
    ("华中", ["武汉", "长沙", "郑州", "合肥"]),
    ("西南", ["成都", "重庆", "昆明", "贵阳", "拉萨"]),
    ("西北", ["西安", "兰州", "西宁", "银川", "乌鲁木齐"]),
    ("东北", ["沈阳", "大连", "长春", "哈尔滨"]),
    ("海外", ["新加坡", "东京", "首尔", "硅谷", "伦敦", "法兰克福"]),
]

# 扁平化城市列表，含权重
CITIES_WEIGHTED = []
for region, cities in REGIONS:
    for c in cities:
        weight = 5 if c in ["北京", "上海", "广州", "深圳", "杭州", "成都", "武汉", "西安"] else 2
        if region == "海外":
            weight = 1
        CITIES_WEIGHTED.extend([(c, region)] * weight)

CHANNELS = [
    ("自然流量", 0.30),
    ("付费投放", 0.25),
    ("渠道代理", 0.15),
    ("口碑推荐", 0.12),
    ("线下活动", 0.10),
    ("其他", 0.08),
]

PLANS = [
    ("免费", 0, 0.35),
    ("基础", 299, 0.40),
    ("专业", 999, 0.18),
    ("企业", 2999, 0.07),
]

CHURN_REASONS = [
    ("价格", 0.30),
    ("竞品", 0.20),
    ("产品不满足", 0.18),
    ("服务问题", 0.15),
    ("公司关闭", 0.10),
    ("其他", 0.07),
]

COMPANIES = [
    "星空科技", "蓝色海洋", "未来教育", "绿野集团", "云端智能",
    "东方传媒", "北方能源", "西部开发", "智联网络", "创新工场",
    "数据港", "量子跃迁", "极光互联", "赤兔物流", "飞鸿制造",
    "博观医疗", "致远金融", "翰林咨询", "锦程旅业", "天工智造",
]

SURNAMES = "张李王刘陈杨赵黄周吴徐孙马朱胡林郭何高罗梁宋郑韩冯谢唐曹许邓萧曾田袁于廖杜钟汪戴崔任陆姜范方石姚谭廖邹熊金薛贾雷白龙段郝孔邵史毛常万顾赖武乔覃钱尤汤阎昌苏鲁柏秦江蔡钭印宿裴卞齐康伍余元卜顾孟平黄和穆萧尹姚邵湛汪祁毛禹狄米贝明臧计伏成戴谈宋茅庞熊纪舒屈项祝董梁杜阮蓝闵席季麻强贾路娄危江童颜郭梅盛林刁钟徐邱骆高夏蔡田樊胡凌霍万虞万支柯昝管卢莫经房裘缪干解应宗丁宣贲邓郁单杭洪包诸左石崔吉钮龚"
GIVEN_NAMES = "伟芳娜敏静丽强军杰霞明超琳峰婷鹏翔伟婷佳爽冰伟霞明超琳峰婷鹏翔伟婷佳爽冰"


def weighted_choice(choices):
    """choices: [(value, weight), ...]"""
    total = sum(w for _, w in choices)
    r = random.uniform(0, total)
    upto = 0
    for c, w in choices:
        if upto + w >= r:
            return c
        upto += w
    return choices[-1][0]


def random_name():
    return random.choice(SURNAMES) + "".join(random.choices(GIVEN_NAMES, k=2))


def random_company():
    return random.choice(COMPANIES) + random.choice(["科技", "集团", "网络", "信息", "发展", ""])


def seasonal_factor(month):
    """返回该月的开通量倍数：Q4 高，Q1 低"""
    if month in [10, 11, 12]:
        return 1.5
    if month in [1, 2]:
        return 0.6
    if month in [6, 7, 8]:
        return 1.1
    return 1.0


def create_mock_data():
    """生成 ~500 客户，~1200 事件，跨度 12 个月"""
    frappe.flags.ignore_permissions = True

    # 清理旧数据
    if frappe.db.table_exists("tabUser Lifecycle Event"):
        for d in frappe.get_all("User Lifecycle Event"):
            frappe.delete_doc("User Lifecycle Event", d.name)

    # 生成随机客户 ID（不再依赖 Customer DocType）
    customers = []
    for i in range(500):
        cname = random_company()
        cid = f"CUST-{i+1:04d}"
        customers.append({"name": cid, "customer_name": cname})

    # ────────── 先生成所有 Onboarding 事件 ──────────
    onboarding_events = []
    today = date.today()
    start_date = today - timedelta(days=365)

    for cust in customers:
        # 每个客户 1-3 次开通（续费/升级视为新开通）
        num_onboards = random.choices([1, 2, 3], weights=[0.7, 0.2, 0.1])[0]
        last_date = start_date

        for _ in range(num_onboards):
            gap = random.randint(30, 120)
            last_date += timedelta(days=gap)
            if last_date > today:
                break

            # 季节性调整
            if random.random() > seasonal_factor(last_date.month) * 0.8:
                continue

            city_region = random.choice(CITIES_WEIGHTED)
            plan_name = weighted_choice([(p[0], p[2]) for p in PLANS])
            plan_mrr = next(p[1] for p in PLANS if p[0] == plan_name)
            channel = weighted_choice(CHANNELS)

            d = frappe.new_doc("User Lifecycle Event")
            d.event_type = "Onboarding"
            d.event_date = last_date
            d.customer = cust["name"]
            d.region = city_region[1]
            d.channel = channel
            d.plan = plan_name
            d.mrr = plan_mrr
            d.insert()
            onboarding_events.append({
                "name": d.name,
                "customer": cust["name"],
                "date": last_date,
                "plan": plan_name,
                "mrr": plan_mrr,
                "channel": channel,
                "region": city_region[1],
            })

    # ────────── 生成 Churn 事件（约 35% 的开通会流失） ──────────
    for ob in onboarding_events:
        # 早期流失概率高
        if random.random() > 0.35:
            continue

        churn_delay = random.choices(
            [random.randint(1, 30), random.randint(31, 90), random.randint(91, 180)],
            weights=[0.5, 0.3, 0.2]
        )[0]
        churn_date = ob["date"] + timedelta(days=churn_delay)
        if churn_date > today:
            continue

        d = frappe.new_doc("User Lifecycle Event")
        d.event_type = "Churn"
        d.event_date = churn_date
        d.customer = ob["customer"]
        d.related_onboarding = ob["name"]
        d.churn_reason = weighted_choice(CHURN_REASONS)
        d.insert()

    frappe.db.commit()
    print(f"✅ Created {len(onboarding_events)} events for {len(customers)} customers.")


if __name__ == "__main__":
    create_mock_data()
