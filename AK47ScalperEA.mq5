//+------------------------------------------------------------------+
//|                                                  AK47ScalperEA.mq5 |
//|                        Copyright 2026, AK47 Scalper EA Developer |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property link      ""
#property version   "5.10"
#property strict
#property description "AK47 PURE AGENT EDITION - 100% API DRIVEN | HIGH-RISK MODE"

#include <Trade\Trade.mqh>
#include "AK47_News.mqh"
#include "AK47_Quantum.mqh"

// EA Settings
input double LotSize           = 0.01;   // Fallback lot when risk sizing is OFF
input double MaxDailyDrawdown  = 15.0;   // % Max drawdown per day (HIGH RISK)
input double DailyProfitTarget = 10.0;   // % Daily profit target to stop
input int    BaseMagicNumber   = 4747;
input int    MaxOrdersTotal    = 8;      // Max concurrent positions (HIGH RISK)
input int    MaxSpread         = 45;     // Max allowed spread in points

// --- 🔥 HIGH-RISK / AGGRESSIVE MODE ---
input bool   AggressiveMode        = true;   // Master switch for high-risk sizing
input double RiskPercentPerTrade   = 3.0;    // % of balance risked per trade
input double AggressiveLotFactor   = 6.0;    // Confidence overshoot -> lot amplifier
input double MaxLotCap             = 5.0;    // Hard ceiling on any single lot
input double EntryConfidence       = 0.65;   // Min AI confidence to fire (lower = more trades)
input int    MaxPositionsPerSymbol = 3;      // Pyramiding cap per symbol (HIGH RISK)
input int    ReentryCooldownSec    = 60;     // Seconds between entries on same symbol
input double AtrSlMultiplier       = 1.2;    // Tight SL (ATR x)
input double AtrTpMultiplier       = 3.2;    // Wide TP (ATR x) -> aggressive R:R

// --- KILO AGENT API ---
input bool   UseNewsAiFilter   = true;   // 🔴 ALWAYS ON NOW
input string Kilo_ApiKey       = "YOUR_API_KEY_HERE";
input string Kilo_ApiUrl       = "https://api.kilocode.ai/v1/chat/completions";
input int    ApiCallInterval   = 15;     // Seconds between API calls

// --- Multi Symbol Settings ---
input string TradingSymbols    = "XAUUSD,EURUSD,GBPUSD,USDJPY";
input int    TrailingStart     = 100;
input int    TrailingStop      = 30;

// --- Symbol Instance ---
struct SymbolInstance
{
   string      symbol;
   int         magicNumber;
   int         digit;
   double      point;
   datetime    lastApiCall;
   string      lastAction;
   double      lastConfidence;
   string      lastInsight;
   bool        isTradingDisabled;
   datetime    lastTradeTime;
};

SymbolInstance g_symbols[8];
int            g_symbolCount = 0;
NewsAiClient  *newsAi;
CTrade        trade;
double         dailyStartBalance;
bool           isGlobalDisabled = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   newsAi = new NewsAiClient(Kilo_ApiKey, Kilo_ApiUrl);
   InitQuantumEngine();

   // Parse symbol list
   string symbols[];
   StringSplit(TradingSymbols, ',', symbols);
   g_symbolCount = ArraySize(symbols);
   if(g_symbolCount > 8) g_symbolCount = 8;

   // Initialize each symbol
   for(int i=0; i<g_symbolCount; i++)
   {
      SymbolInstance &sym = g_symbols[i];
      sym.symbol = StringTrim(symbols[i]);
      sym.magicNumber = BaseMagicNumber + i;

      if(!SymbolSelect(sym.symbol, true))
      {
         Print("Symbol not available: ", sym.symbol);
         g_symbolCount--; i--; continue;
      }

      sym.digit = (int)SymbolInfoInteger(sym.symbol, SYMBOL_DIGITS);
      sym.point = SymbolInfoDouble(sym.symbol, SYMBOL_POINT);
      sym.lastApiCall = 0;
      sym.lastAction = "WAIT";
      sym.lastConfidence = 0.0;
      sym.isTradingDisabled = false;
      sym.lastTradeTime = 0;

      Print("✅ Initialized: ", sym.symbol, " Magic: ", sym.magicNumber);
   }

   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("✅ AK47 PURE AGENT STARTED | ", g_symbolCount, " symbols loaded");
   Print("✅ ALL NEURAL NETWORKS REMOVED | 100% KILO API DRIVEN");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   delete newsAi;
   DeinitQuantumEngine();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateDashboard();
   if(isGlobalDisabled) return;

   // Global Protection
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profitPercent = ((currentEquity - dailyStartBalance) / dailyStartBalance) * 100.0;

   if(profitPercent <= -MaxDailyDrawdown) { isGlobalDisabled = true; return; }
   if(profitPercent >= DailyProfitTarget) { isGlobalDisabled = true; return; }

   if(PositionsTotalMagic() >= MaxOrdersTotal) return;
   if(GetCurrentSession() == SESSION_OFF) return;

   // Process each symbol
   for(int i=0; i<g_symbolCount; i++)
   {
      SymbolInstance &sym = g_symbols[i];
      if(sym.isTradingDisabled) continue;
      // HIGH RISK: allow stacking up to MaxPositionsPerSymbol on the same symbol
      if(PositionsTotalMagicSymbol(sym.magicNumber) >= MaxPositionsPerSymbol) continue;

      int spread = (int)SymbolInfoInteger(sym.symbol, SYMBOL_SPREAD);
      if(spread > MaxSpread) continue;

      // Call Kilo API
      if(TimeCurrent() > sym.lastApiCall + ApiCallInterval)
      {
         double features[19];
         GetMarketFeatures(sym.symbol, features, "USDX", "SPX500", "US10Y", "BTCUSD");
         GetQuantumFeatures(sym.symbol, features, 16);

         newsAi.AnalyzeMarketWithKilo(sym.symbol, features);
         sym.lastApiCall = TimeCurrent();
         sym.lastAction = newsAi.GetAction();
         sym.lastConfidence = newsAi.GetConfidence();
         sym.lastInsight = newsAi.GetInsight();
      }

      // Execute Agent Order (HIGH RISK: lower confidence gate + faster re-entry)
      if(sym.lastConfidence > EntryConfidence && TimeCurrent() > sym.lastTradeTime + ReentryCooldownSec)
      {
         double atr = GetAtrValue(sym.symbol);
         if(atr <= 0.0) continue;
         double sl = atr * AtrSlMultiplier;
         double tp = atr * AtrTpMultiplier;
         double lot = CalculateAggressiveLot(sym.symbol, sl, sym.lastConfidence);
         if(lot <= 0.0) continue;

         if(sym.lastAction == "BUY")
         {
            double ask = SymbolInfoDouble(sym.symbol, SYMBOL_ASK);
            trade.Buy(lot, sym.symbol, 0, NormalizeDouble(ask - sl, sym.digit), NormalizeDouble(ask + tp, sym.digit), sym.magicNumber, "KILO AGENT BUY");
            sym.lastTradeTime = TimeCurrent();
         }
         else if(sym.lastAction == "SELL")
         {
            double bid = SymbolInfoDouble(sym.symbol, SYMBOL_BID);
            trade.Sell(lot, sym.symbol, 0, NormalizeDouble(bid + sl, sym.digit), NormalizeDouble(bid - tp, sym.digit), sym.magicNumber, "KILO AGENT SELL");
            sym.lastTradeTime = TimeCurrent();
         }
      }
   }

   ManagePositions();
}

//+------------------------------------------------------------------+
//| Dashboard                                                        |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = currentEquity - dailyStartBalance;
   double profitPercent = (dailyProfit / dailyStartBalance) * 100.0;

   string text = "";
   text += "╔════════════════════════════════════════╗\n";
   text += "║     AK47 PURE AGENT EDITION           ║\n";
   text += "║    🔥 100% KILO API DRIVEN 🔥         ║\n";
   text += StringFormat("║   %s                        ║\n", AggressiveMode ? "⚠️  HIGH-RISK MODE ⚠️ " : "🛡️  STANDARD MODE   ");
   text += "╠════════════════════════════════════════╣\n";
   text += StringFormat("║  Status: %s                           ║\n", isGlobalDisabled ? "🔴 GLOBAL PAUSED" : "🟢 ACTIVE");
   text += StringFormat("║  Daily P/L: %+7.2f %s  (%+5.2f %%)     ║\n", dailyProfit, AccountInfoString(ACCOUNT_CURRENCY), profitPercent);
   text += StringFormat("║  Risk/Trade: %.1f%% | Conf>=%.0f%%          ║\n", RiskPercentPerTrade, EntryConfidence*100);
   text += "╠────────────────────────────────────────╣\n";

   for(int i=0; i<g_symbolCount; i++)
   {
      SymbolInstance &sym = g_symbols[i];
      text += StringFormat("║  %-7s | %-4s | %3.0f %%                 ║\n",
         sym.symbol, sym.lastAction, sym.lastConfidence*100);
   }

   text += "╠────────────────────────────────────────╣\n";
   text += StringFormat("║  Open Positions: %d / %d               ║\n", PositionsTotalMagic(), MaxOrdersTotal);
   text += "╚════════════════════════════════════════╝\n";
   text += "\n";
   text += "✅ NEURAL NETWORKS FULLY REMOVED\n";
   text += "✅ ALL DECISIONS FROM KILO API\n";

   Comment(text);
}

//+------------------------------------------------------------------+
//| HIGH-RISK Position Sizing                                        |
//|  - Risks RiskPercentPerTrade % of balance based on the SL size   |
//|  - Amplifies the lot as AI confidence overshoots EntryConfidence |
//|  - Clamped to broker volume limits and MaxLotCap                 |
//+------------------------------------------------------------------+
double CalculateAggressiveLot(string symbol, double slPriceDistance, double confidence)
{
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(minLot <= 0.0)  minLot  = 0.01;
   if(lotStep <= 0.0) lotStep = 0.01;

   // Conservative fallback when aggressive sizing is disabled or data is missing
   if(!AggressiveMode) return LotSize;

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * RiskPercentPerTrade / 100.0;

   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || slPriceDistance <= 0.0) return LotSize;

   // Money lost per 1.0 lot if the stop is hit
   double lossPerLot = (slPriceDistance / tickSize) * tickValue;
   if(lossPerLot <= 0.0) return LotSize;

   double lots = riskMoney / lossPerLot;

   // Confidence amplifier: the more the agent overshoots the entry gate, the bigger the size
   double overshoot = confidence - EntryConfidence;
   if(overshoot < 0.0) overshoot = 0.0;
   lots *= (1.0 + overshoot * AggressiveLotFactor);

   // Clamp to caps and broker limits, then snap to lot step
   if(lots > MaxLotCap) lots = MaxLotCap;
   if(maxLot > 0.0 && lots > maxLot) lots = maxLot;
   if(lots < minLot) lots = minLot;

   lots = MathFloor(lots / lotStep) * lotStep;
   if(lots < minLot) lots = minLot;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
int PositionsTotalMagic()
{
   int count = 0;
   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         int magic = (int)PositionGetInteger(POSITION_MAGIC);
         if(magic >= BaseMagicNumber && magic < BaseMagicNumber + 8) count++;
      }
   }
   return count;
}

int PositionsTotalMagicSymbol(int magic)
{
   int count = 0;
   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magic) count++;
   }
   return count;
}

void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(magic < BaseMagicNumber || magic >= BaseMagicNumber + 8) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double point = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_POINT);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_BID);
         if(bid - openPrice > TrailingStart * point)
         {
            double newSL = NormalizeDouble(bid - TrailingStop * point, (int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL), SYMBOL_DIGITS));
            if(newSL > currentSL + 10 * point) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
      }
      else
      {
         double ask = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_ASK);
         if(openPrice - ask > TrailingStart * point)
         {
            double newSL = NormalizeDouble(ask + TrailingStop * point, (int)SymbolInfoInteger(PositionGetString(POSITION_SYMBOL), SYMBOL_DIGITS));
            if(currentSL == 0 || newSL < currentSL - 10 * point) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
      }
   }
}
//+------------------------------------------------------------------+
