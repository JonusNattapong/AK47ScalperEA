# AK47 Scalper EA — V5.0 PURE AGENT EDITION

**🔥 100% Kilo API Driven · Zero Internal Neural Networks · Multi-Symbol**

AK47 Scalper EA is a fully autonomous, multi-symbol scalping Expert Advisor for
MetaTrader 5. Every trade decision is delegated to the **Kilo AI Agent** — the
EA itself carries no built-in prediction model. It extracts a rich quantitative
feature vector from the live market, hands it to the agent, and executes only on
high-confidence signals under a strict risk framework.

> คือ EA ที่ตัดสินใจด้วย AI Agent 100% ไม่มีโมเดลภายในเลย — ตัว EA ทำหน้าที่
> เก็บข้อมูลตลาด ส่งให้ Kilo Agent วิเคราะห์ แล้วเข้าออเดอร์เฉพาะสัญญาณที่มั่นใจสูง
> ภายใต้ระบบบริหารความเสี่ยงที่เข้มงวด

---

## ✨ What's New in V5.0

| Change | Detail |
|---|---|
| 🧠 **All neural networks removed** | The internal MLP / LSTM / Tri-Brain stack is gone. Signals come **only** from the Kilo API. |
| ⚛️ **Quantum Feature Engine** | New `AK47_Quantum.mqh` builds a 19-dimension feature vector per symbol (price action, structure, swarm correlations, entropy, Hurst memory, volatility regime). |
| 🔀 **True multi-symbol** | Trades a configurable basket (default `XAUUSD, EURUSD, GBPUSD, USDJPY`) with per-symbol indicator handles and magic numbers. |
| 📰 **Native MT5 calendar** | `AK47_News.mqh` feeds upcoming economic events straight into the agent prompt. |

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    AK47 PURE AGENT PIPELINE                    │
│                                                                │
│   [ MARKET FEED ]  ── per symbol ──►  [ QUANTUM ENGINE ]       │
│                                        AK47_Quantum.mqh        │
│                                        features[0..18]         │
│                                             │                  │
│   [ MT5 ECONOMIC CALENDAR ] ──►  [ NEWS/AGENT CLIENT ]         │
│                                    AK47_News.mqh               │
│                                             │                  │
│                                             ▼                  │
│                                   [ KILO AI AGENT ]            │
│                              action · confidence · insight     │
│                                             │                  │
│                        confidence > 0.82 ?  │                  │
│                                             ▼                  │
│               [ RISK GATE ]  ─►  [ EXECUTE ]  ─►  [ TRAIL ]    │
│         drawdown · profit · spread · session · max orders     │
└──────────────────────────────────────────────────────────────┘
```

### Feature vector (19 dimensions)
| Index | Source | Meaning |
|---|---|---|
| `0–2` | Price action | Body, range, close-to-close momentum |
| `3–7` | Indicators | RSI, CCI, MACD, Stochastic, ATR |
| `8–11` | Structure | MA distance, volume ratio, MA slope, Hurst(50) |
| `12–15` | Swarm | DXY, SPX500, US10Y, BTCUSD correlation drift |
| `16` | Quantum | Return **entropy** (market randomness) |
| `17` | Quantum | **Hurst** market memory (trend persistence) |
| `18` | Quantum | **Volatility regime** (short vs long ATR) |

---

## 📁 Files

| File / Folder | Role |
|---|---|
| `AK47ScalperEA.mq5` | Main EA — orchestration, risk gate, execution, and local chart dashboard |
| `AK47_Quantum.mqh` | Self-contained quantitative feature engine (generates 19-dimension feature vector) |
| `AK47_News.mqh` | Kilo API client + MT5 economic-calendar outlook |
| `AK47_WebBridge.mqh` | Web Dashboard Bridge — POSTs EA states, open/closed positions, signals, & logs to the local Node.js server |
| `web/` | Local Node.js / Express / Socket.IO web console for live stats, charts, strategy config, and agent chat logs |

---

## 🖥️ Web Console Dashboard

The repository includes a local web-based dashboard console for real-time monitoring, strategy editing, and chat integration.

### Features
* **Real-time Metrics**: Live balance, equity, and daily P&L.
* **Positions Panel**: Interactive list of active and historical trades.
* **Signals & Insights**: Feeds signal notifications and Kilo AI agent reasoning details.
* **Database Logs**: SQLite-based historical performance tracking and signal/chat backup.

### Quick Start
1. **Navigate to the web directory**:
   ```bash
   cd web
   ```
2. **Install dependencies**:
   ```bash
   npm install
   ```
3. **Start the local server**:
   ```bash
   npm run dev
   ```
4. **Access the console** at `http://localhost:3000`.

### Integration with EA
* To route data from MT5 to the dashboard, ensure you include `AK47_WebBridge.mqh` in the EA code and invoke `WebBridgeEnable("127.0.0.1", 3000)` during initialization.
* Whitelist `http://127.0.0.1:3000` in MT5 under:
  `Tools → Options → Expert Advisors → Allow WebRequest for listed URL`.

---

## ⚙️ Installation

1. Copy `AK47ScalperEA.mq5`, `AK47_Quantum.mqh`, `AK47_News.mqh`, and `AK47_WebBridge.mqh` into
   `<MT5 Data Folder>/MQL5/Experts/AK47ScalperEA/`.
2. Open in **MetaEditor** and compile `AK47ScalperEA.mq5` (F7).
3. **Whitelist API URLs** so the EA can reach the agent and local dashboard:
   `Tools → Options → Expert Advisors → Allow WebRequest for listed URL` →
   add `https://api.kilocode.ai` and `http://127.0.0.1:3000` (if using the Web Console).
4. Attach the EA to any chart and enable **Auto Trading**.

> การเทรดหลายคู่จัดการจากภายในตัว EA ผ่านพารามิเตอร์ `TradingSymbols`
> — แนบ EA บนกราฟเดียวก็พอ ไม่ต้องเปิดหลายกราฟ

---


## 🔧 Inputs

### Core
| Input | Default | Description |
|---|---|---|
| `LotSize` | `0.01` | Fixed lot per position |
| `MaxDailyDrawdown` | `4.0` | % daily loss → pause all trading |
| `DailyProfitTarget` | `2.5` | % daily profit → stop for the day |
| `BaseMagicNumber` | `4747` | Base magic (each symbol gets `base + i`) |
| `MaxOrdersTotal` | `4` | Max concurrent positions across the basket |
| `MaxSpread` | `35` | Max allowed spread (points) per entry |

### Kilo Agent
| Input | Default | Description |
|---|---|---|
| `UseNewsAiFilter` | `true` | Always on in Pure Agent Edition |
| `Kilo_ApiKey` | `YOUR_API_KEY_HERE` | **Set your Kilo API key** |
| `Kilo_ApiUrl` | `https://api.kilocode.ai/v1/chat/completions` | Agent endpoint |
| `ApiCallInterval` | `15` | Seconds between agent calls per symbol |

### Multi-symbol & management
| Input | Default | Description |
|---|---|---|
| `TradingSymbols` | `XAUUSD,EURUSD,GBPUSD,USDJPY` | Comma-separated basket (max 8) |
| `TrailingStart` | `100` | Points in profit before trailing begins |
| `TrailingStop` | `30` | Trailing distance (points) |

---

## 🛡️ Risk & Execution Logic

- **Entry** only when agent confidence `> 0.82` and at least 5 minutes since the
  last trade on that symbol.
- **SL / TP** are ATR-dynamic: `SL = ATR × 1.5`, `TP = ATR × 2.5`.
- **One position per symbol**, capped by `MaxOrdersTotal` across the basket.
- **Global protection**: trading pauses for the day on hitting either the daily
  drawdown limit or the daily profit target.
- **Session filter**: no new entries during the OFF session (weekends / dead hours).
- **Spread guard**: entries skipped when spread exceeds `MaxSpread`.
- **Trailing stop** locks in profit once `TrailingStart` is reached.

---

## ⚠️ Requirements & Notes

- MetaTrader 5 build with **Economic Calendar** and **WebRequest** enabled.
- A valid **Kilo API key** — without it the agent returns no signal and the EA
  simply waits (no trades).
- Test on a **demo account** before going live.
- Trade frequency is deliberately low: with no confident signal, the EA holds.
  Zero-trade sessions are expected behaviour.

---

## 📜 License

See the [`License`](./License) file. See [`CHANGELOG.md`](./CHANGELOG.md) for
version history and [`docs/`](./docs) for configuration and roadmap details.

---

`Copyright 2026 — AK47 Scalper EA · Pure Agent Edition`
