//+------------------------------------------------------------------+
//|                                                 AK47_Quantum.mqh |
//|                        Copyright 2026, AK47 Scalper EA Developer |
//+------------------------------------------------------------------+
//| Quantum Feature Engine — v5.1 AUTO ADAPTIVE                      |
//|                                                                   |
//| Auto-selects timeframe per symbol based on market regime.         |
//| Auto-recreates indicator handles when timeframe changes.          |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property link      ""
#property version   "5.10"
#property strict

#define QUANTUM_MAX_SYMBOLS 12

//+------------------------------------------------------------------+
//| String helper                                                    |
//+------------------------------------------------------------------+
string StringTrim(string text)
{
   StringTrimLeft(text);
   StringTrimRight(text);
   return text;
}

//+------------------------------------------------------------------+
//| Session Engine                                                   |
//+------------------------------------------------------------------+
enum SESSION_TYPE { SESSION_ASIAN, SESSION_LONDON, SESSION_NEWYORK, SESSION_OFF };

SESSION_TYPE GetCurrentSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return SESSION_OFF;
   int h = dt.hour;
   if(h >= 0 && h < 7)   return SESSION_ASIAN;
   if(h >= 7 && h < 13)  return SESSION_LONDON;
   if(h >= 13 && h < 21) return SESSION_NEWYORK;
   return SESSION_OFF;
}

//+------------------------------------------------------------------+
//| Market Regime                                                    |
//+------------------------------------------------------------------+
enum MARKET_REGIME
{
   REGIME_TRENDING,
   REGIME_RANGING,
   REGIME_VOLATILE,
   REGIME_CALM
};

//+------------------------------------------------------------------+
//| Auto-select optimal timeframe based on market regime             |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES RegimeToTimeframe(MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_TRENDING: return PERIOD_H1;    // Higher TF for trend following
      case REGIME_RANGING:  return PERIOD_M15;   // Lower TF for scalping ranges
      case REGIME_VOLATILE: return PERIOD_M30;   // Medium TF during volatility
      case REGIME_CALM:     return PERIOD_M5;    // Fast scalping in calm markets
   }
   return PERIOD_M15;
}

string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
   }
   return "M15";
}

//+------------------------------------------------------------------+
//| Per-symbol indicator handle cache (timeframe-aware)              |
//+------------------------------------------------------------------+
struct QuantumHandles
{
   string         symbol;
   bool           ready;
   ENUM_TIMEFRAMES timeframe;
   int    hRSI;
   int    hCCI;
   int    hMACD;
   int    hStoch;
   int    hATR14;
   int    hATR50;
   int    hMA20;
   int    hMA50;
   int    hMA200;
   int    hMA1H;
   int    hMA4H;
   int    hBB;
   int    hADX;
};

QuantumHandles g_qh[QUANTUM_MAX_SYMBOLS];
int            g_qhCount = 0;

//+------------------------------------------------------------------+
//| Engine lifecycle                                                 |
//+------------------------------------------------------------------+
void InitQuantumEngine()
{
   g_qhCount = 0;
   for(int i=0; i<QUANTUM_MAX_SYMBOLS; i++)
   {
      g_qh[i].symbol = "";
      g_qh[i].ready  = false;
   }
   Print("Quantum Engine v5.1 AUTO ADAPTIVE initialized");
}

void ReleaseHandleSet(int idx)
{
   if(idx < 0 || idx >= g_qhCount) return;
   if(g_qh[idx].hRSI   != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hRSI);
   if(g_qh[idx].hCCI   != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hCCI);
   if(g_qh[idx].hMACD  != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hMACD);
   if(g_qh[idx].hStoch != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hStoch);
   if(g_qh[idx].hATR14 != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hATR14);
   if(g_qh[idx].hATR50 != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hATR50);
   if(g_qh[idx].hMA20  != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hMA20);
   if(g_qh[idx].hMA50  != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hMA50);
   if(g_qh[idx].hMA200 != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hMA200);
   if(g_qh[idx].hMA1H  != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hMA1H);
   if(g_qh[idx].hMA4H  != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hMA4H);
   if(g_qh[idx].hBB    != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hBB);
   if(g_qh[idx].hADX   != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hADX);
   g_qh[idx].ready = false;
}

void DeinitQuantumEngine()
{
   for(int i=0; i<g_qhCount; i++) ReleaseHandleSet(i);
   g_qhCount = 0;
}

//+------------------------------------------------------------------+
//| Resolve handle set for a symbol + timeframe.                     |
//| Returns index, or -1 on failure.                                 |
//| If handles exist with wrong timeframe, they are re-created.      |
//+------------------------------------------------------------------+
int GetHandleSetEx(string symbol, ENUM_TIMEFRAMES tf)
{
   // Check existing handles
   for(int i=0; i<g_qhCount; i++)
   {
      if(g_qh[i].symbol == symbol && g_qh[i].ready)
      {
         // Same symbol, check timeframe
         if(g_qh[i].timeframe == tf) return i;
         // Timeframe changed: release and recreate
         if(g_qh[i].timeframe != tf)
         {
            Print("Quantum: timeframe change for ", symbol, " ",
               TimeframeToString(g_qh[i].timeframe), "->", TimeframeToString(tf));
            int idx = i;
            ReleaseHandleSet(idx);
            // Re-init this slot with new timeframe
            QuantumHandles hset;
            hset.symbol    = symbol;
            hset.timeframe = tf;
            hset.hRSI   = iRSI(symbol, tf, 14, PRICE_CLOSE);
            hset.hCCI   = iCCI(symbol, tf, 20, PRICE_CLOSE);
            hset.hMACD  = iMACD(symbol, tf, 12, 26, 9, PRICE_CLOSE);
            hset.hStoch = iStochastic(symbol, tf, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
            hset.hATR14 = iATR(symbol, tf, 14);
            hset.hATR50 = iATR(symbol, tf, 50);
            hset.hMA20  = iMA(symbol, tf, 20, 0, MODE_SMA, PRICE_CLOSE);
            hset.hMA50  = iMA(symbol, tf, 50, 0, MODE_SMA, PRICE_CLOSE);
            hset.hMA200 = iMA(symbol, tf, 200, 0, MODE_SMA, PRICE_CLOSE);
            hset.hMA1H  = iMA(symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
            hset.hMA4H  = iMA(symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
            hset.hBB    = iBands(symbol, tf, 20, 0, 2.0, PRICE_CLOSE);
            hset.hADX   = iADX(symbol, tf, 14);

            if(hset.hRSI == INVALID_HANDLE || hset.hATR14 == INVALID_HANDLE)
            {
               Print("Quantum: failed re-init for ", symbol);
               return -1;
            }
            hset.ready = true;
            g_qh[idx] = hset;
            return idx;
         }
      }
   }

   // Create new
   if(g_qhCount >= QUANTUM_MAX_SYMBOLS) return -1;

   int idx = g_qhCount;
   QuantumHandles hset;
   hset.symbol    = symbol;
   hset.timeframe = tf;
   hset.hRSI   = iRSI(symbol, tf, 14, PRICE_CLOSE);
   hset.hCCI   = iCCI(symbol, tf, 20, PRICE_CLOSE);
   hset.hMACD  = iMACD(symbol, tf, 12, 26, 9, PRICE_CLOSE);
   hset.hStoch = iStochastic(symbol, tf, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   hset.hATR14 = iATR(symbol, tf, 14);
   hset.hATR50 = iATR(symbol, tf, 50);
   hset.hMA20  = iMA(symbol, tf, 20, 0, MODE_SMA, PRICE_CLOSE);
   hset.hMA50  = iMA(symbol, tf, 50, 0, MODE_SMA, PRICE_CLOSE);
   hset.hMA200 = iMA(symbol, tf, 200, 0, MODE_SMA, PRICE_CLOSE);
   hset.hMA1H  = iMA(symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   hset.hMA4H  = iMA(symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
   hset.hBB    = iBands(symbol, tf, 20, 0, 2.0, PRICE_CLOSE);
   hset.hADX   = iADX(symbol, tf, 14);

   if(hset.hRSI == INVALID_HANDLE || hset.hATR14 == INVALID_HANDLE)
   {
      Print("Quantum: failed to create indicators for ", symbol);
      return -1;
   }

   hset.ready = true;
   g_qh[idx]  = hset;
   g_qhCount++;
   return idx;
}

// Legacy overload for backward compat (uses _Period)
int GetHandleSet(string symbol)
{
   return GetHandleSetEx(symbol, _Period);
}

//+------------------------------------------------------------------+
//| Buffer read helper                                               |
//+------------------------------------------------------------------+
double QGetVal(int handle, int buffer=0, int shift=0)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, buffer, shift, 1, buf) > 0) return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Volume ratio                                                     |
//+------------------------------------------------------------------+
double GetVolumeRatio(string symbol, ENUM_TIMEFRAMES tf)
{
   long vol[];
   if(CopyTickVolume(symbol, tf, 0, 20, vol) < 20) return 1.0;

   double avgVol = 0.0;
   for(int i=1; i<20; i++) avgVol += (double)vol[i];
   avgVol /= 19.0;

   return (avgVol > 0.0) ? (double)vol[0] / avgVol : 1.0;
}

double GetVolumeRatio(string symbol) { return GetVolumeRatio(symbol, _Period); }

//+------------------------------------------------------------------+
//| H1 % change                                                      |
//+------------------------------------------------------------------+
double GetSymbolChange(string sym)
{
   if(sym == "" || sym == "NULL" || sym == "NONE") return 0.0;
   if(!SymbolSelect(sym, true)) return 0.0;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(sym, PERIOD_H1, 0, 2, r) < 2) return 0.0;
   return (r[0].close - r[1].close) / (r[1].close + 1e-9);
}

//+------------------------------------------------------------------+
//| Hurst exponent (R/S analysis)                                    |
//+------------------------------------------------------------------+
double CalculateHurstExponent(string symbol, int period)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, _Period, 0, period, rates) < period) return 0.5;

   int    maxPoints = period / 4;
   double logRS[], logN[];
   ArrayResize(logRS, maxPoints);
   ArrayResize(logN, maxPoints);
   int idx = 0;

   for(int n=10; n<period; n+=10)
   {
      double mean = 0.0;
      for(int i=0; i<n; i++) mean += rates[i].close;
      mean /= n;

      double maxDiff = -1e10, minDiff = 1e10, cumSum = 0.0, std = 0.0;
      for(int i=0; i<n; i++)
      {
         cumSum += (rates[i].close - mean);
         maxDiff = MathMax(maxDiff, cumSum);
         minDiff = MathMin(minDiff, cumSum);
         std    += MathPow(rates[i].close - mean, 2);
      }
      std = MathSqrt(std / n);

      if(std > 0.0)
      {
         logRS[idx] = MathLog((maxDiff - minDiff) / std);
         logN[idx]  = MathLog((double)n);
         idx++;
      }
      if(idx >= maxPoints) break;
   }

   if(idx < 2) return 0.5;

   double sumX=0, sumY=0, sumXY=0, sumX2=0;
   for(int i=0; i<idx; i++)
   {
      sumX  += logN[i];
      sumY  += logRS[i];
      sumXY += logN[i] * logRS[i];
      sumX2 += logN[i] * logN[i];
   }

   double denom = (idx * sumX2 - sumX * sumX);
   if(MathAbs(denom) < 1e-12) return 0.5;

   double hurst = (idx * sumXY - sumX * sumY) / denom;
   return MathMax(0.0, MathMin(1.0, hurst));
}

//+------------------------------------------------------------------+
//| Shannon entropy                                                  |
//+------------------------------------------------------------------+
double CalculateReturnEntropy(string symbol, int period)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(symbol, _Period, 0, period + 1, r);
   if(n < 3) return 0.5;

   int up = 0, down = 0;
   for(int i=0; i<n-1; i++)
   {
      double diff = r[i].close - r[i+1].close;
      if(diff > 0)      up++;
      else if(diff < 0) down++;
   }

   int total = up + down;
   if(total == 0) return 0.0;

   double pUp   = (double)up / total;
   double pDown = (double)down / total;

   double entropy = 0.0;
   if(pUp   > 0.0) entropy -= pUp   * (MathLog(pUp)   / MathLog(2.0));
   if(pDown > 0.0) entropy -= pDown * (MathLog(pDown) / MathLog(2.0));

   return MathMax(0.0, MathMin(1.0, entropy));
}

//+------------------------------------------------------------------+
//| Current ATR value (timeframe-aware)                              |
//+------------------------------------------------------------------+
double GetAtrValueEx(string symbol, ENUM_TIMEFRAMES tf)
{
   int h = GetHandleSetEx(symbol, tf);
   if(h < 0) return 0.0;
   return QGetVal(g_qh[h].hATR14);
}

double GetAtrValue(string symbol) { return GetAtrValueEx(symbol, _Period); }

//+------------------------------------------------------------------+
//| Market Regime Detection (timeframe-aware)                        |
//+------------------------------------------------------------------+
MARKET_REGIME DetectMarketRegimeEx(string symbol, ENUM_TIMEFRAMES tf)
{
   int h = GetHandleSetEx(symbol, tf);
   if(h < 0) return REGIME_CALM;

   double adxVal  = QGetVal(g_qh[h].hADX, 0);
   double bbUpper = QGetVal(g_qh[h].hBB, 1);
   double bbLower = QGetVal(g_qh[h].hBB, 2);
   double bbMid   = QGetVal(g_qh[h].hBB, 0);
   double atr14   = QGetVal(g_qh[h].hATR14);
   double atr50   = QGetVal(g_qh[h].hATR50);
   double point   = SymbolInfoDouble(symbol, SYMBOL_POINT);

   double bbWidth = (bbMid > 0.0) ? (bbUpper - bbLower) / bbMid : 0.0;
   double bbWidthNorm = bbWidth / (point * 100.0 + 0.0001);
   double volRatio = (atr50 > 0.0) ? atr14 / atr50 : 1.0;

   if(adxVal > 25.0 && bbWidthNorm > 0.5) return REGIME_TRENDING;
   if(volRatio > 1.5 && bbWidthNorm > 1.0) return REGIME_VOLATILE;
   if(adxVal < 20.0 && bbWidthNorm < 1.0) return REGIME_RANGING;
   return REGIME_CALM;
}

MARKET_REGIME DetectMarketRegime(string symbol)
{
   return DetectMarketRegimeEx(symbol, _Period);
}

//+------------------------------------------------------------------+
//| Session Quality Score                                            |
//+------------------------------------------------------------------+
double GetSessionQuality()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return 0.1;

   int h = dt.hour;
   if(h >= 12 && h < 16)
   {
      if(h >= 13 && h < 14) return 1.0;
      return 0.85;
   }
   if(h >= 7 && h < 12) return 0.75;
   if(h >= 16 && h < 21) return 0.65;
   if(h >= 0 && h < 7) return 0.50;
   return 0.20;
}

//+------------------------------------------------------------------+
//| Momentum                                                         |
//+------------------------------------------------------------------+
double CalculateMomentum(string symbol, int periods)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int n = CopyRates(symbol, _Period, 0, periods + 1, r);
   if(n < periods + 1) return 0.0;

   double mom = (r[0].close - r[periods].close) / (r[periods].close + 1e-9);
   return MathMax(-1.0, MathMin(1.0, mom * 100.0));
}

//+------------------------------------------------------------------+
//| Feature Extraction (timeframe-aware)                             |
//+------------------------------------------------------------------+
void GetMarketFeaturesEx(string symbol, double &features[], string dxy, string sp500, string us10y, string btc, ENUM_TIMEFRAMES tf)
{
   int h = GetHandleSetEx(symbol, tf);
   if(h < 0)
   {
      for(int i=0; i<16; i++) features[i] = 0.5;
      return;
   }
   QuantumHandles hs = g_qh[h];

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 2, rates) < 2)
   {
      for(int i=0; i<16; i++) features[i] = 0.5;
      return;
   }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0) point = _Point;
   double atr14 = QGetVal(hs.hATR14);

   features[0]  = (rates[0].close - rates[0].open) / (point * 10.0);
   features[1]  = (rates[0].high - rates[0].low) / (point * 10.0);
   features[2]  = (rates[0].close - rates[1].close) / (point * 10.0);
   features[3]  = QGetVal(hs.hRSI) / 100.0;
   features[4]  = QGetVal(hs.hCCI) / 200.0 + 0.5;
   features[5]  = QGetVal(hs.hMACD) / (point * 10.0);
   features[6]  = QGetVal(hs.hStoch) / 100.0;
   features[7]  = atr14 / (point * 100.0);

   features[8]  = (rates[0].close - QGetVal(hs.hMA20)) / (atr14 + 0.0001);
   features[9]  = GetVolumeRatio(symbol, tf) / 2.0;
   features[10] = (QGetVal(hs.hMA1H) - QGetVal(hs.hMA4H)) / (atr14 + 0.0001);
   features[11] = CalculateHurstExponent(symbol, 50);

   features[12] = GetSymbolChange(dxy) * 100.0 + 0.5;
   features[13] = GetSymbolChange(sp500) * 100.0 + 0.5;

   MARKET_REGIME regime = DetectMarketRegimeEx(symbol, tf);
   double regimeVal = 0.5;
   switch(regime)
   {
      case REGIME_TRENDING: regimeVal = 0.75; break;
      case REGIME_RANGING:  regimeVal = 0.35; break;
      case REGIME_VOLATILE: regimeVal = 0.90; break;
      case REGIME_CALM:     regimeVal = 0.20; break;
   }
   features[14] = regimeVal;
   features[15] = GetSessionQuality();

   for(int i=0; i<16; i++) features[i] = MathMax(0.0, MathMin(1.0, features[i]));
}

void GetMarketFeatures(string symbol, double &features[], string dxy, string sp500, string us10y, string btc)
{
   GetMarketFeaturesEx(symbol, features, dxy, sp500, us10y, btc, _Period);
}

//+------------------------------------------------------------------+
//| Quantum Feature Layer                                            |
//+------------------------------------------------------------------+
void GetQuantumFeatures(string symbol, double &features[], int offset)
{
   int h = GetHandleSet(symbol);

   double entropy = CalculateReturnEntropy(symbol, 30);
   double memory  = CalculateHurstExponent(symbol, 100);

   double volRegime = 0.5;
   if(h >= 0)
   {
      double atr14 = QGetVal(g_qh[h].hATR14);
      double atr50 = QGetVal(g_qh[h].hATR50);
      if(atr50 > 0.0) volRegime = MathMax(0.0, MathMin(1.0, atr14 / (atr50 * 2.0)));
   }

   double momentum = CalculateMomentum(symbol, 5);
   double momNormalized = MathMax(0.0, MathMin(1.0, (momentum + 1.0) * 0.5));

   features[offset + 0] = entropy;
   features[offset + 1] = memory;
   features[offset + 2] = volRegime;
   features[offset + 3] = momNormalized;
}
//+------------------------------------------------------------------+
