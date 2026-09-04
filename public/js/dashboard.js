// 大屏仪表盘渲染逻辑
(function() {
  // 直接使用 fetch 调用 API（不依赖 frappe.call）
  function fetchData() {
    fetch('/api/method/user_growth_analytics.user_growth_analytics.api.dashboard.get_dashboard_data', {
      method: 'GET',
      headers: {
        'Accept': 'application/json'
      }
    })
    .then(function(response) {
      return response.json();
    })
    .then(function(data) {
      if (data.message) {
        renderDashboard(data.message);
      } else if (data.exc) {
        console.error('Dashboard error:', data.exc);
      }
    })
    .catch(function(error) {
      console.error('Failed to fetch dashboard data:', error);
    });
  }

  function renderDashboard(d) {
    if (!d || !d.kpi) {
      console.error('Dashboard: Invalid data', d);
      return;
    }

    // KPI
    document.getElementById("kpi-active").textContent = d.kpi.active;
    document.getElementById("kpi-churned").textContent = d.kpi.churned;
    document.getElementById("kpi-arr").textContent = "¥" + d.kpi.total_mrr.toLocaleString();
    document.getElementById("kpi-retention").textContent = d.kpi.retention + "%";

    // 趋势折线
    echarts.init(document.getElementById("chart-trend")).setOption({
      tooltip: { trigger: "axis" },
      legend: { data: ["新增", "流失"], textStyle: { color: "#cbd5e1" } },
      xAxis: { type: "category", data: d.trend.labels, axisLabel: { color: "#94a3b8" } },
      yAxis: { type: "value", axisLabel: { color: "#94a3b8" } },
      series: [
        { name: "新增", data: d.trend.activations, type: "line", smooth: true, itemStyle: { color: "#22c55e" }, areaStyle: { opacity: 0.3 } },
        { name: "流失", data: d.trend.churns, type: "line", smooth: true, itemStyle: { color: "#ef4444" }, areaStyle: { opacity: 0.3 } }
      ]
    });

    // 地区分布
    echarts.init(document.getElementById("chart-region")).setOption({
      tooltip: { trigger: "axis" },
      xAxis: { type: "category", data: d.regions.map(function(r) { return r.name; }), axisLabel: { color: "#94a3b8", rotate: 30 } },
      yAxis: { type: "value", axisLabel: { color: "#94a3b8" } },
      series: [{ data: d.regions.map(function(r) { return r.value; }), type: "bar", itemStyle: { color: "#5eead4", borderRadius: [4,4,0,0] } }]
    });

    // 套餐环形
    echarts.init(document.getElementById("chart-tier")).setOption({
      tooltip: { trigger: "item" },
      legend: { textStyle: { color: "#cbd5e1" }, bottom: 0 },
      series: [{
        type: "pie", radius: ["40%", "70%"],
        data: d.tiers,
        label: { color: "#cbd5e1" }
      }]
    });

    // 渠道
    echarts.init(document.getElementById("chart-channel")).setOption({
      tooltip: { trigger: "item" },
      series: [{
        type: "pie", radius: "70%",
        data: d.channels,
        label: { color: "#cbd5e1" }
      }]
    });

    // 漏斗
    echarts.init(document.getElementById("chart-funnel")).setOption({
      tooltip: { trigger: "item" },
      series: [{ type: "funnel", data: d.funnel, label: { color: "#cbd5e1" } }]
    });

    // 流失原因
    if (d.churn_reasons && d.churn_reasons.length > 0) {
      echarts.init(document.getElementById("chart-churn-reason")).setOption({
        tooltip: { trigger: "item" },
        series: [{
          type: "pie", radius: ["30%", "70%"],
          data: d.churn_reasons,
          label: { color: "#cbd5e1" },
          emphasis: { itemStyle: { shadowBlur: 10, shadowOffsetX: 0, shadowColor: "rgba(0, 0, 0, 0.5)" } }
        }]
      });
    }

    // 事件流
    const feed = document.getElementById("event-feed");
    feed.innerHTML = d.events.map(function(e) {
      var tagClass = e.event_type === 'Onboarding' ? 'tag-active' : 'tag-churn';
      return '<div class="feed-item">' +
        '<span class="feed-tag ' + tagClass + '">' + e.event_type + '</span>' +
        '<strong>' + e.customer + '</strong> 于 ' + e.event_date + ' 在 ' + (e.region || '未知') + ' 触发' +
        '</div>';
    }).join("");
  }

  // 初始加载
  fetchData();

  // 30秒自动刷新
  setInterval(fetchData, 30000);
})();
