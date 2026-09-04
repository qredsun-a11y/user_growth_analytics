frappe.pages['usergrowthdashboard'].on_page_load = function(wrapper) {
  frappe.ui.make_app_page({
    parent: frappe.pages['usergrowthdashboard'],
    title: __('用户增长指挥中心'),
    single_column: true,
  });

  // 加载 ECharts
  const script = document.createElement('script');
  script.src = 'https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js';
  script.onload = () => {
    fetchDashboardData();
  };
  document.head.appendChild(script);
};

function fetchDashboardData() {
  frappe.call({
    method: 'user_growth_analytics.user_growth_analytics.api.dashboard.get_dashboard_data',
    callback: function(r) {
      if (r.message) {
        renderDashboard(r.message);
      } else if (r.exc) {
        console.error('Dashboard error:', r.exc);
      }
    }
  });
}

function renderDashboard(d) {
  if (!d || !d.kpi) return;

  // KPI
  document.getElementById('kpi-active').textContent = d.kpi.active;
  document.getElementById('kpi-churned').textContent = d.kpi.churned;
  document.getElementById('kpi-arr').textContent = '¥' + d.kpi.total_mrr.toLocaleString();
  document.getElementById('kpi-retention').textContent = d.kpi.retention + '%';

  // 趋势折线
  echarts.init(document.getElementById('chart-trend')).setOption({
    tooltip: { trigger: 'axis' },
    legend: { data: ['新增', '流失'], textStyle: { color: '#cbd5e1' } },
    xAxis: { type: 'category', data: d.trend.labels, axisLabel: { color: '#94a3b8' } },
    yAxis: { type: 'value', axisLabel: { color: '#94a3b8' } },
    series: [
      { name: '新增', data: d.trend.activations, type: 'line', smooth: true, itemStyle: { color: '#22c55e' }, areaStyle: { opacity: 0.3 } },
      { name: '流失', data: d.trend.churns, type: 'line', smooth: true, itemStyle: { color: '#ef4444' }, areaStyle: { opacity: 0.3 } }
    ]
  });

  // 地区分布
  echarts.init(document.getElementById('chart-region')).setOption({
    tooltip: { trigger: 'axis' },
    xAxis: { type: 'category', data: d.regions.map(r => r.name), axisLabel: { color: '#94a3b8', rotate: 30 } },
    yAxis: { type: 'value', axisLabel: { color: '#94a3b8' } },
    series: [{ data: d.regions.map(r => r.value), type: 'bar', itemStyle: { color: '#5eead4', borderRadius: [4,4,0,0] } }]
  });

  // 套餐环形
  echarts.init(document.getElementById('chart-tier')).setOption({
    tooltip: { trigger: 'item' },
    legend: { textStyle: { color: '#cbd5e1' }, bottom: 0 },
    series: [{ type: 'pie', radius: ['40%', '70%'], data: d.tiers, label: { color: '#cbd5e1' } }]
  });

  // 渠道
  echarts.init(document.getElementById('chart-channel')).setOption({
    tooltip: { trigger: 'item' },
    series: [{ type: 'pie', radius: '70%', data: d.channels, label: { color: '#cbd5e1' } }]
  });

  // 漏斗
  echarts.init(document.getElementById('chart-funnel')).setOption({
    tooltip: { trigger: 'item' },
    series: [{ type: 'funnel', data: d.funnel, label: { color: '#cbd5e1' } }]
  });

  // 流失原因
  if (d.churn_reasons && d.churn_reasons.length > 0) {
    echarts.init(document.getElementById('chart-churn-reason')).setOption({
      tooltip: { trigger: 'item' },
      series: [{
        type: 'pie', radius: ['30%', '70%'],
        data: d.churn_reasons,
        label: { color: '#cbd5e1' },
        emphasis: { itemStyle: { shadowBlur: 10, shadowOffsetX: 0, shadowColor: 'rgba(0, 0, 0, 0.5)' } }
      }]
    });
  }

  // 事件流
  const feed = document.getElementById('event-feed');
  feed.innerHTML = d.events.map(e => `
    <div class="feed-item">
      <span class="feed-tag ${e.event_type === 'Onboarding' ? 'tag-active' : 'tag-churn'}">${e.event_type}</span>
      <strong>${e.customer}</strong> 于 ${e.event_date} 在 ${e.region || '未知'} 触发
    </div>
  `).join('');
}

// 30秒自动刷新
setInterval(fetchDashboardData, 30000);
