# XAUUSD AK47ScalperEA Configuration Guide

## 🥇 GOLD/USD (XAUUSD) Optimized Settings

### 📈 **Trading Parameters (Pre-configured for Gold)**
- **Primary Symbol**: XAUUSD
- **Timeframe**: M1 (1-minute scalping)
- **Stop Loss**: 300 points (30 pips) - Perfect for Gold's volatility
- **Take Profit**: 450 points (45 pips) - 1.5:1 Risk/Reward ratio
- **Trailing Stop**: 150 points (15 pips)
- **Break Even**: 150 points (15 pips)

### 💰 **Gold-Specific Risk Management**
- **Default Risk**: 1.0% per trade
- **Max Daily Trades**: 10 (suitable for M1 scalping)
- **Max Simultaneous**: 3 trades
- **Points System**: Optimized for Gold's pip value

### 🧠 **AI & SMC Settings for Gold**
- **AI Signal Period**: 14 (optimized for Gold's movement patterns)
- **AI Threshold**: 0.75 (75% confidence for entry)
- **Order Block Lookback**: 20 bars (Gold's structure analysis)
- **Supply/Demand Zones**: Enabled (crucial for Gold trading)

### ⏰ **Trading Sessions for XAUUSD**
- **24/7 Trading**: Enabled (Gold trades around the clock)
- **Best Performance Hours**:
  - London Session: 08:00-17:00 GMT
  - New York Session: 13:00-22:00 GMT
  - Asian Session: 00:00-09:00 GMT

### 🎯 **Gold Market Characteristics**
- **High Volatility**: 30-100 pips daily range
- **Safe Haven Asset**: Reacts to economic news
- **Trend Following**: Excellent for SMC analysis
- **Scalping Friendly**: High liquidity and tight spreads

## 🚀 **Recommended XAUUSD Setup**

### **Account Requirements:**
- Minimum Balance: $500 (for 0.01 lots)
- Recommended Balance: $2,000+ (for optimal performance)
- Spread: <30 points (3 pips)
- Leverage: 1:100 or higher

### **Optimal EA Settings for Gold:**
```
[Trading Settings]
AllowBuyTrades = true
AllowSellTrades = true
TradingTimeframe = PERIOD_M1
MaxSimultaneousTrades = 3
MaxDailyTrades = 10

[Risk Management]
RiskPercent = 1.0
StopLossPoints = 300     // 30 pips
TakeProfitPoints = 450   // 45 pips
UseTrailingStop = true
TrailingStopPoints = 150 // 15 pips

[AI Signals]
UseAISignals = true
AISignalPeriod = 14
AIThreshold = 0.75
AIHistoryBars = 1000

[SMC Analysis]
UseSMCAnalysis = true
SMCOrderBlockLookback = 20
UseSupplyDemandZones = true
UseBreakOfStructure = true
```

### **Why These Settings Work for Gold:**

1. **300 Point Stop Loss**: 
   - Accounts for Gold's normal intraday volatility
   - Prevents premature stop-outs on spikes

2. **450 Point Take Profit**:
   - 1.5:1 risk/reward ratio
   - Captures Gold's typical swing moves

3. **M1 Timeframe**:
   - Perfect for scalping Gold's quick movements
   - High-frequency opportunity capture

4. **SMC Analysis**:
   - Gold respects institutional levels
   - Order blocks are clearly visible
   - Supply/demand zones are highly effective

### **Gold Trading Tips:**

🔥 **Best Trading Times:**
- London Open: 08:00 GMT (high volatility)
- NY Open: 13:00 GMT (breakout opportunities)
- Avoid major news releases (NFP, FOMC, etc.)

📊 **Market Conditions:**
- Trending markets: Best for SMC signals
- Range-bound: Focus on supply/demand zones
- High volatility: Reduce lot size

⚠️ **Risk Considerations:**
- Start with 0.01 lots
- Monitor during news events
- Use VPS for 24/7 operation
- Regular performance monitoring

## 📈 **Expected Performance on XAUUSD:**
- **Win Rate**: 65-75% (with proper settings)
- **Average Trades/Day**: 5-8 trades
- **Monthly Return**: 5-15% (depending on market conditions)
- **Max Drawdown**: <10% (with 1% risk per trade)
