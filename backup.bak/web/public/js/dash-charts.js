/* ============================================================
   AK47 Scalper EA — Chart.js Visualizations
   Doughnut (allocation) + Bar (daily P&L)
   ============================================================ */

import { Chart, registerables } from 'chart.js';
Chart.register(...registerables);

Chart.defaults.color = '#8a96a8';
Chart.defaults.borderColor = '#2a3548';
Chart.defaults.font.family = "'Segoe UI', system-ui, sans-serif";

const COLORS = ['#3b82f6', '#22c55e', '#eab308', '#ef4444', '#8b5cf6', '#ec4899', '#14b8a6', '#f97316'];
const DARK_BG = '#1a212b';

let allocationChart = null;
let dailyChart = null;

// ─── Doughnut: Symbol Position Count ────────────────────────
function createAllocationChart(positions) {
  const canvas = document.getElementById('chart-allocation');
  if (!canvas) return;
  if (allocationChart) { allocationChart.destroy(); allocationChart = null; }

  if (!positions || positions.length === 0) {
    const ctx = canvas.getContext('2d');
    allocationChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['No Positions'],
        datasets: [{ data: [1], backgroundColor: ['#2a3548'], borderWidth: 0 }]
      },
      options: {
        responsive: true, maintainAspectRatio: true, cutout: '60%',
        plugins: {
          legend: { position: 'bottom', labels: { padding: 16, color: '#5a6678', boxWidth: 12 } },
          tooltip: { enabled: false }
        }
      }
    });
    return;
  }

  const map = {};
  positions.forEach(p => {
    if (!map[p.symbol]) map[p.symbol] = 0;
    map[p.symbol]++;
  });

  const labels = Object.keys(map);
  const data = labels.map(l => map[l]);
  const colors = COLORS.slice(0, labels.length);

  const ctx = canvas.getContext('2d');
  allocationChart = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels,
      datasets: [{
        data,
        backgroundColor: colors,
        borderColor: DARK_BG,
        borderWidth: 2,
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: true, cutout: '60%',
      plugins: {
        legend: { position: 'bottom', labels: { padding: 16, color: '#8a96a8', boxWidth: 12 } },
        tooltip: { callbacks: { label: (ctx) => `${ctx.label}: ${ctx.parsed} position(s)` } }
      }
    }
  });
}

// ─── Bar: Daily P&L Last 7 Days ─────────────────────────────
function createDailyBarChart(perfData) {
  const canvas = document.getElementById('chart-daily');
  if (!canvas) return;
  if (dailyChart) { dailyChart.destroy(); dailyChart = null; }

  const dayMap = {};
  (perfData || []).forEach(d => {
    if (!d.created_at) return;
    const day = d.created_at.split(' ')[0];
    if (!dayMap[day]) dayMap[day] = 0;
    dayMap[day] += Number(d.daily_pnl) || 0;
  });

  const days = Object.keys(dayMap).slice(-7);
  const pnls = days.map(d => dayMap[d]);

  if (days.length < 1) return;

  const ctx = canvas.getContext('2d');
  dailyChart = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: days.map(d => d.slice(5)),
      datasets: [{
        label: 'Daily P&L',
        data: pnls,
        backgroundColor: pnls.map(v => v >= 0 ? 'rgba(34,197,94,0.7)' : 'rgba(239,68,68,0.7)'),
        borderColor: pnls.map(v => v >= 0 ? '#22c55e' : '#ef4444'),
        borderWidth: 1,
        borderRadius: 4,
      }]
    },
    options: {
      responsive: true, maintainAspectRatio: true,
      plugins: { legend: { display: false } },
      scales: {
        y: {
          grid: { color: '#2a3548' },
          ticks: { color: '#8a96a8', callback: (v) => '$' + Number(v).toFixed(0) }
        },
        x: { grid: { display: false }, ticks: { color: '#8a96a8' } }
      }
    }
  });
}

// ─── Init ────────────────────────────────────────────────────
export function initDashCharts() {
  Promise.all([
    fetch('/api/positions').then(r => r.json()).catch(() => []),
    fetch('/api/performance?limit=100').then(r => r.json()).catch(() => []),
  ]).then(([positions, perf]) => {
    createAllocationChart(positions);
    createDailyBarChart(perf);
  });
}
