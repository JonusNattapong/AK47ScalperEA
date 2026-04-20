//+------------------------------------------------------------------+
//|                                                      AK47_AI.mqh |
//|                        Copyright 2026, AK47 Scalper EA Developer |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property link      ""
#property version   "1.10"
#property strict

//+------------------------------------------------------------------+
//| AI Neural Network - Lightweight for MQL5 Scalper                |
//+------------------------------------------------------------------+
class NeuralNet
{
private:
   double   weightsIH[19][6];   // Input -> Hidden (16 Swarm + 3 Quantum)
   double   weightsHO[6];       // Hidden -> Output
   double   biasH[6];
   double   biasO;
   
   double   sigmoid(const double x) const { return(1.0 / (1.0 + exp(-x))); }

public:
   NeuralNet()
   {
      // Initialize base weights (12) + New Swarm weights (4)
      double ih_vals[19][6] = {
         {0.12, -0.08, 0.21, -0.15, 0.07, 0.19}, {-0.11, 0.14, -0.07, 0.22, -0.18, 0.09},
         {0.17, -0.12, 0.05, -0.09, 0.24, -0.13}, {-0.06, 0.19, -0.14, 0.11, -0.05, 0.16},
         {0.20, -0.05, 0.13, -0.17, 0.09, -0.08}, {-0.15, 0.10, -0.19, 0.06, -0.21, 0.12},
         {0.08, -0.16, 0.11, -0.13, 0.15, -0.07}, {-0.13, 0.07, -0.09, 0.18, -0.10, 0.20},
         {0.14, -0.11, 0.17, -0.08, 0.12, -0.14}, {-0.09, 0.15, -0.05, 0.14, -0.16, 0.08},
         {0.11, -0.18, 0.08, -0.20, 0.13, -0.11}, {-0.07, 0.12, -0.16, 0.09, -0.08, 0.17},
         // Swarm Weights: DXY, SP500, US10Y, BTC
         {0.15, -0.10, 0.25, -0.12, 0.18, 0.05}, {-0.20, 0.12, -0.15, 0.20, -0.09, 0.11},
         {0.10, -0.14, 0.08, -0.18, 0.22, -0.07}, {-0.05, 0.16, -0.11, 0.09, -0.13, 0.19},
         // Quantum Weights: Sentiment, Breakout, Denoise
         {0.22, -0.18, 0.30, -0.15, 0.24, 0.08}, {0.25, -0.20, 0.28, -0.17, 0.22, 0.11},
         {0.18, -0.12, 0.21, -0.10, 0.16, 0.06}
      };
      double ho_vals[6] = {0.32, -0.28, 0.25, -0.22, 0.29, -0.19};
      double h_bias[6] = {0.05, -0.03, 0.07, -0.04, 0.06, -0.02};
      
      for(int i=0; i<19; i++) for(int j=0; j<6; j++) weightsIH[i][j] = ih_vals[i][j];
      for(int i=0; i<6; i++) { weightsHO[i] = ho_vals[i]; biasH[i] = h_bias[i]; }
      biasO = 0.03;
   }
   
   double Predict(const double &inputs[])
   {
      double hidden[6] = {0};
      for(int i=0; i<6; i++) {
         hidden[i] = biasH[i];
         for(int j=0; j<19; j++) hidden[i] += inputs[j] * weightsIH[j][i];
         hidden[i] = sigmoid(hidden[i]);
      }
      double output = biasO;
      for(int i=0; i<6; i++) output += hidden[i] * weightsHO[i];
      return(sigmoid(output));
   }
   
   void Train(const double &inputs[], const double target, const double lr=0.01)
   {
      double hidden[6] = {0};
      for(int i=0; i<6; i++) {
         hidden[i] = biasH[i];
         for(int j=0; j<19; j++) hidden[i] += inputs[j] * weightsIH[j][i];
         hidden[i] = sigmoid(hidden[i]);
      }
      double output = biasO;
      for(int i=0; i<6; i++) output += hidden[i] * weightsHO[i];
      output = sigmoid(output);
      
      double error = target - output;
      double outputDelta = error * output * (1.0 - output);
      
      for(int i=0; i<6; i++) {
         double hiddenGrad = outputDelta * weightsHO[i] * hidden[i] * (1.0 - hidden[i]);
         weightsHO[i] += lr * outputDelta * hidden[i];
         for(int j=0; j<19; j++) weightsIH[j][i] += lr * hiddenGrad * inputs[j];
         biasH[i] += lr * hiddenGrad;
      }
      biasO += lr * outputDelta;
      SaveWeights();
   }

   // Persist weights to file
   void SaveWeights()
   {
      string filename = "AK47_Weights_" + _Symbol + ".bin";
      int file = FileOpen(filename, FILE_WRITE|FILE_BIN);
      if(file != INVALID_HANDLE) {
         FileWriteArray(file, weightsIH);
         FileWriteArray(file, weightsHO);
         FileWriteArray(file, biasH);
         FileWriteDouble(file, biasO);
         FileClose(file);
      }
   }

   // Load weights from file
   bool LoadWeights()
   {
      string filename = "AK47_Weights_" + _Symbol + ".bin";
      if(!FileIsExist(filename)) return false;
      
      int file = FileOpen(filename, FILE_READ|FILE_BIN);
      if(file != INVALID_HANDLE) {
         FileReadArray(file, weightsIH);
         FileReadArray(file, weightsHO);
         FileReadArray(file, biasH);
         biasO = FileReadDouble(file);
         FileClose(file);
         return true;
      }
      return false;
   }
};

//+------------------------------------------------------------------+
//| Indicator Handles Container                                    |
//+------------------------------------------------------------------+
int hATR14, hATR50, hRSI, hCCI, hStoch, hMACD, hMA20, hMA50, hMA1H, hMA4H, hBB;

void InitIndicators()
{
   hATR14 = iATR(_Symbol, _Period, 14);
   hATR50 = iATR(_Symbol, _Period, 50);
   hRSI   = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   hCCI   = iCCI(_Symbol, _Period, 20, PRICE_CLOSE);
   hStoch = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   hMACD  = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);
   hMA20  = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
   hMA50  = iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE);
   hMA1H  = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   hMA4H  = iMA(_Symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE);
   hBB    = iBands(_Symbol, _Period, 20, 0, 2, PRICE_CLOSE);
}

double GetVal(int handle, int buffer=0, int shift=0)
{
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, buffer, shift, 1, buf) > 0) return buf[0];
   return 0;
}

//+------------------------------------------------------------------+
//| Market Insights: Volume & Tick Flow                              |
//+------------------------------------------------------------------+
double GetTickSpeed()
{
   static datetime lastTickTime = 0;
   static int tickCount = 0;
   static double currentSpeed = 0;
   
   datetime now = TimeCurrent();
   tickCount++;
   
   if(now > lastTickTime)
   {
      currentSpeed = tickCount;
      tickCount = 0;
      lastTickTime = now;
   }
   return currentSpeed; // Ticks per second
}

double GetVolumeRatio()
{
   long vol[];
   if(CopyTickVolume(_Symbol, _Period, 0, 20, vol) < 20) return 1.0;
   
   double avgVol = 0;
   for(int i=1; i<20; i++) avgVol += (double)vol[i];
   avgVol /= 19.0;
   
   return (avgVol > 0) ? (double)vol[0] / avgVol : 1.0;
}

bool IsDxyStrong(string dxySymbol)
{
   if(dxySymbol == "" || dxySymbol == "NONE") return false;
   
   double pCurrent = SymbolInfoDouble(dxySymbol, SYMBOL_BID);
   double pOpen = 0;
   
   MqlRates rates[];
   if(CopyRates(dxySymbol, PERIOD_D1, 0, 1, rates) > 0)
      pOpen = rates[0].open;
      
   if(pOpen > 0)
   {
      double change = (pCurrent - pOpen) / pOpen * 100.0;
      return (change > 0.05); // Strong if up more than 0.05%
   }
   return false;
}

//+------------------------------------------------------------------+
//| SMC Layer: Order Block & Zone Detection                          |
//+------------------------------------------------------------------+
struct Zone { double top; double bottom; bool isDemand; };

Zone GetRecentOrderBlock(string symbol)
{
   Zone ob; ob.top = 0; ob.bottom = 0;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, _Period, 0, 100, rates) < 100) return ob;

   for(int i=5; i<95; i++)
   {
      double bodySize = MathAbs(rates[i].close - rates[i].open);
      double avgBody = 0;
      for(int j=i+1; j<i+10; j++) avgBody += MathAbs(rates[j].close - rates[j].open);
      avgBody /= 10.0;

      // เพิ่มระบบ FVG Confirmation (งานวิจัยแนะนำ)
      bool fvgFound = (rates[i-1].low > rates[i+1].high) || (rates[i-1].high < rates[i+1].low);

      if(bodySize > avgBody * 3.0 && fvgFound) 
      {
         ob.top = rates[i+1].high;
         ob.bottom = rates[i+1].low;
         ob.isDemand = (rates[i].close > rates[i].open);
         break;
      }
   }
   return ob;
}

bool IsInSmcZone(string symbol, bool lookForBuy)
{
   Zone ob = GetRecentOrderBlock(symbol);
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(lookForBuy) return (ob.isDemand && price <= ob.top && price >= ob.bottom);
   else return (!ob.isDemand && price >= ob.bottom && price <= ob.top);
}

//+------------------------------------------------------------------+
//| Intelligence-Based Risk (IBR)                                    |
//+------------------------------------------------------------------+
double CalculateDynamicLot(double baseLot, double confidence, double threshold)
{
   if(confidence < threshold) return 0.0;
   
   // ยิ่งมั่นใจเกิน Threshold มาก Lot ยิ่งเพิ่ม (Max 3x ของ BaseLot)
   double multiplier = 1.0 + (confidence - threshold) * 8.0; 
   if(multiplier > 3.0) multiplier = 3.0;
   
   return NormalizeDouble(baseLot * multiplier, 2);
}

//+------------------------------------------------------------------+
//| Quantitative Layer: Hurst Exponent (Market Memory)               |
//+------------------------------------------------------------------+
double CalculateHurstExponent(string symbol, int period)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, _Period, 0, period, rates) < period) return 0.5;
   
   double logRS[], logN[];
   ArrayResize(logRS, period/4);
   ArrayResize(logN, period/4);
   int idx = 0;

   // Simplified R/S Analysis
   for(int n=10; n<period; n+=10)
   {
      double mean = 0, std = 0;
      for(int i=0; i<n; i++) mean += rates[i].close;
      mean /= n;
      
      double maxDiff = -1e10, minDiff = 1e10, cumSum = 0;
      for(int i=0; i<n; i++) {
         cumSum += (rates[i].close - mean);
         maxDiff = MathMax(maxDiff, cumSum);
         minDiff = MathMin(minDiff, cumSum);
         std += MathPow(rates[i].close - mean, 2);
      }
      std = MathSqrt(std/n);
      
      if(std > 0) {
         logRS[idx] = MathLog((maxDiff - minDiff) / std);
         logN[idx] = MathLog(n);
         idx++;
      }
      if(idx >= period/4) break;
   }
   
   // Simple Linear Regression for Hurst (Slope)
   double sumX=0, sumY=0, sumXY=0, sumX2=0;
   for(int i=0; i<idx; i++) {
      sumX += logN[i]; sumY += logRS[i];
      sumXY += logN[i] * logRS[i];
      sumX2 += logN[i] * logN[i];
   }
   
   double hurst = (idx * sumXY - sumX * sumY) / (idx * sumX2 - sumX * sumX);
   return hurst;
}

bool IsMarketTrending(string symbol)
{
   double h = CalculateHurstExponent(symbol, 100);
   return (h > 0.55); // Persistent trend if > 0.55
}
bool IsSidewayMarket()
{
   double atr14 = GetVal(hATR14);
   double atr50 = GetVal(hATR50);
   double bbUp  = GetVal(hBB, 1); // UPPER_BAND
   double bbLo  = GetVal(hBB, 2); // LOWER_BAND
   return(atr14 < atr50 * 0.7 || (bbUp - bbLo) < atr50 * 2.5);
}

//+------------------------------------------------------------------+
//| V4 Session Engine                                                |
//+------------------------------------------------------------------+
enum SESSION_TYPE { SESSION_ASIAN, SESSION_LONDON, SESSION_NEWYORK, SESSION_OFF };

SESSION_TYPE GetCurrentSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return SESSION_OFF;
   int h = dt.hour; // Server time (GMT assumed)
   if(h >= 0 && h < 7)   return SESSION_ASIAN;
   if(h >= 7 && h < 13)  return SESSION_LONDON;
   if(h >= 13 && h < 21) return SESSION_NEWYORK;
   return SESSION_OFF;
}

string SessionToString(SESSION_TYPE s)
{
   switch(s) {
      case SESSION_ASIAN:    return "ASIAN";
      case SESSION_LONDON:   return "LONDON";
      case SESSION_NEWYORK:  return "NEW YORK";
      default:               return "OFF";
   }
}

bool IsGoodTradingTime()
{
   return (GetCurrentSession() != SESSION_OFF);
}

//+------------------------------------------------------------------+
//| V4 ATR-Dynamic SL/TP Calculator                                  |
//+------------------------------------------------------------------+
double GetDynamicSL(double atrMultiplier = 1.5)
{
   double atr = GetVal(hATR14);
   double minSL = 50 * _Point;   // Floor: 5 pips
   double maxSL = 500 * _Point;  // Ceiling: 50 pips
   double sl = atr * atrMultiplier;
   return MathMax(minSL, MathMin(maxSL, sl));
}

double GetDynamicTP(double atrMultiplier = 2.5)
{
   double atr = GetVal(hATR14);
   double minTP = 80 * _Point;   // Floor: 8 pips
   double maxTP = 800 * _Point;  // Ceiling: 80 pips
   double tp = atr * atrMultiplier;
   return MathMax(minTP, MathMin(maxTP, tp));
}

//+------------------------------------------------------------------+
//| V4 Equity Curve Filter                                           |
//+------------------------------------------------------------------+
bool IsEquityCurveHealthy(double currentEquity, double startBalance, int recentWins, int recentLosses)
{
   // If losing streak > 5 in a row from recent trades, pause
   if(recentLosses > 5 && recentWins == 0) return false;
   // If equity dropped > 3% from start, slow down
   double drawdown = ((startBalance - currentEquity) / startBalance) * 100.0;
   if(drawdown > 3.0) return false;
   return true;
}

bool IsSpreadOK(int maxSpreadPoints)
{
   int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread <= maxSpreadPoints);
}

bool TrendConfirmation(const ENUM_POSITION_TYPE direction)
{
   double ma1h = GetVal(hMA1H);
   double ma4h = GetVal(hMA4H);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (direction == POSITION_TYPE_BUY) ? (price > ma1h && price > ma4h) : (price < ma1h && price < ma4h);
}

//+------------------------------------------------------------------+
//| Swarm Integration: Get Symbol % Change                           |
//+------------------------------------------------------------------+
double GetSymbolChange(string sym)
{
   if(sym == "" || sym == "NULL" || !SymbolSelect(sym, true)) return 0.0;
   MqlRates r[]; ArraySetAsSeries(r, true);
   if(CopyRates(sym, PERIOD_H1, 0, 2, r) < 2) return 0.0;
   return (r[0].close - r[1].close) / (r[1].close + 1e-9);
}

//+------------------------------------------------------------------+
//| Feature Extraction (V4.0 - Multi-TF + Swarm - 16 Inputs)        |
//+------------------------------------------------------------------+
void GetMarketFeatures(double &features[], string dxy, string sp500, string us10y, string btc)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   CopyRates(_Symbol, _Period, 0, 2, rates);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // M1 Price Action Features (0-7)
   features[0]  = (rates[0].close - rates[0].open) / (point * 10.0);
   features[1]  = (rates[0].high - rates[0].low) / (point * 10.0);
   features[2]  = (rates[0].close - rates[1].close) / (point * 10.0);
   features[3]  = GetVal(hRSI) / 100.0;
   features[4]  = GetVal(hCCI) / 200.0 + 0.5;
   features[5]  = GetVal(hMACD) / (point * 10.0);
   features[6]  = GetVal(hStoch) / 100.0;
   features[7]  = GetVal(hATR14) / (point * 100.0);

   // Market Structure Features (8-11)
   features[8]  = (rates[0].close - GetVal(hMA20)) / (GetVal(hATR14) + 0.0001);
   features[9]  = GetVolumeRatio() / 2.0;
   features[10] = (double)GetTickSpeed() / 20.0;
   features[11] = CalculateHurstExponent(_Symbol, 50);

   // Swarm Features (12-15)
   features[12] = GetSymbolChange(dxy) * 100.0 + 0.5;
   features[13] = GetSymbolChange(sp500) * 100.0 + 0.5;
   features[14] = GetSymbolChange(us10y) * 100.0 + 0.5;
   features[15] = GetSymbolChange(btc) * 100.0 + 0.5;

   for(int i=0; i<16; i++) features[i] = MathMax(0.0, MathMin(1.0, features[i]));
}

//+------------------------------------------------------------------+
//| V4 True Multi-TF: H1 Feature Extraction                          |
//+------------------------------------------------------------------+
void GetH1Features(double &features[], string dxy, string sp500, string us10y, string btc)
{
   MqlRates h1Rates[];
   ArraySetAsSeries(h1Rates, true);
   CopyRates(_Symbol, PERIOD_H1, 0, 3, h1Rates);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // H1 Price Action
   features[0]  = (h1Rates[0].close - h1Rates[0].open) / (point * 100.0);
   features[1]  = (h1Rates[0].high - h1Rates[0].low) / (point * 100.0);
   features[2]  = (h1Rates[0].close - h1Rates[1].close) / (point * 100.0);

   // H1 Indicators (use dedicated H1 MA handles)
   features[3]  = GetVal(hRSI) / 100.0;
   features[4]  = GetVal(hCCI) / 200.0 + 0.5;
   features[5]  = (h1Rates[0].close - GetVal(hMA1H)) / (GetVal(hATR14) + 0.0001);
   features[6]  = (GetVal(hMA1H) - GetVal(hMA4H)) / (GetVal(hATR14) + 0.0001);
   features[7]  = GetVal(hATR14) / (point * 100.0);

   // H1 Structure
   features[8]  = CalculateHurstExponent(_Symbol, 100);
   features[9]  = GetVolumeRatio() / 2.0;
   features[10] = (h1Rates[0].close > h1Rates[1].close && h1Rates[1].close > h1Rates[2].close) ? 1.0 : 0.0;
   features[11] = (h1Rates[0].close < h1Rates[1].close && h1Rates[1].close < h1Rates[2].close) ? 1.0 : 0.0;

   // Swarm (same global context)
   features[12] = GetSymbolChange(dxy) * 100.0 + 0.5;
   features[13] = GetSymbolChange(sp500) * 100.0 + 0.5;
   features[14] = GetSymbolChange(us10y) * 100.0 + 0.5;
   features[15] = GetSymbolChange(btc) * 100.0 + 0.5;

   for(int i=0; i<16; i++) features[i] = MathMax(0.0, MathMin(1.0, features[i]));
}

//+------------------------------------------------------------------+
