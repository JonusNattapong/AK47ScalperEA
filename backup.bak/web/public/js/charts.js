/* ============================================================
   AK47 Scalper EA — Performance Charts (Lightweight Charts)
   Equity curve + Daily P&L histogram
   ============================================================ */

import { createChart, ColorType } from 'lightweight-charts';

const DARK_BG = '#0b0e14';
const DARK_TEXT = '#8a96a8';
const GRID_COLOR = '#1a212b';
const GREEN = '#22c55e';
const RED = '#ef4444';
const BLUE = '#3b82f6';

// ========== Shared chart theme ==========
const chartTheme = {
  layout: {
    background: { type: ColorType.Solid, color: DARK_BG },
    textColor: DARK_TEXT,
    fontSize: 11,
    fontFamily: "'Segoe UI', system-ui, sans-serif",
  },
  grid: {
    vertLines: { color: GRID_COLOR },
    horzLines: { color: GRID_COLOR },
  },
  timeScale: {
    borderColor: '#2a3548',
    tickMarkFormatter: (ts) => {
      const d = new Date(ts * 1000);
      return `${d.getHours().toString().padStart(2,'0')}:${d.getMinutes().toString().padStart(2,'0')}`;
    },
    timeVisible: true,
    secondsVisible: false,
  },
  rightPriceScale: {
    borderColor: '#2a3548',
  },
  crosshair: {
    vertLine: { color: '#3b82f6', width: 1, style: 2 },
    horzLine: { color: '#3b82f6', width: 1, style: 2 },
  },
};

// ========== Format snapshot time to TradingView time (epoch seconds) ==========
function toTvTime(dateStr) {
  const d = new Date(dateStr);
  return Math.floor(d.getTime() / 1000);
}

// ========== Equity Curve Chart ==========
let equityChart = null;
let equitySeries = null;

function initEquityChart() {
  const container = document.getElementById('chart-equity');
  if (!container) return;

  equityChart = createChart(container, {
    ...chartTheme,
    width: container.clientWidth,
    height: 320,
  });

  equitySeries = equityChart.addLineSeries({
    color: BLUE,
    lineWidth: 2,
    crosshairMarkerVisible: true,
    crosshairMarkerRadius: 4,
    priceFormat: {
      type: 'price',
      precision: 2,
      minMove: 0.01,
    },
    lastValueVisible: true,
    priceLineVisible: false,
  });

  // Resize handler
  const ro = new ResizeObserver(() => {
    if (equityChart) {
      equityChart.applyOptions({ width: container.clientWidth });
    }
  });
  ro.observe(container);
}

function renderEquityCurve(data) {
  if (!equitySeries || !data || data.length < 2) return;
  const seriesData = data
    .filter(d => d.balance > 0)
    .map(d => ({ time: toTvTime(d.created_at), value: d.balance }));
  equitySeries.setData(seriesData);
  if (equityChart) equityChart.timeScale().fitContent();
}

// ========== Daily P&L Histogram Chart ==========
let pnlChart = null;
let pnlSeries = null;

function initPnlChart() {
  const container = document.getElementById('chart-dailypnl');
  if (!container) return;

  pnlChart = createChart(container, {
    ...chartTheme,
    width: container.clientWidth,
    height: 320,
  });

  pnlSeries = pnlChart.addHistogramSeries({
    priceFormat: {
      type: 'price',
      precision: 2,
      minMove: 0.01,
    },
    priceLineVisible: false,
    lastValueVisible: true,
  });

  const ro = new ResizeObserver(() => {
    if (pnlChart) {
      pnlChart.applyOptions({ width: container.clientWidth });
    }
  });
  ro.observe(container);
}

function renderPnlHistogram(data) {
  if (!pnlSeries || !data || data.length < 2) return;
  const seriesData = data
    .filter(d => d.balance > 0)
    .map(d => ({
      time: toTvTime(d.created_at),
      value: d.daily_pnl,
      color: d.daily_pnl >= 0 ? GREEN : RED,
    }));
  pnlSeries.setData(seriesData);
  if (pnlChart) pnlChart.timeScale().fitContent();
}

// ========== Load data & init ==========
export function loadCharts() {
  initEquityChart();
  initPnlChart();

  fetch('/api/performance?limit=500')
    .then(r => r.json())
    .then(data => {
      renderEquityCurve(data);
      renderPnlHistogram(data);
    })
    .catch(() => {});
}

// ========== Real-time update (called from app.js) ==========
// We don't re-fetch everything on each state update — the snapshot
// row is appended server-side, but for simplicity we can refetch
// periodically. For now, the initial load is sufficient.
