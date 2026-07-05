//+------------------------------------------------------------------+
//|                                                 AK47_Quantum.mqh |
//|                        Copyright 2026, AK47 Scalper EA Developer |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
//| Quantum Feature Engine for the AK47 PURE AGENT EDITION.           |
//|                                                                   |
//| This module is 100% self-contained. It replaces the removed      |
//| neural-network module (AK47_AI.mqh) with a lightweight, purely    |
//| quantitative feature extractor that feeds the Kilo API agent.     |
//|                                                                   |
//| It exposes:                                                       |
//|   - StringTrim()          : trim helper                           |
//|   - GetCurrentSession()   : trading session engine                |
//|   - InitQuantumEngine()   : allocate per-symbol indicator handles |
//|   - DeinitQuantumEngine() : release all handles                   |
//|   - GetMarketFeatures()   : features[0..15]  (price/structure)    |
//|   - GetQuantumFeatures()  : features[16..18] (entropy/memory/vol) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property link      ""
#property version   "5.00"
#property strict

#define QUANTUM_MAX_SYMBOLS 8

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
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return SESSION_OFF; // Weekend
   int h = dt.hour; // Server time (GMT assumed)
   if(h >= 0 && h < 7)   return SESSION_ASIAN;
   if(h >= 7 && h < 13)  return SESSION_LONDON;
   if(h >= 13 && h < 21) return SESSION_NEWYORK;
   return SESSION_OFF;
}

string SessionToString(SESSION_TYPE s)
{
   switch(s)
   {
      case SESSION_ASIAN:   return "ASIAN";
      case SESSION_LONDON:  return "LONDON";
      case SESSION_NEWYORK: return "NEW YORK";
      default:              return "OFF";
   }
}

//+------------------------------------------------------------------+
//| Per-symbol indicator handle cache                                |
//+------------------------------------------------------------------+
struct QuantumHandles
{
   string symbol;
   bool   ready;
   int    hRSI;
   int    hCCI;
   int    hMACD;
   int    hStoch;
   int    hATR14;
   int    hATR50;
   int    hMA20;
   int    hMA1H;
   int    hMA4H;
   int    hBB;
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
   Print("⚛️ Quantum Feature Engine initialized (lazy per-symbol handles)");
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
   if(g_qh[idx].hMA1H  != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hMA1H);
   if(g_qh[idx].hMA4H  != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hMA4H);
   if(g_qh[idx].hBB    != INVALID_HANDLE) IndicatorRelease(g_qh[idx].hBB);
   g_qh[idx].ready = false;
}

void DeinitQuantumEngine()
{
   for(int i=0; i<g_qhCount; i++) ReleaseHandleSet(i);
   g_qhCount = 0;
}

//+------------------------------------------------------------------+
//| Resolve (and lazily create) the handle set for a symbol.         |
//| Returns index into g_qh[], or -1 on failure.                     |
//+------------------------------------------------------------------+
int GetHandleSet(string symbol)
{
   for(int i=0; i<g_qhCount; i++)
      if(g_qh[i].symbol == symbol && g_qh[i].ready) return i;

   if(g_qhCount >= QUANTUM_MAX_SYMBOLS) return -1;

   int idx = g_qhCount;
   QuantumHandles hset;
   hset.symbol = symbol;
   hset.hRSI   = iRSI(symbol, _Period, 14, PRICE_CLOSE);
   hset.hCCI   = iCCI(symbol, _Period, 20, PRICE_CLOSE);
   hset.hMACD  = iMACD(symbol, _Period, 12, 26, 9, PRICE_CLOSE);
   hset.hStoch = iStochastic(symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   hset.hATR14 = iATR(symbol, _Period, 14);
   hset.hATR50 = iATR(symbol, _Period, 50);
   hset.hMA20  = iMA(symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
   hset.hMA1H  = iMA(symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   hset.hMA4H  = iMA(symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
   hset.hBB    = iBands(symbol, _Period, 20, 0, 2.0, PRICE_CLOSE);

   if(hset.hRSI == INVALID_HANDLE || hset.hATR14 == INVALID_HANDLE)
   {
      Print("⚠️ Quantum: failed to create indicators for ", symbol);
      return -1;
   }

   hset.ready = true;
   g_qh[idx]  = hset;
   g_qhCount++;
   return idx;
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
//| Volume ratio: current bar volume vs recent average               |
//+------------------------------------------------------------------+
double GetVolumeRatio(string symbol)
{
   long vol[];
   if(CopyTickVolume(symbol, _Period, 0, 20, vol) < 20) return 1.0;

   double avgVol = 0.0;
   for(int i=1; i<20; i++) avgVol += (double)vol[i];
   avgVol /= 19.0;

   return (avgVol > 0.0) ? (double)vol[0] / avgVol : 1.0;
}

//+------------------------------------------------------------------+
//| % change over the last completed H1 candle                       |
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
//| Hurst exponent (market memory) via simplified R/S analysis       |
//|   > 0.5 : persistent / trending                                  |
//|   ~ 0.5 : random walk                                            |
//|   < 0.5 : mean reverting                                         |
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
//| Shannon entropy of the last N return signs (market uncertainty). |
//| Returns 0.0 (fully ordered) .. 1.0 (maximum randomness).         |
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

   return MathMax(0.0, MathMin(1.0, entropy)); // Already in [0,1] for 2 outcomes
}

//+------------------------------------------------------------------+
//| Current ATR(14) value in price terms for a symbol.               |
//| MQL5-safe replacement for the legacy value-style iATR() call.    |
//+------------------------------------------------------------------+
double GetAtrValue(string symbol)
{
   int h = GetHandleSet(symbol);
   if(h < 0) return 0.0;
   return QGetVal(g_qh[h].hATR14);
}

//+------------------------------------------------------------------+
//| Feature Extraction (0..15) - price action + structure + swarm    |
//+------------------------------------------------------------------+
void GetMarketFeatures(string symbol, double &features[], string dxy, string sp500, string us10y, string btc)
{
   int h = GetHandleSet(symbol);
   if(h < 0)
   {
      for(int i=0; i<16; i++) features[i] = 0.5; // neutral fallback
      return;
   }
   QuantumHandles hs = g_qh[h];

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, _Period, 0, 2, rates) < 2)
   {
      for(int i=0; i<16; i++) features[i] = 0.5;
      return;
   }

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0) point = _Point;
   double atr14 = QGetVal(hs.hATR14);

   // M1 Price Action Features (0-7)
   features[0]  = (rates[0].close - rates[0].open) / (point * 10.0);
   features[1]  = (rates[0].high - rates[0].low) / (point * 10.0);
   features[2]  = (rates[0].close - rates[1].close) / (point * 10.0);
   features[3]  = QGetVal(hs.hRSI) / 100.0;
   features[4]  = QGetVal(hs.hCCI) / 200.0 + 0.5;
   features[5]  = QGetVal(hs.hMACD) / (point * 10.0);
   features[6]  = QGetVal(hs.hStoch) / 100.0;
   features[7]  = atr14 / (point * 100.0);

   // Market Structure Features (8-11)
   features[8]  = (rates[0].close - QGetVal(hs.hMA20)) / (atr14 + 0.0001);
   features[9]  = GetVolumeRatio(symbol) / 2.0;
   features[10] = (QGetVal(hs.hMA1H) - QGetVal(hs.hMA4H)) / (atr14 + 0.0001);
   features[11] = CalculateHurstExponent(symbol, 50);

   // Swarm / Global Correlation Features (12-15)
   features[12] = GetSymbolChange(dxy) * 100.0 + 0.5;
   features[13] = GetSymbolChange(sp500) * 100.0 + 0.5;
   features[14] = GetSymbolChange(us10y) * 100.0 + 0.5;
   features[15] = GetSymbolChange(btc) * 100.0 + 0.5;

   for(int i=0; i<16; i++) features[i] = MathMax(0.0, MathMin(1.0, features[i]));
}

//+------------------------------------------------------------------+
//| Quantum Feature Layer (offset..offset+2)                         |
//|   [offset+0] Return entropy   : market randomness                |
//|   [offset+1] Market memory     : Hurst exponent                  |
//|   [offset+2] Volatility regime : short vs long ATR compression   |
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

   features[offset + 0] = entropy;
   features[offset + 1] = memory;
   features[offset + 2] = volRegime;
}
//+------------------------------------------------------------------+
