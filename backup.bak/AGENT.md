# AGENT.md

This file provides guidance to Clew Code when working with code in this repository.

## Project Overview

AK47 Scalper EA is a multi-symbol scalping Expert Advisor for MetaTrader 5 (MQL5). No internal prediction model — every trade decision is delegated to the Kilo AI Agent API. The EA extracts a 19-dimension quantitative feature vector from live market data, sends it to the Kilo agent, and executes only on high-confidence signals (`confidence > 0.82`) under a strict risk framework.

A companion Node.js web dashboard provides REST + WebSocket endpoints for monitoring trades, signals, chat, and journal entries.

## Source Files

| File | Role |
|---|---|
| `AK47ScalperEA.mq5` | Main EA — symbol orchestration, risk gate, execution, trailing, dashboard overlay |
| `AK47_Quantum.mqh` | Self-contained feature engine: indicators, market structure, swarm correlations, entropy, Hurst exponent, volatility regime |
| `AK47_News.mqh` | `NewsAiClient` class — Kilo API HTTP client (`WebRequest`) + MT5 economic calendar |
| `web/server/server.js` | Express + Socket.IO backend |
| `web/db.js` | SQLite data layer using `better-sqlite3` (WAL mode, 7 tables) |
| `web/package.json` | Dependencies: express, socket.io, better-sqlite3, cors |

## Architecture

### Tick Cycle Data Flow
```
GetMarketFeatures() → GetQuantumFeatures() → AnalyzeMarketWithKilo()
  → confidence > 0.82? → Risk gates (drawdown, spread, session, cooldown) → trade.Buy/Sell() → ManagePositions()
```

### Key Design Details

- **Multi-symbol**: `SymbolInstance` struct array (max 8), each with its own magic number (`BaseMagicNumber + i`), lazy indicator handles, and API call timer.
- **Lazy indicator handles**: `GetHandleSet()` creates per-symbol iRSI/iCCI/iMACD/etc. on first access, cached in `g_qh[]`.
- **Session engine**: `GetCurrentSession()` returns ASIAN/LONDON/NEWYORK/OFF based on server time (GMT assumed). No entries during OFF/weekend.
- **Risk gates** (checked every tick): daily drawdown limit, daily profit target, max total orders, max spread, per-symbol 300s cooldown.
- **SL/TP**: ATR-dynamic — `SL = ATR × 1.5`, `TP = ATR × 2.5`.
- **Trailing stop**: Activates at `TrailingStart` points profit, maintains `TrailingStop` distance.
- **Global pause**: `isGlobalDisabled` flag stops all trading for the day when daily limit hit.
- **Kilo API expects**: JSON response with fields `action` ("BUY"/"SELL"/"WAIT"), `confidence` (0-1 double), `insight` (string).
- **AK47_AI.mqh was fully removed** in V5.0 — all neural network code was deleted.

### Web Dashboard

- Express server in `web/` with SQLite persistence (7 tables: ea_state, symbols, positions, chat_messages, signals, strategy_config, journal_entries).
- REST endpoints: `/api/state`, `/api/symbols`, `/api/positions`, `/api/signals`, `/api/chat`, `/api/strategy`, `/api/journal`.
- Real-time updates via Socket.IO (`ea:state`, `ea:symbols`, `ea:positions`, `ea:signal`, `chat:message`, etc.).
- Frontend: served from `web/public/` directory. If missing, create it and serve your `index.html` there.
- No MT5 connectivity built in — data pushed via REST API from EA or external source.

## Development

### MQL5 EA
- **Compile**: Open `AK47ScalperEA.mq5` in MetaEditor and press F7.
- **Test**: Run MT5 Strategy Tester with the EA attached to a symbol.
- **No automated test framework** — MQL5 has no package manager or test runner. Validation is via backtest, forward demo, or live demo.
- **Remember**: `.ex5` binaries in `.gitignore`. Always commit the `.mq5` source.
- **CONTRIBUTING.md** has the PR checklist and testing notes template.

### Web Dashboard
```bash
cd web
npm install
npm start        # http://localhost:3000
```

**Note**: `better-sqlite3` requires native compilation. On Windows you may need `windows-build-tools` or Visual Studio Build Tools. The `cors` package is used in `server.js` but not listed in `package.json` — install it separately if missing.

### Environment Requirements
- MetaTrader 5 with Economic Calendar and WebRequest enabled.
- Kilo API key (`Kilo_ApiKey` input) — without it the EA silently waits.
- WebRequest whitelist: add `https://api.kilocode.ai` in MT5 Tools → Options → Expert Advisors.

## Important Behaviors

- The EA attaches to a **single chart** and manages all symbols internally via `TradingSymbols` parameter.
- Indicator handles are created lazily per symbol — first tick may show fallback values (`0.5`) while handles initialize.
- Zero-trade sessions are expected when the Kilo agent returns low confidence.
- The EA calls the Kilo API every `ApiCallInterval` seconds per symbol (max 8 symbols, so up to 8 calls per interval).
- `StringTrim()` helper lives in `AK47_Quantum.mqh` (MQL5's built-in trim modifies in-place — need a function).
- `UseNewsAiFilter` input is declared but always effectively ON in Pure Agent Edition — the feature toggle is vestigial.
