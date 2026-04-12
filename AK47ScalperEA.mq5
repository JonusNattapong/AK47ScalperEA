//+------------------------------------------------------------------+
//|                                                  AK47ScalperEA.mq5 |
//|                        Copyright 2026, AK47 Scalper EA Developer |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AK47 Scalper EA"
#property link      ""
#property version   "1.00"
#property strict
#property description "AK47 AI Scalper Expert Advisor"

// EA Settings
input double LotSize          = 0.01;
input int    StopLossPoints   = 15;
input int    TakeProfitPoints = 25;
input double AiThresholdBuy   = 0.72;
input double AiThresholdSell  = 0.28;
input int    MagicNumber      = 4747;
input int    MaxOrders        = 1;
input double MaxDailyDrawdown = 3.0;   // % Max drawdown per day
input bool   DynamicLotSize   = true;
input bool   AiSelfLearning   = true;
input bool   SkipSideway      = true;
input bool   TimeFilter       = true;
input bool   TrendConfirm     = true;
input int    BreakEvenAfter   = 12;     // Points profit for BE

#include "AK47_AI.mqh"

NeuralNet *ai;
double dailyStartBalance;
double lastPrediction;
double lastFeatures[12];
datetime lastTradeTime;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ai = new NeuralNet();
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   lastTradeTime = 0;
   Print("✅ AK47 AI Scalper EA Initialized");
   Print("🧠 AI Neural Network Ready | Self Learning: ", AiSelfLearning ? "ON" : "OFF");
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   delete ai;
   Print("AK47 AI Scalper EA Shutdown");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Drawdown Protection
   const double currentDrawdown = ((dailyStartBalance - AccountInfoDouble(ACCOUNT_EQUITY)) / dailyStartBalance) * 100.0;
   if(currentDrawdown > MaxDailyDrawdown)
   {
      static bool warned = false;
      if(!warned) { Print("⚠️  Max Drawdown Reached: ", NormalizeDouble(currentDrawdown,2), "% | EA Stopped for today"); warned = true; }
      return;
   }

   // Skip Sideway Market
   if(SkipSideway && IsSidewayMarket())
      return;
      
   // Time Filter
   if(TimeFilter && !IsGoodTradingTime())
      return;
      
   int totalOrders = OrdersTotalMagic();
   
   if(totalOrders >= MaxOrders)
   {
      ManagePositions();
      return;
   }
      
   double features[12];
   GetMarketFeatures(features);
   
   const double prediction = ai.Predict(features);
   
   // Dynamic Lot Size based on AI confidence
   double actualLot = LotSize;
   if(DynamicLotSize)
   {
      const double confidence = MathAbs(prediction - 0.5) * 2.0;
      actualLot = LotSize * (0.5 + confidence);
      actualLot = NormalizeDouble(actualLot, 2);
   }
   
   // AI BUY SIGNAL
   if(prediction > AiThresholdBuy && OrdersTotalMagic(ORDER_TYPE_BUY) == 0 && TimeCurrent() > lastTradeTime + 60)
   {
      if(!TrendConfirm || TrendConfirmation(ORDER_TYPE_BUY))
      {
         ArrayCopy(lastFeatures, features);
         lastPrediction = prediction;
         OpenOrder(ORDER_TYPE_BUY, actualLot);
         lastTradeTime = TimeCurrent();
         Print("🤖 AI BUY | Confidence: ", NormalizeDouble(prediction*100,1), "% | Lot: ", actualLot);
      }
   }
   
   // AI SELL SIGNAL
   if(prediction < AiThresholdSell && OrdersTotalMagic(ORDER_TYPE_SELL) == 0 && TimeCurrent() > lastTradeTime + 60)
   {
      if(!TrendConfirm || TrendConfirmation(ORDER_TYPE_SELL))
      {
         ArrayCopy(lastFeatures, features);
         lastPrediction = prediction;
         OpenOrder(ORDER_TYPE_SELL, actualLot);
         lastTradeTime = TimeCurrent();
         Print("🤖 AI SELL | Confidence: ", NormalizeDouble((1.0-prediction)*100,1), "% | Lot: ", actualLot);
      }
   }
   
   ManagePositions();
}
//+------------------------------------------------------------------+
//| Count orders with our magic number                               |
//+------------------------------------------------------------------+
int OrdersTotalMagic(const ENUM_ORDER_TYPE type=-1)
{
   int count=0;
   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         if(type == -1 || PositionGetInteger(POSITION_TYPE) == type)
            count++;
      }
   }
   return(count);
}
//+------------------------------------------------------------------+
//| Open Trade Order                                                 |
//+------------------------------------------------------------------+
bool OpenOrder(const ENUM_ORDER_TYPE type, const double lot=LotSize)
{
   MqlTradeRequest request = {0};
   MqlTradeResult  result  = {0};
   
   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.volume   = lot;
   request.type     = type;
   request.price    = (type==ORDER_TYPE_BUY) ? Ask : Bid;
   request.deviation= 3;
   request.magic    = MagicNumber;
   request.comment  = "AK47 AI Trade";
   
   if(StopLossPoints > 0)
      request.sl = (type==ORDER_TYPE_BUY) ? (Ask - StopLossPoints*Point) : (Bid + StopLossPoints*Point);
      
   if(TakeProfitPoints > 0)
      request.tp = (type==ORDER_TYPE_BUY) ? (Ask + TakeProfitPoints*Point) : (Bid - TakeProfitPoints*Point);
   
   return OrderSend(request, result);
}
//+------------------------------------------------------------------+
//| Manage Open Positions                                            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i=0; i<PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      
      if(PositionSelectByTicket(ticket) && 
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         const double profit = PositionGetDouble(POSITION_PROFIT);
         const ENUM_ORDER_TYPE posType = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
         
         // Trailing Stop Logic
         if(profit > TakeProfitPoints*Point*LotSize * 0.35)
         {
            double newSL = posType == ORDER_TYPE_BUY ? 
               PositionGetDouble(POSITION_PRICE_OPEN) + 3*Point :
               PositionGetDouble(POSITION_PRICE_OPEN) - 3*Point;
            
            ModifyPosition(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
      }
   }
}
//+------------------------------------------------------------------+
