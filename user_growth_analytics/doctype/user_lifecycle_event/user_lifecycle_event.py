import frappe
from frappe.model.document import Document
from frappe import _


class UserLifecycleEvent(Document):
    def validate(self):
        # Churn 必须关联开通单
        if self.event_type == "Churn":
            if not self.related_onboarding:
                frappe.throw(_("流失事件必须关联一次开通单 (related_onboarding)"))

            # 校验关联单是否为该客户的 Onboarding
            related = frappe.get_doc("User Lifecycle Event", self.related_onboarding)
            if related.event_type != "Onboarding":
                frappe.throw(_("关联单据必须是开通类型 (Onboarding)"))
            if related.customer != self.customer:
                frappe.throw(_("关联开通单的客户必须与流失事件的客户一致"))

        # 设置自动标题
        if self.customer_name and self.event_date:
            self.set_title(f"{self.event_type}-{self.customer_name}-{self.event_date}")

    def before_save(self):
        # Churn 事件的 MRR/channel/plan/region 取自关联开通单（快照）
        if self.event_type == "Churn" and self.related_onboarding:
            related = frappe.get_doc("User Lifecycle Event", self.related_onboarding)
            self.mrr = related.mrr
            self.plan = related.plan
            self.channel = related.channel
            self.region = related.region

    def on_update(self):
        # 清除相关缓存，保证大屏/报表实时性
        frappe.cache().delete_keys("uga:")
