# AK47 Scalper EA V5.0 - QUANTUM EDITION Roadmap

## Release Target: Q2 2026

---

## Core Vision
From: **Trading Bot** -> To: **Autonomous Capital Protection System**

V5 will not be an incremental update. It will be a complete paradigm shift in how scalper EA operate.

---

## ✅ 7 NEW FEATURES (No other EA has these)

| # | Feature | Description | Status |
|---|---------|-------------|--------|
| 1 | 🧠 **Tri-Brain Consensus Engine** | 3 independent neural networks at M1 / M5 / H1 timeframes. **ALL 3 must agree** before any trade is opened. No exceptions. | Planned |
| 2 | 🕹️ **Live Position Agent** | Dedicated thread that manages open positions after execution. Dynamically moves SL/TP, tightens/loosens, and can close early _without predefined rules_. | Planned |
| 3 | 🧪 **Liquidity Map Detector** | Instead of hunting order blocks, system predicts where liquidity will be targeted 2-3 ticks before price moves there. | Planned |
| 4 | 📉 **Dynamic Drawdown Governor** | Lot size automatically scales down/up in real time based on current account drawdown percentage. Slows losses exponentially. | Planned |
| 5 | 🕒 **Time Warp Memory Filter** | System remembers which 30 minute windows historically win/lose, and automatically skips bad time windows permanently. | Planned |
| 6 | 🔄 **Anti-Martingale Guard** | Absolute hard lock: If the last position lost, same direction entries are blocked for minimum 12 candles. | Planned |
| 7 | ⚙️ **Zero Configuration Mode** | **No user inputs required at all**. System calculates all parameters automatically from account balance, leverage and volatility. | Planned |

---

## 🧱 Architecture Changes from V4
```
[ MARKET FEED ]
       |
       ▼
[ LIQUIDITY MAPPER ] <----> [ TIME WARP HISTORY ]
       |                      |
       +----------------------+
       |
       ▼
[ TRI-BRAIN CONSENSUS ]
  M1 <> M5 <> H1  (UNANIMOUS VOTE ONLY)
       |
       ▼
[ DRAWDOWN GOVERNOR ]
       |
       ▼
[ EXECUTE TRADE ]
       |
       ▼
[ LIVE POSITION AGENT ]  <---- (LIVE THREAD RUNNING PER OPEN POSITION)
       |
       ▼
[ CONTINUOUS NETWORK REWEIGHTING ]
```

---

## 🗑️ What gets REMOVED from V4
All hard coded parameters will be eliminated:
- ❌ Remove `LotSize` input
- ❌ Remove `AtrSlMultiplier`
- ❌ Remove `AtrTpMultiplier`
- ❌ Remove all manual threshold settings
- ❌ Remove fixed session time windows

---

## 📅 Development Timeline
| Week | Task |
|---|------|
| 1 | Implement Tri-Brain neural layer architecture |
| 2 | Build Liquidity Map detection engine |
| 3 | Live Position Agent thread system |
| 4 | Time Warp memory & Drawdown Governor |
| 5 | 6 month backtest validation & weight tuning |
| 6 | Zero configuration auto-calibration |

---

## Performance Targets
✅ Maximum Drawdown < 8%
✅ Win Rate > 72%
✅ Profit Factor > 1.8
✅ Zero user configuration required
