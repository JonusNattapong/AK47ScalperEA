//+------------------------------------------------------------------+
//|                                                      AK47_AI.mqh |
//|                        Copyright 2026, AK47 Scalper EA Developer |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property link      ""
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| AI Neural Network - Lightweight for MQL5 Scalper                |
//+------------------------------------------------------------------+
class NeuralNet
{
private:
   double   weightsIH[12][6];   // Input -> Hidden
   double   weightsHO[6];       // Hidden -> Output
   double   biasH[6];
   double   biasO;
   
   double   sigmoid(const double x) const
   {
      return(1.0 / (1.0 + exp(-x)));
   }

public:
   NeuralNet()
   {
      // Initialize weights with optimized values for scalping
      double ih_vals[12][6] = {
         {0.12, -0.08, 0.21, -0.15, 0.07, 0.19},
         {-0.11, 0.14, -0.07, 0.22, -0.18, 0.09},
         {0.17, -0.12, 0.05, -0.09, 0.24, -0.13},
         {-0.06, 0.19, -0.14, 0.11, -0.05, 0.16},
         {0.20, -0.05, 0.13, -0.17, 0.09, -0.08},
         {-0.15, 0.10, -0.19, 0.06, -0.21, 0.12},
         {0.08, -0.16, 0.11, -0.13, 0.15, -0.07},
         {-0.13, 0.07, -0.09, 0.18, -0.10, 0.20},
         {0.14, -0.11, 0.17, -0.08, 0.12, -0.14},
         {-0.09, 0.15, -0.05, 0.14, -0.16, 0.08},
         {0.11, -0.18, 0.08, -0.20, 0.13, -0.11},
         {-0.07, 0.12, -0.16, 0.09, -0.08, 0.17}
      };
      
      double ho_vals[6] = {0.32, -0.28, 0.25, -0.22, 0.29, -0.19};
      double h_bias[6] = {0.05, -0.03, 0.07, -0.04, 0.06, -0.02};
      
      ArrayCopy(weightsIH, ih_vals);
      ArrayCopy(weightsHO, ho_vals);
      ArrayCopy(biasH, h_bias);
      biasO = 0.03;
   }
   
   double Predict(const double inputs[]) const
   {
      double hidden[6] = {0};
      
      // Calculate hidden layer
      for(int i=0; i<6; i++)
      {
         hidden[i] = biasH[i];
         for(int j=0; j<12; j++)
            hidden[i] += inputs[j] * weightsIH[j][i];
         hidden[i] = sigmoid(hidden[i]);
      }
      
      // Calculate output
      double output = biasO;
      for(int i=0; i<6; i++)
         output += hidden[i] * weightsHO[i];
      
      return(sigmoid(output));
   }
   
   // Online Train AI with actual market result
   void Train(const double inputs[], const double target, const double lr=0.008)
   {
      double hidden[6] = {0};
      double hiddenGrad[6] = {0};
      
      // Forward pass
      for(int i=0; i<6; i++)
      {
         hidden[i] = biasH[i];
         for(int j=0; j<12; j++)
            hidden[i] += inputs[j] * weightsIH[j][i];
         hidden[i] = sigmoid(hidden[i]);
      }
      
      double output = biasO;
      for(int i=0; i<6; i++)
         output += hidden[i] * weightsHO[i];
      output = sigmoid(output);
      
      // Calculate error
      const double error = target - output;
      const double outputDelta = error * output * (1.0 - output);
      
      // Update output weights
      for(int i=0; i<6; i++)
      {
         weightsHO[i] += lr * outputDelta * hidden[i];
         hiddenGrad[i] = outputDelta * weightsHO[i] * hidden[i] * (1.0 - hidden[i]);
      }
      biasO += lr * outputDelta;
      
      // Update hidden weights
      for(int i=0; i<6; i++)
      {
         for(int j=0; j<12; j++)
            weightsIH[j][i] += lr * hiddenGrad[i] * inputs[j];
         biasH[i] += lr * hiddenGrad[i];
      }
   }
};

//+------------------------------------------------------------------+
//| Market State Input Features for AI                               |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Market Condition Filter                                          |
//+------------------------------------------------------------------+
bool IsSidewayMarket()
{
   const double atr14 = iATR(_Symbol, _Period, 14, 0);
   const double atr50 = iATR(_Symbol, _Period, 50, 0);
   const double bbUpper = iBands(_Symbol, _Period, 20, 2, 0, PRICE_CLOSE, MODE_UPPER, 0);
   const double bbLower = iBands(_Symbol, _Period, 20, 2, 0, PRICE_CLOSE, MODE_LOWER, 0);
   
   return(atr14 < atr50 * 0.65 || (bbUpper - bbLower) < atr50 * 2.2);
}

double GetMarketVolatilityScore()
{
   return NormalizeDouble(iATR(_Symbol, _Period, 14, 0) / iATR(_Symbol, _Period, 50, 0), 2);
}

//+------------------------------------------------------------------+
//| Trading Time Filter                                              |
//+------------------------------------------------------------------+
bool IsGoodTradingTime()
{
   const int hour = TimeHour(TimeCurrent());
   const int day  = TimeDayOfWeek(TimeCurrent());
   
   // ไม่เทรด วันเสาร์ อาทิตย์
   if(day == 0 || day == 6) return false;
   
   // ช่วงเวลาที่เหมาะสมที่สุด London + New York Overlap
   return (hour >= 7 && hour <= 21);
}

//+------------------------------------------------------------------+
//| Multi Timeframe Trend Confirmation                               |
//+------------------------------------------------------------------+
bool TrendConfirmation(const ENUM_ORDER_TYPE direction)
{
   const double ma1h = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   const double ma4h = iMA(_Symbol, PERIOD_H4, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   const double price = iClose(_Symbol, _Period, 0);
   
   if(direction == ORDER_TYPE_BUY)
      return price > ma1h && price > ma4h;
   else
      return price < ma1h && price < ma4h;
}

//+------------------------------------------------------------------+
//| Market State Input Features for AI                               |
//+------------------------------------------------------------------+
void GetMarketFeatures(double &features[], const int symbol=0)
{
   features[0]  = NormalizeDouble((iClose(_Symbol, _Period, 0) - iOpen(_Symbol, _Period, 0)) / Point, 2);
   features[1]  = NormalizeDouble((iHigh(_Symbol, _Period, 0) - iLow(_Symbol, _Period, 0)) / Point, 2);
   features[2]  = NormalizeDouble((iClose(_Symbol, _Period, 0) - iClose(_Symbol, _Period, 1)) / Point, 2);
   features[3]  = iRSI(_Symbol, _Period, 14, PRICE_CLOSE, 0) / 100.0;
   features[4]  = iCCI(_Symbol, _Period, 20, 0) / 200.0 + 0.5;
   features[5]  = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 0) / Point / 10.0;
   features[6]  = iStochastic(_Symbol, _Period, 5, 3, 3, MODE_SMA, 0, MODE_MAIN, 0) / 100.0;
   features[7]  = iATR(_Symbol, _Period, 14, 0) / Point / 50.0;
   features[8]  = (iClose(_Symbol, _Period, 0) - iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE, 0)) / iATR(_Symbol, _Period, 14, 0);
   features[9]  = (iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE, 0) - iMA(_Symbol, _Period, 50, 0, MODE_SMA, PRICE_CLOSE, 0)) / iATR(_Symbol, _Period, 14, 0);
   features[10] = Volume[0] / Volume[1];
   features[11] = (Bid - Ask) / Point / 5.0;
   
   // Normalize all inputs between 0 and 1
   for(int i=0; i<12; i++)
      features[i] = MathMax(0.0, MathMin(1.0, (features[i] + 3.0) / 6.0));
}
//+------------------------------------------------------------------+
