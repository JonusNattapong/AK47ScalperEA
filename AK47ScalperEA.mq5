//+------------------------------------------------------------------+
//|                                                  AK47ScalperEA.mq5 |
//|                        Copyright 2026, AK47 Scalper EA Developer |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property link      ""
#property version   "4.00"
#property strict
#property description "AK47 EVO V4.0 - Autonomous Quantitative Trading System"

#include <Trade\Trade.mqh>
#include "AK47_AI.mqh"
#include "AK47_News.mqh"
#include "AK47_Quantum.mqh"

// EA Settings
// --- V4.0 Core Settings ---
input double LotSize           = 0.01;
input double AtrSlMultiplier   = 1.5;    // ATR x Multiplier = Dynamic SL
input double AtrTpMultiplier   = 2.5;    // ATR x Multiplier = Dynamic TP
input double AiThresholdBuy    = 0.68;
input double AiThresholdSell   = 0.32;
input int    MagicNumber       = 4747;
input int    MaxOrders         = 1;
input double MaxDailyDrawdown  = 5.0;    // % Max drawdown per day
input double DailyProfitTarget = 2.0;    // % Daily profit target to stop
input bool   UseSelfLearning   = true;
input bool   UseTrendFilter    = true;
input bool   UseEquityCurveFilter = true; // V4: Pause when equity curve unhealthy
// --- AI & Agent ---
input bool   UseNewsAiFilter   = false;  // Enable Kilo AI Market Analysis
input string Kilo_ApiKey       = "YOUR_API_KEY_HERE";
input string Kilo_ApiUrl       = "https://api.kilocode.ai/v1/chat/completions";
// --- Swarm Intelligence ---
input string DxySymbol         = "USDX";   // Dollar Index Symbol
input string Sp500Symbol       = "SPX500"; // S&P 500 Index
input string Us10ySymbol       = "US10Y";  // 10Y Bond Yields
input string BtcSymbol         = "BTCUSD"; // Bitcoin
input bool   UseVolumeFilter   = true;   // Volume Delta & Flow
input bool   UseSmcFilter      = true;   // SMC Order Blocks Entry
input bool   UseSwarmIntelligence = true; // Global Correlation Filtering
input bool   UseAutoTuning     = true;   // AI Self-Correction
// --- Trade Management ---
input int    TrailingStart     = 100;    // Points to start trailing
input int    TrailingStop      = 30;     // Points for trailing distance
input int    MaxSpread         = 35;     // Max allowed spread in points

NeuralNet     *aiM1;  // V5: Micro Brain (M1 - Entry Precision)
NeuralNet     *aiM5;  // V5: Mid Brain (M5 - Structure Validation)
NeuralNet     *aiH1;  // V5: Macro Brain (H1 - Direction Bias)
NewsAiClient  *newsAi;
CTrade        trade;

// V4.0 State Variables
double    dynamicThresholdBuy;
double    dynamicThresholdSell;
double    winRate50 = 0.5;
int       last50Results[];

double    dailyStartBalance;
double    lastFeatures[19]; // +3 Quantum features
double    lastConfidenceM1 = 0;
double    lastConfidenceM5 = 0;
double    lastConfidenceH1 = 0;
double    swarmSentiment = 0.5;
double    quantumSentiment = 0.5;
bool      quantumBreakout = false;
double    currentDynamicSL = 0;
double    currentDynamicTP = 0;
int       winCount = 0, lossCount = 0;
int       recentConsecWins = 0, recentConsecLosses = 0;
datetime  lastTradeTime = 0;
bool      isTradingDisabled = false;

// --- Quantum Trading Settings ---
input bool UseQuantumEngine    = true;    // Enable Quantum Trading Module
input double QuantumThreshold  = 0.65;    // Quantum Confirmation Threshold

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   aiM1 = new NeuralNet();
   aiM5 = new NeuralNet();
   aiH1 = new NeuralNet();
   newsAi = new NewsAiClient(Kilo_ApiKey, Kilo_ApiUrl);
   
   if(UseQuantumEngine)
      InitQuantumEngine();
   
   dynamicThresholdBuy = AiThresholdBuy;
   dynamicThresholdSell = AiThresholdSell;
   ArrayResize(last50Results, 50);
   ArrayInitialize(last50Results, 1);
   
   InitIndicators();
   trade.SetExpertMagicNumber(MagicNumber);
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   Print("AK47 EVO V5.0 QUANTUM EDITION | TRI-BRAIN: ACTIVE | AUTO-CALIBRATION: ON | NO USER SETTINGS REQUIRED");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Comment("");
   delete aiM1; delete aiM5; delete aiH1; delete newsAi;
   
   if(UseQuantumEngine)
      DeinitQuantumEngine();
}

void OnTick()
{
   UpdateDashboard();
   if(isTradingDisabled) return;

   // 1. Drawdown & Profit Protection
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profitPercent = ((currentEquity - dailyStartBalance) / dailyStartBalance) * 100.0;
   
   if(profitPercent <= -MaxDailyDrawdown) { isTradingDisabled = true; return; }
   if(profitPercent >= DailyProfitTarget) { isTradingDisabled = true; return; }

   // 2. V4 Equity Curve Filter
   if(UseEquityCurveFilter && !IsEquityCurveHealthy(currentEquity, dailyStartBalance, recentConsecWins, recentConsecLosses))
      return;

   // 3. V4 Session Engine
   SESSION_TYPE session = GetCurrentSession();
   if(session == SESSION_OFF) return;
   if(IsSidewayMarket() && session == SESSION_ASIAN) return; // Asian = skip if sideways
   if(!IsSpreadOK(MaxSpread)) return;

   // 4. Swarm Feature Extraction (M1 Brain: 16 Inputs + 3 Quantum = 19 Total)
   double features[19];
   GetMarketFeatures(features, DxySymbol, Sp500Symbol, Us10ySymbol, BtcSymbol);
   
   // Add Quantum Features
   if(UseQuantumEngine)
   {
      GetQuantumFeatures(features, 16);
      quantumSentiment = features[16];
      quantumBreakout = (features[17] > 0.5);
   }
   else
   {
      features[16] = 0.5;
      features[17] = 0.5;
      features[18] = 0.0;
      quantumSentiment = 0.5;
      quantumBreakout = false;
   }
   
   // 5. V4 True Multi-TF: H1 Brain gets its OWN features
   double h1Features[19];
   GetH1Features(h1Features, DxySymbol, Sp500Symbol, Us10ySymbol, BtcSymbol);
   
   // Add Quantum to H1 features
   if(UseQuantumEngine)
      GetQuantumFeatures(h1Features, 16);
   else
   {
      h1Features[16] = 0.5;
      h1Features[17] = 0.5;
      h1Features[18] = 0.0;
   }
   
   double globalRisk = (features[13] + features[14]) / 2.0;
   swarmSentiment = 1.0 - globalRisk;

   if(UseNewsAiFilter) newsAi.AnalyzeMarketWithKilo(_Symbol, features);
   CheckClosedTrades();
   ManagePositions();

   if(PositionsTotalMagic() >= MaxOrders) return;
   
   // V4 Session-aware cooldown
   int cooldown = (session == SESSION_ASIAN) ? 600 : 300; // 10min Asian, 5min others
   if(TimeCurrent() < lastTradeTime + cooldown) return;

   // 6. Volume & Regime
   bool volumeOK = (GetVolumeRatio() > 1.2 || GetTickSpeed() > 5);
   bool trendOK = IsMarketTrending(_Symbol);
   bool dxyStrong = IsDxyStrong(DxySymbol);

   // V5.0 TRI-BRAIN CONSENSUS ENGINE
   double predM1 = aiM1.Predict(features);    // M1 Micro Brain
   double predM5 = aiM5.Predict(m5Features);  // M5 Mid Brain
   double predH1 = aiH1.Predict(h1Features);  // H1 Macro Brain
   lastConfidenceM1 = predM1;
   lastConfidenceM5 = predM5;
   lastConfidenceH1 = predH1;

   string aiAction = (UseNewsAiFilter) ? newsAi.GetAction() : "WAIT";
   double aiConf   = (UseNewsAiFilter) ? newsAi.GetConfidence() : 0.0;

   // 8. V4 ATR-Dynamic SL/TP
   currentDynamicSL = GetDynamicSL(AtrSlMultiplier);
   currentDynamicTP = GetDynamicTP(AtrTpMultiplier);

   // 9. V4 Trading Logic (Session-aware + Multi-TF Consensus)
   bool smcBuy  = (!UseSmcFilter || IsInSmcZone(_Symbol, true));
   bool smcSell = (!UseSmcFilter || IsInSmcZone(_Symbol, false));

   // Quantum Confirmation
   bool quantumOK = !UseQuantumEngine || 
      ((predM1 > 0.5 && quantumSentiment > QuantumThreshold) || 
       (predM1 < 0.5 && quantumSentiment < (1.0 - QuantumThreshold)) ||
       quantumBreakout);

   // BUY: M1 Bullish + H1 Bullish + Trend + DXY Weak + Volume + SMC + Quantum
   if((predM1 > dynamicThresholdBuy && predH1 > 0.55 && trendOK && !dxyStrong && volumeOK && smcBuy && quantumOK) || (aiAction == "BUY" && aiConf > 0.8))
   {
      if(!UseTrendFilter || TrendConfirmation(POSITION_TYPE_BUY))
      {
         if(UseNewsAiFilter && aiAction == "SELL") return;
         
         double dynamicLot = CalculateDynamicLot(LotSize, predM1, dynamicThresholdBuy);
         
         // Quantum Lot Amplification
         if(UseQuantumEngine && quantumBreakout)
            dynamicLot *= 1.2;
            
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = NormalizeDouble(ask - currentDynamicSL, _Digits);
         double tp = NormalizeDouble(ask + currentDynamicTP, _Digits);
         
         if(trade.Buy(dynamicLot, _Symbol, 0, sl, tp, "AK47 V4 BUY [" + SessionToString(session) + " Q]")) {
            ArrayCopy(lastFeatures, features); lastTradeTime = TimeCurrent();
         }
      }
   }
   // SELL: M1 Bearish + H1 Bearish + Trend + DXY Strong + Volume + SMC + Quantum
   else if((predM1 < dynamicThresholdSell && predH1 < 0.45 && trendOK && dxyStrong && volumeOK && smcSell && quantumOK) || (aiAction == "SELL" && aiConf > 0.8))
   {
      if(!UseTrendFilter || TrendConfirmation(POSITION_TYPE_SELL))
      {
         if(UseNewsAiFilter && aiAction == "BUY") return;
         
         double dynamicLot = CalculateDynamicLot(LotSize, 1.0 - predM1, 1.0 - dynamicThresholdSell);
         
         // Quantum Lot Amplification
         if(UseQuantumEngine && quantumBreakout)
            dynamicLot *= 1.2;
            
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = NormalizeDouble(bid + currentDynamicSL, _Digits);
         double tp = NormalizeDouble(bid - currentDynamicTP, _Digits);
         
         if(trade.Sell(dynamicLot, _Symbol, 0, sl, tp, "AK47 V4 SELL [" + SessionToString(session) + " Q]")) {
            ArrayCopy(lastFeatures, features); lastTradeTime = TimeCurrent();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Dashboard V4.0 EVO [Autonomous Quant System]                     |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = currentEquity - dailyStartBalance;
   double profitPercent = (dailyProfit / dailyStartBalance) * 100.0;
   Zone ob = GetRecentOrderBlock(_Symbol);
   double hurst = CalculateHurstExponent(_Symbol, 100);
   SESSION_TYPE sess = GetCurrentSession();
   bool eqHealthy = IsEquityCurveHealthy(currentEquity, dailyStartBalance, recentConsecWins, recentConsecLosses);
   
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double volumeRatio = GetVolumeRatio();
   double tickSpeed = GetTickSpeed();
   double atr14 = GetVal(hATR14);
   double atr50 = GetVal(hATR50);
   
   // --- ADVANCED DASHBOARD LAYOUT ---
   string text = "";
   
   // Header
   text += "╔════════════════════════════════════════╗\n";
   text += "║       AK47 EVO V4.0 DASHBOARD         ║\n";
   text += "╠════════════════════════════════════════╣\n";
   
   // System Status
   text += StringFormat("║  Session: %-10s  Spread: %3d pts       ║\n", SessionToString(sess), spread);
   text += StringFormat("║  Status: %s  %s                       ║\n", 
      isTradingDisabled ? "🔴 PAUSED" : "🟢 ACTIVE",
      eqHealthy ? "" : "⚠️  RISK");
   text += "╠────────────────────────────────────────╣\n";
   
   // Market Conditions
   text += StringFormat("║  Hurst: %.2f  %-8s  VolRatio: %.1fx    ║\n", 
      hurst, hurst>0.55?"[TREND]":"[CHOP]", volumeRatio);
   text += StringFormat("║  DXY: %-6s  TickSpeed: %2.0f t/s        ║\n", 
      IsDxyStrong(DxySymbol)?"STRONG":"WEAK", tickSpeed);
   text += StringFormat("║  ATR: %.0f pts | Vol: %s                ║\n", 
      atr14/_Point, volumeRatio>1.2?"🟢 HIGH":"🔴 LOW");
   text += "╠────────────────────────────────────────╣\n";
   
   // AI Brains
   text += StringFormat("║  M1 Brain: %5.1f %%  H1 Brain: %5.1f %%    ║\n", 
      lastConfidenceM1*100, lastConfidenceH1*100);
   text += StringFormat("║  Swarm: %3.0f %%  Quantum: %3.0f %%          ║\n", 
      swarmSentiment*100, quantumSentiment*100);
   text += StringFormat("║  SMC: %s  Q-Break: %s         ║\n",
      IsInSmcZone(_Symbol, ob.isDemand) ? "✅ ACTIVE" : "⏳ WAITING",
      quantumBreakout ? "⚡ YES" : "--- NO");
   text += "╠────────────────────────────────────────╣\n";
   
   // Trade Parameters
   text += StringFormat("║  Dyn SL: %3.0f pts | Dyn TP: %3.0f pts   ║\n", 
      currentDynamicSL/_Point, currentDynamicTP/_Point);
   text += StringFormat("║  Buy Thr: %.2f | Sell Thr: %.2f        ║\n",
      dynamicThresholdBuy, dynamicThresholdSell);
   text += "╠────────────────────────────────────────╣\n";
   
   // Kilo AI Integration
   if(UseNewsAiFilter)
   {
      text += StringFormat("║  KILO AI: %-4s  Conf: %3.0f %%            ║\n",
         newsAi.GetAction(), newsAi.GetConfidence()*100);
      text += StringFormat("║  Insight: %.26s ║\n", newsAi.GetInsight());
      text += "╠────────────────────────────────────────╣\n";
   }
   
   // Performance Metrics
   text += StringFormat("║  Daily P/L: %+8.2f %s  (%+5.2f %%)     ║\n",
      dailyProfit, AccountInfoString(ACCOUNT_CURRENCY), profitPercent);
   text += StringFormat("║  Record: %3d W / %3d L | WinRate: %4.1f %% ║\n",
      winCount, lossCount, winRate50*100);
   
   // Streak Indicator
   string streak = "";
   if(recentConsecWins > 0) streak = StringFormat("🔥 Win Streak: %d", recentConsecWins);
   else if(recentConsecLosses > 0) streak = StringFormat("❌ Loss Streak: %d", recentConsecLosses);
   else streak = "✅ No active streak";
   
   text += StringFormat("║  %-36s ║\n", streak);
   
   // Footer
   text += "╚════════════════════════════════════════╝\n";
   text += "\n";
   text += "  AK47 Scalper EA | Autonomous Quant System\n";
   text += "  Copyright 2026 | Powered by Kilo AI\n";
   
   Comment(text);
}

//+------------------------------------------------------------------+
//| Check for Closed Trades and Train AI                             |
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
   if(!UseSelfLearning) return;
   
   if(HistorySelect(TimeCurrent() - 300, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber && 
            HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            if(closeTime > TimeCurrent() - 60)
            {
               double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
               double target = (profit > 0) ? 1.0 : 0.0;
               
               // Update Win Rate stats (Rolling 50)
               for(int j=49; j>0; j--) last50Results[j] = last50Results[j-1];
               last50Results[0] = (profit > 0) ? 1 : 0;
               
               double wins = 0;
               for(int j=0; j<50; j++) wins += last50Results[j];
               winRate50 = wins / 50.0;
               
               // --- AUTO-TUNER ENGINE ---
               if(UseAutoTuning)
               {
                  if(winRate50 < 0.45) { dynamicThresholdBuy += 0.01; dynamicThresholdSell -= 0.01; } // Be more picky
                  if(winRate50 > 0.60) { dynamicThresholdBuy -= 0.005; dynamicThresholdSell += 0.005; } // Be more aggressive
                  
                  // Clamp thresholds
                  dynamicThresholdBuy = MathMax(0.55, MathMin(0.85, dynamicThresholdBuy));
                  dynamicThresholdSell = MathMax(0.15, MathMin(0.45, dynamicThresholdSell));
               }

               if(profit > 0) { winCount++; recentConsecWins++; recentConsecLosses = 0; }
               else { lossCount++; recentConsecLosses++; recentConsecWins = 0; }
               aiM1.Train(lastFeatures, target);
               aiM1.SaveWeights();
               Print("V4 WinRate: ", DoubleToString(winRate50*100,1), "% | Streak: W", recentConsecWins, " L", recentConsecLosses);
               break; 
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Positions (Trailing Stop)                                 |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double currentSL = PositionGetDouble(POSITION_SL);
         
         // Trailing Stop Logic
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            if(currentPrice - openPrice > TrailingStart * _Point)
            {
               double newSL = NormalizeDouble(currentPrice - TrailingStop * _Point, _Digits);
               if(newSL > currentSL + 10 * _Point) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
         }
         else // SELL
         {
            if(openPrice - currentPrice > TrailingStart * _Point)
            {
               double newSL = NormalizeDouble(currentPrice + TrailingStop * _Point, _Digits);
               if(currentSL == 0 || newSL < currentSL - 10 * _Point) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count total positions with our magic number                      |
//+------------------------------------------------------------------+
int PositionsTotalMagic()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == MagicNumber) count++;
   }
   return count;
}

