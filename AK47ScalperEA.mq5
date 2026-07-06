//+------------------------------------------------------------------+
//|                                                  AK47ScalperEA.mq5 |
//|                        Copyright 2026, AK47 Scalper EA Developer |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property link      ""
#property version   "5.00"
#property strict
#property description "AK47 PURE AGENT EDITION - 100% API DRIVEN"

#include <Trade\Trade.mqh>
#include "AK47_News.mqh"
#include "AK47_Quantum.mqh"

// EA Settings (set once via properties window, overridable via dashboard)
input double LotSize           = 0.01;
input double MaxDailyDrawdown  = 10.0;   // % Max drawdown per day
input double DailyProfitTarget = 15.0;   // % Daily profit target to stop
input int    BaseMagicNumber   = 4747;
input int    MaxOrdersTotal    = 8;
input int    MaxSpread         = 50;     // Max allowed spread in points

// --- AI AGENT API ---
input bool   UseNewsAiFilter   = true;
input string Kilo_ApiKey       = "";            // AI API key ("" = Free Mode)
input string Kilo_ApiUrl       = "https://api.kilocode.ai/v1/chat/completions";
input int    AI_Provider       = 0;             // 0=OpenAI-compat, 1=Anthropic, 2=Ollama
input string AI_Model          = "kilo-alpha-1"; // model name (gpt-4, claude-3, etc.)
input int    ApiCallInterval   = 15;     // Seconds between API calls

// --- High Risk Mode ---
input bool   HighRiskMode      = true;
input double RiskConfidence    = 0.30;     // Min confidence in high-risk mode

// --- 24/7 Mode ---
input bool   Allow247          = true;    // Allow trading on weekends & all hours

// --- Multi Symbol Settings ---
input string TradingSymbols    = "XAUUSD,EURUSD,GBPUSD,USDJPY";
input int    TrailingStart     = 100;
input int    TrailingStop      = 30;

// --- TinyFish News Context ---
input string TinyFish_ApiKey       = "";       // empty = disabled

// --- Custom Instruction (natural language) ---
input string CustomInstruction     = "";       // e.g. "Buy XAUUSD only if RSI < 30"
input int    TinyFish_Interval     = 1800;     // seconds between news refresh per symbol
input int    TinyFish_MaxResults   = 3;        // max search results per query

//+------------------------------------------------------------------+
//| Runtime Config (modifiable via dashboard)                        |
//+------------------------------------------------------------------+
struct RuntimeConfig
{
   bool   highRiskMode;
   double riskConfidence;
   int    maxOrdersTotal;
   double lotSize;
   double maxDailyDrawdown;
   double dailyProfitTarget;
   int    maxSpread;
   int    trailingStart;
   int    trailingStop;
   bool   allow247;
};

RuntimeConfig g_config;

//+------------------------------------------------------------------+
//| Strategy Profiles                                                |
//+------------------------------------------------------------------+
#define STRAT_AUTO     0
#define STRAT_SCALP    1
#define STRAT_TREND    2
#define STRAT_NEWS     3
#define STRAT_CUSTOM   4
#define STRAT_COUNT    5

string g_stratName[STRAT_COUNT] = {"Auto", "Scalp", "Trend", "News", "Custom"};
string g_stratPrompt[STRAT_COUNT] = {
   "You are the AK47 Master Trader. Your desk has MT5 candle data, indicators, and a REAL-TIME Economic Calendar.",
   "You are a SCALPING specialist. Focus on short-term price action, quick entries and exits within 1-2 bars. Prefer small quick profits and tight stops. Prioritize speed over catching big moves.",
   "You are a TREND TRADER. Identify and follow established trends using moving averages and market structure. Let profits run with wider stops. Avoid counter-trend entries.",
   "You are a NEWS TRADER. Prioritize economic calendar events above all. Trade the volatility around high-impact news releases. Use wider stops during news. Low-impact events are noise.",
   "" // Custom - loaded from file
};
int    g_stratCurrent = STRAT_AUTO;

//+------------------------------------------------------------------+
//| Calendar Event System                                            |
//+------------------------------------------------------------------+
#define EVT_WAIT       0
#define EVT_BUY        1
#define EVT_SELL       2
#define EVT_BUY_STOP   3
#define EVT_SELL_STOP  4
#define EVT_BUY_LIMIT  5
#define EVT_SELL_LIMIT 6
#define EVT_ACTIONS    7

string g_evtActionName[EVT_ACTIONS] = {"WAIT", "BUY", "SELL", "BUY_STOP", "SELL_STOP", "BUY_LIMIT", "SELL_LIMIT"};

struct CalendarEvent
{
   datetime eventTime;
   string   eventName;
   int      importance;     // 1=low, 2=medium, 3=high
   string   currency;
   int      action;         // EVT_* constant
   bool     isActive;
   ulong    pendingTicket;  // 0 = no ticket
   long     eventId;
};

#define MAX_EVENTS 8
CalendarEvent g_events[MAX_EVENTS];
int            g_eventCount = 0;
datetime       g_lastCalendarScan = 0;

//+------------------------------------------------------------------+
//| Symbol Instance                                                  |
//+------------------------------------------------------------------+
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

   // Auto-adaptive: timeframe and strategy
   ENUM_TIMEFRAMES activeTf;            // current trading timeframe
   MARKET_REGIME   lastRegime;          // last detected regime
   bool            tfChanged;           // flag when timeframe changes

   // News context (TinyFish)
   string      newsAccum;
   datetime    lastNewsFetch;

   // Advanced risk management
   int         consecutiveLosses;
   double      lastTradePnl;
   datetime    lastLossTime;
   int         totalLosses;
   int         totalWins;
};

SymbolInstance g_symbols[12];
int            g_symbolCount = 0;
NewsAiClient  *newsAi;
CTrade        trade;
double         dailyStartBalance;
bool           isGlobalDisabled = false;
int            g_autoScanCounter = 0;     // tick counter for auto-scan
int            g_strategySwitchCounter = 0; // tick counter for auto-strategy

//+------------------------------------------------------------------+
//| Dashboard object constants                                       |
//+------------------------------------------------------------------+
#define DASH_PREFIX    "AK47_"
#define DASH_X         10
#define DASH_Y_START   8
#define DASH_LINE_H    17
#define BTN_W          200
#define BTN_H          16

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   newsAi = new NewsAiClient(Kilo_ApiKey, Kilo_ApiUrl);
   newsAi.SetTinyFishKey(TinyFish_ApiKey);
   newsAi.SetInstruction(CustomInstruction);
   newsAi.SetProvider(AI_Provider);
   newsAi.SetModel(AI_Model);
   InitQuantumEngine();

   // Set initial strategy prompt
   ApplyStrategyProfile();

   // Init runtime config from input params
   g_config.highRiskMode      = HighRiskMode;
   g_config.riskConfidence    = RiskConfidence;
   g_config.maxOrdersTotal    = MaxOrdersTotal;
   g_config.lotSize           = LotSize;
   g_config.maxDailyDrawdown  = MaxDailyDrawdown;
   g_config.dailyProfitTarget = DailyProfitTarget;
   g_config.maxSpread         = MaxSpread;
   g_config.trailingStart     = TrailingStart;
   g_config.trailingStop      = TrailingStop;
   g_config.allow247          = Allow247;

   // Parse symbol list
   string symbols[];
   StringSplit(TradingSymbols, ',', symbols);
   g_symbolCount = ArraySize(symbols);
   if(g_symbolCount > 8) g_symbolCount = 8;

   // Initialize each symbol
   for(int i=0; i<g_symbolCount; i++)
   {
      g_symbols[i].symbol = StringTrim(symbols[i]);
      g_symbols[i].magicNumber = BaseMagicNumber + i;

      if(!SymbolSelect(g_symbols[i].symbol, true))
      {
         Print("Symbol not available: ", g_symbols[i].symbol);
         g_symbolCount--; i--; continue;
      }

      g_symbols[i].digit = (int)SymbolInfoInteger(g_symbols[i].symbol, SYMBOL_DIGITS);
      g_symbols[i].point = SymbolInfoDouble(g_symbols[i].symbol, SYMBOL_POINT);
      g_symbols[i].lastApiCall = 0;
      g_symbols[i].lastAction = "WAIT";
      g_symbols[i].lastConfidence = 0.0;
      g_symbols[i].isTradingDisabled = false;
      g_symbols[i].lastTradeTime = 0;
      g_symbols[i].activeTf = _Period;
      g_symbols[i].lastRegime = REGIME_CALM;
      g_symbols[i].tfChanged = false;
      g_symbols[i].newsAccum = "";
      g_symbols[i].lastNewsFetch = 0;
      g_symbols[i].consecutiveLosses = 0;
      g_symbols[i].lastTradePnl = 0.0;
      g_symbols[i].lastLossTime = 0;
      g_symbols[i].totalLosses = 0;
      g_symbols[i].totalWins = 0;

      Print("Initialized: ", g_symbols[i].symbol, " Magic: ", g_symbols[i].magicNumber);
   }

   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("AK47 PURE AGENT STARTED | ", g_symbolCount, " symbols loaded");

   // Initial calendar scan
   ScanEconomicCalendar();

   CreateDashboardObjects();
   UpdateDashboard();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteDashboardObjects();
   CancelAllEventOrders();
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
   TrackClosedPositions();
   if(isGlobalDisabled) return;

   // Daily calendar refresh
   if(TimeCurrent() > g_lastCalendarScan + 3600)
      ScanEconomicCalendar();

   // Check pending event orders
   CheckEventOrders();

   // Global Protection
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profitPercent = ((currentEquity - dailyStartBalance) / dailyStartBalance) * 100.0;

   if(profitPercent <= -g_config.maxDailyDrawdown) { isGlobalDisabled = true; return; }
   if(!g_config.highRiskMode && profitPercent >= g_config.dailyProfitTarget) { isGlobalDisabled = true; return; }

   int maxOrders = g_config.highRiskMode ? 8 : g_config.maxOrdersTotal;
   if(PositionsTotalMagic() >= maxOrders) return;
   if(!g_config.allow247 && !g_config.highRiskMode && GetCurrentSession() == SESSION_OFF) return;

   // --- Auto-Strategy: switch based on dominant market regime ---
   g_strategySwitchCounter++;
   if(g_strategySwitchCounter >= 100)
   {
      g_strategySwitchCounter = 0;
      int trendCount=0, rangeCount=0, volCount=0, calmCount=0;
      for(int si=0; si<g_symbolCount; si++)
      {
         MARKET_REGIME r = DetectMarketRegimeEx(g_symbols[si].symbol, g_symbols[si].activeTf);
         switch(r) {
            case REGIME_TRENDING: trendCount++; break;
            case REGIME_RANGING:  rangeCount++; break;
            case REGIME_VOLATILE: volCount++;   break;
            case REGIME_CALM:     calmCount++;  break;
         }
      }
      int newStrat = STRAT_AUTO;
      int maxCount = MathMax(MathMax(trendCount, rangeCount), MathMax(volCount, calmCount));
      if(maxCount > 0 && maxCount == trendCount)      newStrat = STRAT_TREND;
      else if(maxCount > 0 && maxCount == rangeCount) newStrat = STRAT_SCALP;
      else if(maxCount > 0 && maxCount == volCount)   newStrat = STRAT_AUTO;
      if(newStrat != g_stratCurrent)
      {
         g_stratCurrent = newStrat;
         ApplyStrategyProfile();
         Print("Auto-strategy: switched to ", g_stratName[g_stratCurrent]);
      }
   }

   // --- Auto-Scan: discover new forex symbols every 500 ticks ---
   g_autoScanCounter++;
   if(g_autoScanCounter >= 500)
   {
      g_autoScanCounter = 0;
      int totalAvail = SymbolsTotal(false);
      for(int si=0; si<totalAvail && g_symbolCount < 12; si++)
      {
         string sym = SymbolName(si, false);
         bool already = false;
         for(int gi=0; gi<g_symbolCount; gi++)
            if(g_symbols[gi].symbol == sym) { already = true; break; }
         if(already) continue;
         if(StringFind(sym, "XAU") >=0 || StringFind(sym, "XAG") >=0 ||
            StringFind(sym, "EUR") == 0 || StringFind(sym, "GBP") == 0 ||
            StringFind(sym, "USD") == 3 || StringFind(sym, "JPY") == 3 ||
            StringFind(sym, "AUD") == 0 || StringFind(sym, "NZD") == 0 ||
            StringFind(sym, "CAD") == 3 || StringFind(sym, "CHF") == 3)
         {
            if(!SymbolSelect(sym, true)) continue;
            int idx = g_symbolCount;
            g_symbols[idx].symbol = sym;
            g_symbols[idx].magicNumber = BaseMagicNumber + idx;
            g_symbols[idx].digit = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
            g_symbols[idx].point = SymbolInfoDouble(sym, SYMBOL_POINT);
            g_symbols[idx].lastApiCall = 0;
            g_symbols[idx].lastAction = "WAIT";
            g_symbols[idx].lastConfidence = 0.0;
            g_symbols[idx].isTradingDisabled = false;
            g_symbols[idx].lastTradeTime = 0;
            g_symbols[idx].activeTf = _Period;
            g_symbols[idx].lastRegime = REGIME_CALM;
            g_symbols[idx].tfChanged = false;
            g_symbols[idx].newsAccum = "";
            g_symbols[idx].lastNewsFetch = 0;
            g_symbols[idx].consecutiveLosses = 0;
            g_symbols[idx].lastTradePnl = 0.0;
            g_symbols[idx].lastLossTime = 0;
            g_symbols[idx].totalLosses = 0;
            g_symbols[idx].totalWins = 0;
            g_symbolCount++;
            Print("Auto-scan: added ", sym, " (total: ", g_symbolCount, ")");
         }
      }
      if(g_symbolCount > 0)
         Print("Auto-scan complete: ", g_symbolCount, " symbols active");
   }

   // Process each symbol
   for(int i=0; i<g_symbolCount; i++)
   {
      if(g_symbols[i].isTradingDisabled) continue;
      if(PositionsTotalMagicSymbol(g_symbols[i].magicNumber) >= 1) continue;

      int spread = (int)SymbolInfoInteger(g_symbols[i].symbol, SYMBOL_SPREAD);
      if(spread > g_config.maxSpread) continue;

      // --- Auto-Timeframe: adapt to market regime ---
      MARKET_REGIME currentRegime = DetectMarketRegimeEx(g_symbols[i].symbol, g_symbols[i].activeTf);
      if(currentRegime != g_symbols[i].lastRegime)
      {
         ENUM_TIMEFRAMES newTf = RegimeToTimeframe(currentRegime);
         if(newTf != g_symbols[i].activeTf)
         {
            g_symbols[i].activeTf = newTf;
            g_symbols[i].tfChanged = true;
         }
         g_symbols[i].lastRegime = currentRegime;
      }

      // Refresh news context via TinyFish
      if(TinyFish_ApiKey != "" && TimeCurrent() > g_symbols[i].lastNewsFetch + TinyFish_Interval)
      {
         string news = "";
         if(newsAi.SearchTinyFish(g_symbols[i].symbol, TinyFish_MaxResults, news) && news != "")
         {
            string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES);
            string entry = "[" + timestamp + "] " + news;
            if(g_symbols[i].newsAccum == "")
               g_symbols[i].newsAccum = entry;
            else
               g_symbols[i].newsAccum = entry + " || " + g_symbols[i].newsAccum;
            if(StringLen(g_symbols[i].newsAccum) > 2000)
               g_symbols[i].newsAccum = StringSubstr(g_symbols[i].newsAccum, 0, 2000);
         }
         g_symbols[i].lastNewsFetch = TimeCurrent();
      }

      // Call Kilo API
      if(TimeCurrent() > g_symbols[i].lastApiCall + ApiCallInterval)
      {
         double features[20] = {0.5};
         GetMarketFeaturesEx(g_symbols[i].symbol, features, "USDX", "SPX500", "US10Y", "BTCUSD", g_symbols[i].activeTf);
         GetQuantumFeatures(g_symbols[i].symbol, features, 16);

         newsAi.AnalyzeMarketWithKilo(g_symbols[i].symbol, features, g_symbols[i].newsAccum);
         g_symbols[i].lastApiCall = TimeCurrent();
         g_symbols[i].lastAction = newsAi.GetAction();
         g_symbols[i].lastConfidence = newsAi.GetConfidence();
         g_symbols[i].lastInsight = newsAi.GetInsight();
      }

      // Execute Agent Order - AI BROKER MODE
      // Auto-adjust minConf based on available mode
      bool isFreeMode = (Kilo_ApiKey == "" || Kilo_ApiKey == "YOUR_API_KEY_HERE" || Kilo_ApiKey == "YOUR_API_KEY");
      double minConf;
      int    cooldown;
      if(g_config.highRiskMode)
      {
         minConf = g_config.riskConfidence;
         cooldown = 30;
      }
      else if(isFreeMode)
      {
         minConf = 0.55;  // Free mode: lower threshold so it actually trades
         cooldown = 120;   // 2 min cooldown
      }
      else
      {
         minConf = 0.75;  // API mode: higher confidence expected
         cooldown = 180;   // 3 min cooldown
      }

      // Adaptive cooldown: increase after consecutive losses
      if(g_symbols[i].consecutiveLosses >= 2)
         cooldown += g_symbols[i].consecutiveLosses * 120; // +2min per consecutive loss
      if(g_symbols[i].consecutiveLosses >= 4)
      {
         // Too many consecutive losses: disable for 30 min
         if(TimeCurrent() < g_symbols[i].lastLossTime + 1800)
         {
            g_symbols[i].lastInsight = "COOLDOWN: " + IntegerToString(g_symbols[i].consecutiveLosses) + " consecutive losses";
            continue;
         }
         g_symbols[i].consecutiveLosses = 0; // Reset after cooldown
      }

      if(g_symbols[i].lastConfidence > minConf && TimeCurrent() > g_symbols[i].lastTradeTime + cooldown)
      {
         // --- News Volatility Filter: reduce confidence near high-impact events ---
         double newsPenalty = 1.0;
         for(int e = 0; e < g_eventCount; e++)
         {
            if(g_events[e].importance < 3) continue; // only high-impact
            int secsToEvent = (int)MathAbs(g_events[e].eventTime - TimeCurrent());
            if(secsToEvent < 7200) // within 2 hours
            {
               newsPenalty = 0.75; // reduce confidence by 25%
               break;
            }
         }

         // --- Anti-Martingale: dynamic lot sizing based on recent performance ---
         double perfMultiplier = 1.0;
         // After 2+ consecutive wins, increase size slightly
         if(g_symbols[i].totalWins > g_symbols[i].totalLosses + 2 && g_symbols[i].consecutiveLosses == 0)
         {
            int winStreak = g_symbols[i].totalWins - g_symbols[i].totalLosses;
            if(winStreak > 4) winStreak = 4;
            perfMultiplier = 1.0 + winStreak * 0.1; // up to 1.4x
         }
         // After consecutive losses, decrease size
         if(g_symbols[i].consecutiveLosses >= 2)
         {
            perfMultiplier = 1.0 / (1.0 + g_symbols[i].consecutiveLosses * 0.15); // down to 0.6x
         }

         // Apply news penalty to confidence check
         double effectiveConf = g_symbols[i].lastConfidence * newsPenalty;
         if(effectiveConf <= minConf) continue;

         // --- Correlation check: skip if we have highly correlated positions ---
         bool skipDueToCorrelation = false;
         string symbol = g_symbols[i].symbol;
         for(int p = 0; p < PositionsTotal(); p++)
         {
            ulong ticket = PositionGetTicket(p);
            if(!PositionSelectByTicket(ticket)) continue;
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            if(posSymbol == symbol) continue;
            // Check if it is a correlated pair (both are USD-based or both EUR-based)
            bool sameBase = (StringFind(symbol, StringSubstr(posSymbol, 0, 3)) == 0);
            bool sameQuote = (StringFind(symbol, StringSubstr(posSymbol, 3)) > 0 && StringLen(posSymbol) >= 6);
            if(sameBase || sameQuote)
            {
               // Found correlated position - only skip if we would trade the SAME direction
               ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               if((g_symbols[i].lastAction == "BUY" && posType == POSITION_TYPE_BUY) ||
                  (g_symbols[i].lastAction == "SELL" && posType == POSITION_TYPE_SELL))
               {
                  skipDueToCorrelation = true;
                  break;
               }
            }
         }

         if(skipDueToCorrelation)
         {
            g_symbols[i].lastInsight = "SKIP: correlated position exists";
            continue;
         }

         double atr = GetAtrValueEx(g_symbols[i].symbol, g_symbols[i].activeTf);
         if(atr <= 0.0) continue;

         // Dynamic SL/TP based on market regime
         MARKET_REGIME regime = DetectMarketRegime(g_symbols[i].symbol);
         double slMultiplier, tpMultiplier;
         switch(regime)
         {
            case REGIME_TRENDING:
               slMultiplier = 1.2; tpMultiplier = 3.0;  // wider TP, tighter SL
               break;
            case REGIME_RANGING:
               slMultiplier = 1.0; tpMultiplier = 2.0;  // tight stops, moderate targets
               break;
            case REGIME_VOLATILE:
               slMultiplier = 2.0; tpMultiplier = 3.5;  // wide stops in volatility
               break;
            case REGIME_CALM:
               slMultiplier = 0.8; tpMultiplier = 2.5;  // tight stops in calm
               break;
            default:
               slMultiplier = 1.5; tpMultiplier = 2.5;
         }

         double sl = atr * slMultiplier;
         double tp = atr * tpMultiplier;

         // Scale lot size by confidence in high-risk mode + anti-martingale
         double lot = g_config.highRiskMode ? g_config.lotSize * (1.0 + (g_symbols[i].lastConfidence - g_config.riskConfidence) * 2.0) : g_config.lotSize;
         lot *= perfMultiplier; // apply anti-martingale scaling
         if(lot > 0.5) lot = 0.5;
         lot = NormalizeDouble(lot, 2);
         if(lot < 0.01) lot = 0.01;

         trade.SetExpertMagicNumber(g_symbols[i].magicNumber);

         if(g_symbols[i].lastAction == "BUY")
         {
            double ask = SymbolInfoDouble(g_symbols[i].symbol, SYMBOL_ASK);
            trade.Buy(lot, g_symbols[i].symbol, 0, NormalizeDouble(ask - sl, g_symbols[i].digit), NormalizeDouble(ask + tp, g_symbols[i].digit), "KILO AGENT BUY");
            g_symbols[i].lastTradeTime = TimeCurrent();
         }
         else if(g_symbols[i].lastAction == "SELL")
         {
            double bid = SymbolInfoDouble(g_symbols[i].symbol, SYMBOL_BID);
            trade.Sell(lot, g_symbols[i].symbol, 0, NormalizeDouble(bid + sl, g_symbols[i].digit), NormalizeDouble(bid - tp, g_symbols[i].digit), "KILO AGENT SELL");
            g_symbols[i].lastTradeTime = TimeCurrent();
         }
      }
   }

   ManagePositions();
}

//+------------------------------------------------------------------+
//| Chart event handler - interactive dashboard clicks               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK) return;

   // Reset button state immediately
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

   //--- Config Settings ---
   if(sparam == "AK47_CFG_HIGHRISK")
   {
      g_config.highRiskMode = !g_config.highRiskMode;
      UpdateDashboard(); ChartRedraw(0); return;
   }
   if(sparam == "AK47_CFG_LOTSIZE")
   {
      double lots[6] = {0.01, 0.02, 0.05, 0.10, 0.20, 0.50};
      CycleDouble(g_config.lotSize, lots);
      UpdateDashboard(); ChartRedraw(0); return;
   }
   if(sparam == "AK47_CFG_MAXORDERS")
   {
      int orders[5] = {1, 2, 4, 6, 8};
      CycleInt(g_config.maxOrdersTotal, orders);
      UpdateDashboard(); ChartRedraw(0); return;
   }
   if(sparam == "AK47_CFG_CONFIDENCE")
   {
      double confs[4] = {0.30, 0.45, 0.60, 0.75};
      CycleDouble(g_config.riskConfidence, confs);
      UpdateDashboard(); ChartRedraw(0); return;
   }
   if(sparam == "AK47_CFG_SPREAD")
   {
      int spreads[4] = {20, 35, 50, 100};
      CycleInt(g_config.maxSpread, spreads);
      UpdateDashboard(); ChartRedraw(0); return;
   }
   if(sparam == "AK47_CFG_DD")
   {
      double dds[4] = {2.0, 4.0, 6.0, 10.0};
      CycleDouble(g_config.maxDailyDrawdown, dds);
      UpdateDashboard(); ChartRedraw(0); return;
   }
   if(sparam == "AK47_CFG_TARGET")
   {
      double targets[4] = {1.0, 2.5, 5.0, 10.0};
      CycleDouble(g_config.dailyProfitTarget, targets);
      UpdateDashboard(); ChartRedraw(0); return;
   }
   if(sparam == "AK47_CFG_247")
   {
      g_config.allow247 = !g_config.allow247;
      UpdateDashboard(); ChartRedraw(0); return;
   }
   if(sparam == "AK47_CFG_STRATEGY")
   {
      g_stratCurrent = (g_stratCurrent + 1) % STRAT_COUNT;
      ApplyStrategyProfile();
      UpdateDashboard(); ChartRedraw(0); return;
   }

   //--- Event Actions (click to cycle action for an event) ---
   for(int i=0; i<g_eventCount; i++)
   {
      string btnName = "AK47_EVT_" + IntegerToString(i);
      if(sparam == btnName)
      {
         // Cycle: WAIT -> BUY -> SELL -> BUY_STOP -> SELL_STOP -> WAIT
         int next[] = {1, 2, 4, 3, 0};  // from EVT_WAIT skip 5,6 (limit)
         int currentAction = g_events[i].action;

         // Find current action index in the cycle
         for(int c=0; c<ArraySize(next); c++)
         {
            if(currentAction == next[c])
            {
               g_events[i].action = next[(c + 1) % ArraySize(next)];
               break;
            }
         }
         if(g_events[i].action == 0)
            g_events[i].action = next[0]; // default to first non-WAIT

         g_events[i].isActive = (g_events[i].action != EVT_WAIT);

         // Place or manage pending order
         if(g_events[i].isActive)
            PlaceEventOrder(i);
         else
            CancelEventOrder(i);

         UpdateDashboard(); ChartRedraw(0); return;
      }
   }

   //--- Event Cancel click ---
   for(int i=0; i<g_eventCount; i++)
   {
      string cancelName = "AK47_EVT_CANCEL_" + IntegerToString(i);
      if(sparam == cancelName)
      {
         CancelEventOrder(i);
         g_events[i].action = EVT_WAIT;
         g_events[i].isActive = false;
         UpdateDashboard(); ChartRedraw(0); return;
      }
   }

   //--- Manual Trade Buttons ---
   if(sparam == "AK47_MANUAL_BUY")
   {
      if(g_symbolCount > 0)
      {
         trade.SetExpertMagicNumber(g_symbols[0].magicNumber);
         double ask = SymbolInfoDouble(g_symbols[0].symbol, SYMBOL_ASK);
         if(trade.Buy(g_config.lotSize, g_symbols[0].symbol, 0, 0, 0, "MANUAL BUY"))
            Print("MANUAL BUY placed on ", g_symbols[0].symbol);
         else
            Print("MANUAL BUY failed, error=", GetLastError());
         UpdateDashboard(); ChartRedraw(0);
      }
      return;
   }
   if(sparam == "AK47_MANUAL_SELL")
   {
      if(g_symbolCount > 0)
      {
         trade.SetExpertMagicNumber(g_symbols[0].magicNumber);
         double bid = SymbolInfoDouble(g_symbols[0].symbol, SYMBOL_BID);
         if(trade.Sell(g_config.lotSize, g_symbols[0].symbol, 0, 0, 0, "MANUAL SELL"))
            Print("MANUAL SELL placed on ", g_symbols[0].symbol);
         else
            Print("MANUAL SELL failed, error=", GetLastError());
         UpdateDashboard(); ChartRedraw(0);
      }
      return;
   }
   if(sparam == "AK47_MANUAL_CLOSEALL")
   {
      int closed = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            int magic = (int)PositionGetInteger(POSITION_MAGIC);
            if(magic >= BaseMagicNumber && magic < BaseMagicNumber + 8)
            {
               if(trade.PositionClose(ticket)) closed++;
            }
         }
      }
      Print("MANUAL CLOSE ALL: ", closed, " positions closed");
      UpdateDashboard(); ChartRedraw(0);
      return;
   }
}

//+------------------------------------------------------------------+
//| Cycle helper: find current value in array, advance to next       |
//+------------------------------------------------------------------+
void CycleInt(int &current, int &values[])
{
   int n = ArraySize(values);
   for(int i = 0; i < n; i++)
   {
      if(current == values[i])
      {
         current = values[(i + 1) % n];
         return;
      }
   }
   current = values[0];
}

void CycleDouble(double &current, double &values[])
{
   int n = ArraySize(values);
   for(int i = 0; i < n; i++)
   {
      if(MathAbs(current - values[i]) < 0.001)
      {
         current = values[(i + 1) % n];
         return;
      }
   }
   current = values[0];
}

//+------------------------------------------------------------------+
//| Dashboard object management                                      |
//+------------------------------------------------------------------+
void CreateDashboardObjects()
{
   DeleteDashboardObjects();

   int y = DASH_Y_START;

   // Title
   CreateLabel("TITLE", y, clrWhite, 10);
   y += DASH_LINE_H;

   // Status line
   CreateLabel("STATUS", y, clrWhite, 9);
   y += DASH_LINE_H;

   // Separator
   CreateLabel("SEP1", y, clrGray, 8);
   y += DASH_LINE_H;

   // Symbol header
   CreateLabel("SYM_HEADER", y, clrDimGray, 8);
   y += DASH_LINE_H;

   // 4 symbol lines
   for(int i=0; i<4; i++)
   {
      CreateLabel("SYM_" + IntegerToString(i), y, clrWhite, 9);
      y += DASH_LINE_H;
   }

   // Separator
   CreateLabel("SEP2", y, clrGray, 8);
   y += DASH_LINE_H + 2;

   // Settings header
   CreateLabel("CFG_HEADER", y, clrAqua, 9);
   y += DASH_LINE_H;

   // Config buttons
   CreateButton("CFG_HIGHRISK",  y, clrDarkSlateGray); y += DASH_LINE_H;
   CreateButton("CFG_LOTSIZE",   y, clrDarkSlateGray); y += DASH_LINE_H;
   CreateButton("CFG_MAXORDERS", y, clrDarkSlateGray); y += DASH_LINE_H;
   CreateButton("CFG_CONFIDENCE", y, clrDarkSlateGray); y += DASH_LINE_H;
   CreateButton("CFG_SPREAD",    y, clrDarkSlateGray); y += DASH_LINE_H;
   CreateButton("CFG_DD",        y, clrDarkSlateGray); y += DASH_LINE_H;
   CreateButton("CFG_TARGET",    y, clrDarkSlateGray); y += DASH_LINE_H;
   CreateButton("CFG_247",       y, clrDarkSlateGray); y += DASH_LINE_H;
   CreateButton("CFG_STRATEGY",  y, clrDarkSlateGray); y += DASH_LINE_H + 2;

   // Separator
   CreateLabel("SEP3", y, clrGray, 8);
   y += DASH_LINE_H;

   // Positions line
   CreateLabel("POSITIONS", y, clrWhite, 9);
   y += DASH_LINE_H + 2;

   // Events header
   CreateLabel("EVT_HEADER", y, clrAqua, 9);
   y += DASH_LINE_H;

   // Event rows (up to MAX_EVENTS)
   for(int i=0; i<MAX_EVENTS; i++)
   {
      CreateButton("EVT_" + IntegerToString(i), y, clrDarkSlateGray);
      CreateButton("EVT_CANCEL_" + IntegerToString(i), y, clrDarkRed);
      y += DASH_LINE_H;
   }

   // Separator
   CreateLabel("SEP4", y, clrGray, 8);
   y += DASH_LINE_H;

   // Manual Trade header
   CreateLabel("MANUAL_HEADER", y, clrAqua, 9);
   y += DASH_LINE_H;

   // Manual BUY button
   CreateButton("MANUAL_BUY", y, clrDarkGreen); y += DASH_LINE_H;
   // Manual SELL button
   CreateButton("MANUAL_SELL", y, clrDarkRed); y += DASH_LINE_H;
   // Close All button
   CreateButton("MANUAL_CLOSEALL", y, clrMaroon); y += DASH_LINE_H;
}

void DeleteDashboardObjects()
{
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, DASH_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

void CreateLabel(string id, int y, color clr, int fontSize)
{
   string name = DASH_PREFIX + id;
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, "");
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, DASH_X);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
}

void CreateButton(string id, int y, color bg)
{
   string name = DASH_PREFIX + id;
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetString(0, name, OBJPROP_TEXT, "");
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, DASH_X);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, BTN_W);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, BTN_H);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
}

void SetText(string id, string text)
{
   ObjectSetString(0, DASH_PREFIX + id, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Dashboard Update                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   // Title
   SetText("TITLE", "AK47 AI BROKER | 100% AUTO-TRADE");

   // Status
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = currentEquity - dailyStartBalance;
   double profitPercent = (dailyStartBalance > 0.0) ? (dailyProfit / dailyStartBalance) * 100.0 : 0.0;
   string statusStr = (isGlobalDisabled ? "GLOBAL PAUSED" : "ACTIVE");
   string modeStr = "";
   if(g_config.highRiskMode) modeStr += " HIGH RISK";
   if(g_config.allow247)     modeStr += " 24/7";
   // Aggregate win/loss stats
   int totalWins = 0, totalLosses = 0;
   for(int si=0; si<g_symbolCount; si++) { totalWins += g_symbols[si].totalWins; totalLosses += g_symbols[si].totalLosses; }
   string wlStr = "";
   if(totalWins + totalLosses > 0)
   {
      double wr = (double)totalWins / (totalWins + totalLosses) * 100.0;
      wlStr = StringFormat(" | W:%d L:%d (%.0f%%)", totalWins, totalLosses, wr);
   }
   SetText("STATUS", StringFormat("AI Broker: %s%s | P/L: %+7.2f %s (%+5.2f%%)%s",
      statusStr, modeStr, dailyProfit, AccountInfoString(ACCOUNT_CURRENCY), profitPercent, wlStr));

   // Separators
   SetText("SEP1", "------------------------------------------------------------");
   SetText("SEP2", "------------------------------------------------------------");
   SetText("SEP3", "------------------------------------------------------------");

   // Symbol header
   SetText("SYM_HEADER", "Symbol  Action  Conf  W/L  Cons  TF  Regime  Insight");

   // Symbol lines
   for(int i=0; i<4; i++)
   {
      if(i < g_symbolCount)
      {
         string regimeStr = "---";
         MARKET_REGIME mr = DetectMarketRegime(g_symbols[i].symbol);
         switch(mr)
         {
            case REGIME_TRENDING: regimeStr = "TRND"; break;
            case REGIME_RANGING:  regimeStr = "RANG"; break;
            case REGIME_VOLATILE: regimeStr = "VOL"; break;
            case REGIME_CALM:     regimeStr = "CLM"; break;
         }
         string tfStr = TimeframeToString(g_symbols[i].activeTf);
         SetText("SYM_" + IntegerToString(i), StringFormat("%-7s %-4s %3.0f%% %d/%d  %d  %-4s %-4s  %s",
            g_symbols[i].symbol, g_symbols[i].lastAction,
            g_symbols[i].lastConfidence * 100,
            g_symbols[i].totalWins, g_symbols[i].totalLosses,
            g_symbols[i].consecutiveLosses, tfStr, regimeStr,
            g_symbols[i].lastInsight));
      }
      else
      {
         SetText("SYM_" + IntegerToString(i), "");
      }
   }

   // Settings header
   SetText("CFG_HEADER", "== SETTINGS (click values to change) ==");

   // Config buttons
   SetText("CFG_HIGHRISK",   StringFormat("High Risk Mode:      %s",       g_config.highRiskMode ? "ON" : "OFF"));
   SetText("CFG_LOTSIZE",    StringFormat("Lot Size:             %.2f",     g_config.lotSize));
   SetText("CFG_MAXORDERS",  StringFormat("Max Orders:           %d",       g_config.maxOrdersTotal));
   SetText("CFG_CONFIDENCE", StringFormat("Risk Confidence:      %.2f",     g_config.riskConfidence));
   SetText("CFG_SPREAD",     StringFormat("Max Spread:           %d",       g_config.maxSpread));
   SetText("CFG_DD",         StringFormat("Max Daily DD:         %.1f%%",   g_config.maxDailyDrawdown));
   SetText("CFG_TARGET",     StringFormat("Daily Profit Target:  %.1f%%",   g_config.dailyProfitTarget));
   SetText("CFG_247",        StringFormat("24/7 Mode:            %s",       g_config.allow247 ? "ON" : "OFF"));
   SetText("CFG_STRATEGY",   StringFormat("Strategy:              %s",       g_stratName[g_stratCurrent]));

   // Positions
   int maxOrders = g_config.highRiskMode ? 8 : g_config.maxOrdersTotal;
   SetText("POSITIONS", StringFormat("Open Positions: %d / %d  |  API: %s",
      PositionsTotalMagic(), maxOrders,
      (Kilo_ApiKey == "" || Kilo_ApiKey == "YOUR_API_KEY_HERE") ? "FREE MODE" : "KILO API"));

   // Events header
   SetText("EVT_HEADER", "== UPCOMING EVENTS (click to set strategy) ==");

   // Event rows
   for(int i=0; i<MAX_EVENTS; i++)
   {
      if(i < g_eventCount)
      {
         string timeStr = TimeToString(g_events[i].eventTime, TIME_DATE|TIME_MINUTES);
         string impStr = (g_events[i].importance >= 3) ? "HIGH" : ((g_events[i].importance == 2) ? "MED" : "LOW");
         string actStr = g_evtActionName[g_events[i].action];

         SetText("EVT_" + IntegerToString(i), StringFormat("%s %-20s %s  [%s]  %s",
            timeStr, g_events[i].eventName, impStr, actStr,
            (g_events[i].isActive ? "(active)" : "") ));
         SetText("EVT_CANCEL_" + IntegerToString(i),
            g_events[i].isActive ? "X" : "");
      }
      else
      {
         SetText("EVT_" + IntegerToString(i), "");
         SetText("EVT_CANCEL_" + IntegerToString(i), "");
      }
   }

   // --- Manual Trade section ---
   SetText("SEP4", "------------------------------------------------------------");
   SetText("MANUAL_HEADER", "== MANUAL TRADE (click to execute) ==");
   string firstSym = (g_symbolCount > 0) ? g_symbols[0].symbol : "---";
   SetText("MANUAL_BUY", StringFormat("BUY %s (%.2f lots)", firstSym, g_config.lotSize));
   SetText("MANUAL_SELL", StringFormat("SELL %s (%.2f lots)", firstSym, g_config.lotSize));
   SetText("MANUAL_CLOSEALL", "CLOSE ALL POSITIONS");
}

//+------------------------------------------------------------------+
//| Strategy Profile Helpers                                         |
//+------------------------------------------------------------------+
string LoadCustomPromptFile()
{
   string filename = "AK47_CustomPrompt.txt";
   string content = "";

   int handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(handle != INVALID_HANDLE)
   {
      content = FileReadString(handle);
      FileClose(handle);
      Print("Custom prompt loaded: ", filename, " (common)");
      return content;
   }

   handle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle != INVALID_HANDLE)
   {
      content = FileReadString(handle);
      FileClose(handle);
      Print("Custom prompt loaded: ", filename, " (local)");
      return content;
   }

   Print("No custom prompt file (", filename, ") found. Using Auto default.");
   return g_stratPrompt[STRAT_AUTO];
}

void ApplyStrategyProfile()
{
   string prompt = g_stratPrompt[g_stratCurrent];

   if(g_stratCurrent == STRAT_CUSTOM)
   {
      string custom = LoadCustomPromptFile();
      if(custom != "") prompt = custom;
   }

   if(newsAi != NULL)
      newsAi.SetSystemPrompt(prompt);

   Print("Strategy profile: ", g_stratName[g_stratCurrent]);
}

//+------------------------------------------------------------------+
//| Calendar Scanner + Event Orders                                  |
//+------------------------------------------------------------------+
string SymbolToCurrency(string symbol)
{
   if(symbol == "XAUUSD" || symbol == "XAGUSD") return "USD";
   if(StringFind(symbol, "EUR") == 0) return "EUR";
   if(StringFind(symbol, "GBP") == 0) return "GBP";
   if(StringFind(symbol, "JPY") == 3) return "JPY";
   if(StringFind(symbol, "USD") == 3 && StringFind(symbol, "JPY") == -1) return "USD";
   if(StringFind(symbol, "AUD") == 0) return "AUD";
   if(StringFind(symbol, "NZD") == 0) return "NZD";
   if(StringFind(symbol, "CAD") == 3) return "CAD";
   if(StringFind(symbol, "CHF") == 3) return "CHF";
   if(StringFind(symbol, "CNH") == 3 || StringFind(symbol, "CNY") == 3) return "CNY";
   return "";
}

void ScanEconomicCalendar()
{
   g_eventCount = 0;

   // Collect unique currencies from our symbols
   string currencies[8];
   int currCount = 0;
   for(int i=0; i<g_symbolCount; i++)
   {
      string c = SymbolToCurrency(g_symbols[i].symbol);
      if(c == "") continue;
      bool found = false;
      for(int j=0; j<currCount; j++)
         if(currencies[j] == c) { found = true; break; }
      if(!found && currCount < 8)
         currencies[currCount++] = c;
   }
   // Always add USD since it affects all pairs
   bool hasUSD = false;
   for(int j=0; j<currCount; j++)
      if(currencies[j] == "USD") { hasUSD = true; break; }
   if(!hasUSD && currCount < 8)
      currencies[currCount++] = "USD";

   datetime from = TimeCurrent();
   datetime to = from + 7 * 86400; // 7 days ahead

   // Scan each currency
   for(int c=0; c<currCount && g_eventCount < MAX_EVENTS; c++)
   {
      MqlCalendarValue values[50];
      int count = CalendarValueHistory(values, from, to, currencies[c]);
      if(count <= 0) continue;

      int limit = MathMin(count, 50);
      for(int v=0; v<limit && g_eventCount < MAX_EVENTS; v++)
      {
         // Filter: only medium and high importance
         if(values[v].impact_type < 2) continue;

         MqlCalendarEvent ev;
         if(!CalendarEventById(values[v].event_id, ev)) continue;
         if(ev.importance < 2) continue;

         int idx = g_eventCount;
         g_events[idx].eventTime = values[v].time;
         g_events[idx].eventName = ev.name;
         g_events[idx].importance = ev.importance;
         g_events[idx].currency = currencies[c];
         g_events[idx].action = EVT_WAIT;
         g_events[idx].isActive = false;
         g_events[idx].pendingTicket = 0;
         g_events[idx].eventId = values[v].event_id;
         g_eventCount++;

         Print("Event: ", ev.name, " (", currencies[c], ") imp=", ev.importance,
            " at ", TimeToString(values[v].time));
      }
   }

   // Sort by time (bubble)
   for(int i=0; i<g_eventCount-1; i++)
   {
      for(int j=i+1; j<g_eventCount; j++)
      {
         if(g_events[j].eventTime < g_events[i].eventTime)
         {
            CalendarEvent tmp = g_events[i];
            g_events[i] = g_events[j];
            g_events[j] = tmp;
         }
      }
   }

   g_lastCalendarScan = TimeCurrent();
   Print("Calendar scanned: ", g_eventCount, " events for next 7 days");
}

void PlaceEventOrder(int idx)
{
   if(idx < 0 || idx >= g_eventCount) return;

   // Cancel existing first
   if(g_events[idx].pendingTicket != 0)
   {
      trade.OrderDelete(g_events[idx].pendingTicket);
      g_events[idx].pendingTicket = 0;
   }

   // Only place if event is within 48 hours
   int secondsToEvent = (int)(g_events[idx].eventTime - TimeCurrent());
   if(secondsToEvent < 0 || secondsToEvent > 172800) // -48h to +48h
   {
      Print("Event out of range for pending order: ", g_events[idx].eventName);
      return;
   }

   int action = g_events[idx].action;
   if(action == EVT_WAIT) return;

   // Determine symbol for this event's currency
   string tradeSymbol = "";
   for(int i=0; i<g_symbolCount; i++)
   {
      if(SymbolToCurrency(g_symbols[i].symbol) == g_events[idx].currency)
      {
         tradeSymbol = g_symbols[i].symbol;
         break;
      }
   }
   // Fallback: first symbol with USD
   if(tradeSymbol == "")
      tradeSymbol = g_symbols[0].symbol;

   double bid = SymbolInfoDouble(tradeSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(tradeSymbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(tradeSymbol, SYMBOL_POINT);
   int digit = (int)SymbolInfoInteger(tradeSymbol, SYMBOL_DIGITS);
   double atr = GetAtrValue(tradeSymbol);
   if(atr <= 0.0) atr = point * 200;

   double entryPrice = 0, slPrice = 0, tpPrice = 0;
   int orderType = -1;
   double atrMultiplier = 2.0; // SL/TP based on ATR

   switch(action)
   {
      case EVT_BUY:
         // Market order: execute now
         trade.SetExpertMagicNumber(BaseMagicNumber + 9); // reserved for news
         trade.Buy(g_config.lotSize, tradeSymbol, 0,
            NormalizeDouble(ask - atr * atrMultiplier, digit),
            NormalizeDouble(ask + atr * atrMultiplier * 2, digit),
            "NEWS " + g_events[idx].eventName);
         g_events[idx].pendingTicket = 0; // market order no ticket
         Print("News BUY placed for ", g_events[idx].eventName);
         return;

      case EVT_SELL:
         trade.SetExpertMagicNumber(BaseMagicNumber + 9);
         trade.Sell(g_config.lotSize, tradeSymbol, 0,
            NormalizeDouble(bid + atr * atrMultiplier, digit),
            NormalizeDouble(bid - atr * atrMultiplier * 2, digit),
            "NEWS " + g_events[idx].eventName);
         g_events[idx].pendingTicket = 0;
         Print("News SELL placed for ", g_events[idx].eventName);
         return;

      case EVT_BUY_STOP:
         entryPrice = ask + atr * 0.5;
         slPrice = entryPrice - atr * atrMultiplier;
         tpPrice = entryPrice + atr * atrMultiplier * 2;
         orderType = ORDER_TYPE_BUY_STOP;
         break;

      case EVT_SELL_STOP:
         entryPrice = bid - atr * 0.5;
         slPrice = entryPrice + atr * atrMultiplier;
         tpPrice = entryPrice - atr * atrMultiplier * 2;
         orderType = ORDER_TYPE_SELL_STOP;
         break;
   }

   if(orderType < 0) return;

   trade.SetExpertMagicNumber(BaseMagicNumber + 9);
   ulong ticket = trade.OrderOpen(tradeSymbol, (ENUM_ORDER_TYPE)orderType, g_config.lotSize,
      0, NormalizeDouble(entryPrice, digit),
      NormalizeDouble(slPrice, digit),
      NormalizeDouble(tpPrice, digit),
      0, // expiration (0 = no expiry)
      "NEWS " + g_events[idx].eventName);

   if(ticket > 0)
   {
      g_events[idx].pendingTicket = ticket;
      Print("Pending order placed for ", g_events[idx].eventName, " ticket=", ticket);
   }
   else
   {
      Print("Failed to place pending order for ", g_events[idx].eventName,
         " error=", GetLastError());
   }
}

void CancelEventOrder(int idx)
{
   if(idx < 0 || idx >= g_eventCount) return;

   if(g_events[idx].pendingTicket != 0)
   {
      trade.OrderDelete(g_events[idx].pendingTicket);
      Print("Cancelled pending order for ", g_events[idx].eventName, " ticket=", g_events[idx].pendingTicket);
      g_events[idx].pendingTicket = 0;
   }
}

void CancelAllEventOrders()
{
   for(int i=0; i<g_eventCount; i++)
   {
      if(g_events[i].pendingTicket != 0)
      {
         trade.OrderDelete(g_events[i].pendingTicket);
         g_events[i].pendingTicket = 0;
      }
   }
}

void CheckEventOrders()
{
   for(int i=0; i<g_eventCount; i++)
   {
      if(!g_events[i].isActive || g_events[i].pendingTicket == 0) continue;

      // Check if event has passed
      if(TimeCurrent() > g_events[i].eventTime + 3600) // 1h after event
      {
         CancelEventOrder(i);
         g_events[i].action = EVT_WAIT;
         g_events[i].isActive = false;
         continue;
      }

      // Check if order still exists
      if(!OrderSelect(g_events[i].pendingTicket))
      {
         // Order was filled or cancelled externally
         g_events[i].pendingTicket = 0;
         if(g_events[i].isActive)
         {
            // If filled, mark as inactive
            g_events[i].isActive = false;
            Print("Event order filled/cancelled: ", g_events[i].eventName);
         }
      }
   }
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

//+------------------------------------------------------------------+
//| Track closed positions for consecutive loss monitoring           |
//+------------------------------------------------------------------+
void TrackClosedPositions()
{
   static datetime lastTrackTime = 0;
   if(TimeCurrent() < lastTrackTime + 5) return; // check every 5s
   lastTrackTime = TimeCurrent();

   HistorySelect(0, TimeCurrent());

   int total = HistoryDealsTotal();
   if(total <= 0) return;

   for(int i = total - 1; i >= MathMax(total - 10, 0); i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket <= 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_TYPE) != DEAL_TYPE_BUY &&
         HistoryDealGetInteger(dealTicket, DEAL_TYPE) != DEAL_TYPE_SELL) continue;

      // Only track closed deals (entry + exit pair would show as balance change)
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT) continue; // Only track exits

      int dealMagic = (int)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(dealMagic < BaseMagicNumber || dealMagic >= BaseMagicNumber + 8) continue;

      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      if(MathAbs(profit) < 0.001) continue; // ignore zero-profit

      // Find which symbol this magic belongs to
      for(int s = 0; s < g_symbolCount; s++)
      {
         if(g_symbols[s].magicNumber != dealMagic) continue;

         // Check if we already processed this deal (by ticket)
         static ulong lastProcessedDeal[8] = {0,0,0,0,0,0,0,0};
         if(lastProcessedDeal[s] == dealTicket) break;
         lastProcessedDeal[s] = dealTicket;

         if(profit > 0)
         {
            g_symbols[s].totalWins++;
            g_symbols[s].consecutiveLosses = 0;
         }
         else
         {
            g_symbols[s].totalLosses++;
            g_symbols[s].consecutiveLosses++;
            g_symbols[s].lastLossTime = TimeCurrent();
         }
         g_symbols[s].lastTradePnl = profit;
         Print("Trade result [", g_symbols[s].symbol, "]: PnL=", profit,
               " Wins=", g_symbols[s].totalWins, " Losses=", g_symbols[s].totalLosses,
               " Consec=", g_symbols[s].consecutiveLosses);
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Manage open positions (trailing stop, breakeven, partial close)  |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(magic < BaseMagicNumber || magic >= BaseMagicNumber + 8) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      double atr = GetAtrValue(sym);
      if(atr <= 0.0) atr = point * 100;
      int digit = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double currentPrice = (posType == POSITION_TYPE_BUY)
         ? SymbolInfoDouble(sym, SYMBOL_BID)
         : SymbolInfoDouble(sym, SYMBOL_ASK);
      double priceDiff = (posType == POSITION_TYPE_BUY)
         ? currentPrice - openPrice
         : openPrice - currentPrice;

      // --- Breakeven Management: Move SL to breakeven at 1x ATR profit ---
      if(currentSL <= 0.0 || (posType == POSITION_TYPE_BUY && currentSL < openPrice) ||
         (posType == POSITION_TYPE_SELL && currentSL > openPrice))
      {
         if(priceDiff > atr * 0.8)
         {
            double beSL = (posType == POSITION_TYPE_BUY)
               ? NormalizeDouble(openPrice + 5 * point, digit)
               : NormalizeDouble(openPrice - 5 * point, digit);
            if(trade.PositionModify(ticket, beSL, currentTP))
               Print("Breakeven set for ticket ", ticket);
         }
      }

      // --- Partial Profit Taking: close 30% at 1:1 R:R ---
      if(priceDiff > atr * 1.0 && currentTP > 0.0)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         // Only do partial close once (if volume is still near original lot size)
         if(volume >= 0.02)
         {
            double closeVolume = NormalizeDouble(volume * 0.3, 2);
            if(closeVolume >= 0.01)
            {
               if(trade.PositionClosePartial(ticket, closeVolume))
                  Print("Partial close at 1:1 for ticket ", ticket, " vol=", closeVolume);
            }
         }
      }

      // --- Trailing Stop (existing logic) ---
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(sym, SYMBOL_BID);
         if(bid - openPrice > g_config.trailingStart * point)
         {
            double newSL = NormalizeDouble(bid - g_config.trailingStop * point, digit);
            if(newSL > currentSL + 10 * point)
               trade.PositionModify(ticket, newSL, currentTP);
         }
      }
      else
      {
         double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
         if(openPrice - ask > g_config.trailingStart * point)
         {
            double newSL = NormalizeDouble(ask + g_config.trailingStop * point, digit);
            if(currentSL == 0 || newSL < currentSL - 10 * point)
               trade.PositionModify(ticket, newSL, currentTP);
         }
      }
   }
}
//+------------------------------------------------------------------+
