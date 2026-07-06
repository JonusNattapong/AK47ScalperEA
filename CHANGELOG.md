# Changelog - AK47 Scalper EA

All notable changes to this project will be documented in this file.

## [5.1.0] - HIGH-RISK / AGGRESSIVE MODE (Current)
### Added
- **Aggressive position sizing (`CalculateAggressiveLot`):** Lot is sized from
  `RiskPercentPerTrade`% of balance against the ATR stop distance, then amplified by
  how far the AI confidence overshoots `EntryConfidence`. Clamped to `MaxLotCap` and
  broker volume limits.
- **Pyramiding:** `MaxPositionsPerSymbol` allows stacking multiple positions per symbol.
- **New tunable inputs:** `AggressiveMode`, `RiskPercentPerTrade`, `AggressiveLotFactor`,
  `MaxLotCap`, `EntryConfidence`, `MaxPositionsPerSymbol`, `ReentryCooldownSec`,
  `AtrSlMultiplier`, `AtrTpMultiplier`.
- **Dashboard:** shows HIGH-RISK banner, per-trade risk % and confidence gate.
### Changed
- Aggressive defaults: `MaxDailyDrawdown` 4%→15%, `DailyProfitTarget` 2.5%→10%,
  `MaxOrdersTotal` 4→8, `MaxSpread` 35→45.
- Entry gate lowered (confidence `0.82`→`EntryConfidence` 0.65) and re-entry cooldown
  cut (`300s`→`ReentryCooldownSec` 60s) for higher trade frequency.
- SL/TP now use `AtrSlMultiplier` (1.2, tighter) and `AtrTpMultiplier` (3.2, wider R:R).
### Note
- ⚠️ This is a high-risk configuration and can produce large drawdowns. Set
  `AggressiveMode = false` to fall back to fixed `LotSize` and conservative behaviour.

## [5.0.0] - PURE AGENT EDITION
### Added
- **Quantum Feature Engine (`AK47_Quantum.mqh`):** New self-contained, neural-network-free
  feature extractor that feeds the Kilo API agent. Provides per-symbol price-action,
  market-structure and swarm-correlation features (0–15) plus a quantum layer (16–18):
  return entropy, Hurst market-memory and volatility-regime.
- **Multi-symbol handle cache:** Indicator handles are created lazily per traded symbol,
  making feature extraction correct across all symbols in `TradingSymbols`.
- **Session engine & `StringTrim` helper** restored into the Quantum module after the
  neural-network module was removed.
### Fixed
- Replaced the legacy value-style `iATR()` call (invalid in MQL5) with a handle-based
  `GetAtrValue()` helper so the EA compiles and computes SL/TP correctly.

## [3.0.0] - EVO Autonomous Edition
### Added
- **Dual-Brain Architecture:** Integrated M1 and H1 Neural Networks for consensus-based decision making.
- **SMC Engine:** Implemented Order Block (Supply/Demand) detection for high-precision entries.
- **Intelligence-Based Risk (IBR):** Dynamic lot scaling based on AI confidence levels (Confidence-based Lot).
- **Self-Correction System:** Autonomous win rate monitoring and threshold auto-tuning.
- **Professional Dashboard:** Clean, autonomous-focused TUI on the chart.

## [2.0.0] - Agentic Workspace Integration
### Added
- **Kilo AI Agent Integration:** Connected the EA to the Cloud AI Workspace for fundamental news analysis.
- **DXY Filter:** Added real-time US Dollar Index correlation analysis to filter false breakouts.
- **Volume Flow Sensor:** Implemented Tick Speed and Volume Delta monitoring for momentum detection.
- **Native Calendar Support:** Direct integration with MT5 Economic Calendar API.

## [1.2.0] - Neural Core Stability
### Added
- **Neural Network Refinement:** Optimized Multilayer Perceptron (MLP) weights and training logic.
- **Self-Learning Capability:** Implemented post-trade weight updates to adapt to market volatility.

## [1.0.0] - Initial Release
### Added
- Basic Scalping logic using RSI, Bollinger Bands, and ATR.
- Trailing Stop and Spread protection modules.
- Multilayer Perceptron (MLP) base implementation.
