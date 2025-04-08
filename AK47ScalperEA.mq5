//+------------------------------------------------------------------+
//|                                              AK47ScalperEA.mq5   |
//|                        Copyright 2025, JonusNattapong                 |
//|                                     https://github.com/JonusNattapong  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, JonusNattapong"
#property link      "https://github.com/JonusNattapong"
#property version   "1.00"
#property strict
#property description "XAU/USD M1 Scalping EA with AI Signals and SMC"

// Include necessary files
#include "AK47_AI_Module.mqh"
#include "AK47_SMC_Module.mqh"
#include "AK47_Risk_Module.mqh"
#include "AK47_Report_Module.mqh"

// EA Input Parameters
// General Settings
input string    EAName = "AK47ScalperEA";     // EA Name
input string    GeneralSettings = "------- General Settings -------"; // General Settings
input bool      IsEAEnabled = true;           // Enable EA
input bool      UseVisualDashboard = true;    // Use Visual Dashboard

// Trading Settings
input string    TradingSettings = "------- Trading Settings -------"; // Trading Settings
input bool      AllowBuyTrades = true;        // Allow Buy Trades
input bool      AllowSellTrades = true;       // Allow Sell Trades
input ENUM_TIMEFRAMES TradingTimeframe = PERIOD_M1; // Trading Timeframe
input int       MaxSimultaneousTrades = 3;    // Max Simultaneous Trades
input int       MaxDailyTrades = 10;          // Max Daily Trades
input int       StartHour = 0;                // Trading Start Hour (0-23)
input int       EndHour = 23;                 // Trading End Hour (0-23)

// AI Signal Settings
input string    AISettings = "------- AI Signal Settings -------"; // AI Signal Settings
input bool      UseAISignals = true;          // Use AI Signals
input int       AISignalPeriod = 14;          // AI Signal Period
input double    AIThreshold = 0.75;           // AI Signal Threshold (0.0-1.0)
input int       AIHistoryBars = 1000;         // AI Learning History Bars

// SMC Settings
input string    SMCSettings = "------- SMC Settings -------"; // SMC Settings
input bool      UseSMCAnalysis = true;        // Use SMC Analysis
input int       SMCOrderBlockLookback = 20;   // Order Block Lookback Bars
input bool      UseSupplyDemandZones = true;  // Use Supply/Demand Zones
input bool      UseBreakOfStructure = true;   // Use Break of Structure

// Risk Management Settings
input string    RiskSettings = "------- Risk Management Settings -------"; // Risk Management Settings
input double    RiskPercent = 1.0;            // Risk Percent per Trade (0.1-5.0)
input bool      UseFixedLotSize = false;      // Use Fixed Lot Size
input double    FixedLotSize = 0.01;          // Fixed Lot Size if Enabled
input int       StopLossPoints = 300;         // Stop Loss Points
input int       TakeProfitPoints = 450;       // Take Profit Points
input bool      UseTrailingStop = true;       // Use Trailing Stop
input int       TrailingStopPoints = 150;     // Trailing Stop Points
input int       TrailingStopStart = 200;      // Trailing Stop Start Points
input bool      UseBreakEven = true;          // Use Break Even
input int       BreakEvenPoints = 150;        // Break Even Points

// Global Variables
CAK47AIModule*     AI;                      // AI Signal Module
CAK47SMCModule*    SMC;                     // SMC Analysis Module
CAK47RiskModule*   Risk;                    // Risk Management Module  
CAK47ReportModule* Report;                  // Reporting Module

int OnInit()
{
    // Initialize modules
    AI = new CAK47AIModule(AISignalPeriod, AIThreshold, AIHistoryBars);
    SMC = new CAK47SMCModule(SMCOrderBlockLookback, UseSupplyDemandZones, UseBreakOfStructure);
    Risk = new CAK47RiskModule(RiskPercent, UseFixedLotSize, FixedLotSize, 
                               StopLossPoints, TakeProfitPoints, 
                               UseTrailingStop, TrailingStopPoints, TrailingStopStart,
                               UseBreakEven, BreakEvenPoints);
    Report = new CAK47ReportModule(EAName, UseVisualDashboard);
    
    // Print welcome message
    Print("AK47ScalperEA initialized. Version 1.00");
    
    // Setup event timer for regular updates
    EventSetTimer(1);
    
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    // Clean up modules
    delete AI;
    delete SMC;
    delete Risk;
    delete Report;
    
    // Remove event timer
    EventKillTimer();
    
    // Print exit message
    Print("AK47ScalperEA terminated. Reason: ", reason);
}

void OnTick()
{
    // Check if EA is enabled
    if(!IsEAEnabled)
        return;
    
    // Check trading hours
    datetime currentTime = TimeCurrent();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    
    if(timeStruct.hour < StartHour || timeStruct.hour >= EndHour)
        return;
    
    // Check max daily trades
    if(Report.GetDailyTradeCount() >= MaxDailyTrades)
        return;
    
    // Check open trades count
    if(Report.GetOpenTradeCount() >= MaxSimultaneousTrades)
        return;
    
    // Get latest market data
    MqlTick latestPrice;
    SymbolInfoTick(_Symbol, latestPrice);
    
    // Get signal from AI module
    double aiSignal = 0;
    if(UseAISignals)
        aiSignal = AI.GetSignal();
    
    // Get SMC analysis
    int smcSignal = 0;
    if(UseSMCAnalysis)
        smcSignal = SMC.GetSignal();
    
    // Combine signals for decision
    int combinedSignal = CombineSignals(aiSignal, smcSignal);
    
    // Execute trades based on signals if allowed
    if(combinedSignal > 0 && AllowBuyTrades)
    {
        // Calculate lot size and risk parameters
        double lotSize = Risk.CalculateLotSize(StopLossPoints);
        int stopLoss = StopLossPoints;
        int takeProfit = TakeProfitPoints;
        
        // Open buy trade
        if(OpenBuyTrade(lotSize, stopLoss, takeProfit))
        {
            Report.LogTrade(true, lotSize, latestPrice.ask, stopLoss, takeProfit);
        }
    }
    else if(combinedSignal < 0 && AllowSellTrades)
    {
        // Calculate lot size and risk parameters
        double lotSize = Risk.CalculateLotSize(StopLossPoints);
        int stopLoss = StopLossPoints;
        int takeProfit = TakeProfitPoints;
        
        // Open sell trade
        if(OpenSellTrade(lotSize, stopLoss, takeProfit))
        {
            Report.LogTrade(false, lotSize, latestPrice.bid, stopLoss, takeProfit);
        }
    }
    
    // Manage existing trades
    ManageOpenTrades();
    
    // Update dashboard
    if(UseVisualDashboard)
        Report.UpdateDashboard();
}

void OnTimer()
{
    // Update AI model with new data (can be done less frequently than on every tick)
    if(UseAISignals)
        AI.UpdateModel();
    
    // Update SMC analysis
    if(UseSMCAnalysis)
        SMC.UpdateAnalysis();
    
    // Update reporting metrics
    Report.UpdateMetrics();
}

int CombineSignals(double aiSignal, int smcSignal)
{
    // Simple signal combination logic
    // Could be enhanced with more sophisticated algorithms
    
    if(aiSignal > AIThreshold && smcSignal > 0)
        return 1;  // Strong buy signal
    
    if(aiSignal < -AIThreshold && smcSignal < 0)
        return -1; // Strong sell signal
    
    if(aiSignal > AIThreshold * 0.7 || smcSignal > 0)
        return 1;  // Moderate buy signal
    
    if(aiSignal < -AIThreshold * 0.7 || smcSignal < 0)
        return -1; // Moderate sell signal
    
    return 0;      // No clear signal
}

bool OpenBuyTrade(double lotSize, int stopLoss, int takeProfit)
{
    MqlTick latestPrice;
    SymbolInfoTick(_Symbol, latestPrice);
    
    double sl = stopLoss > 0 ? latestPrice.ask - stopLoss * _Point : 0;
    double tp = takeProfit > 0 ? latestPrice.ask + takeProfit * _Point : 0;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = latestPrice.ask;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = 1234567;
    request.comment = "AK47ScalperEA Buy";
    request.type_filling = ORDER_FILLING_FOK;
    
    bool success = OrderSend(request, result);
    
    if(!success)
        Print("OrderSend error: ", GetLastError());
    
    return success;
}

bool OpenSellTrade(double lotSize, int stopLoss, int takeProfit)
{
    MqlTick latestPrice;
    SymbolInfoTick(_Symbol, latestPrice);
    
    double sl = stopLoss > 0 ? latestPrice.bid + stopLoss * _Point : 0;
    double tp = takeProfit > 0 ? latestPrice.bid - takeProfit * _Point : 0;
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = latestPrice.bid;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.magic = 1234567;
    request.comment = "AK47ScalperEA Sell";
    request.type_filling = ORDER_FILLING_FOK;
    
    bool success = OrderSend(request, result);
    
    if(!success)
        Print("OrderSend error: ", GetLastError());
    
    return success;
}

void ManageOpenTrades()
{
    // Iterate through all open positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        
        if(ticket <= 0)
            continue;
            
        if(!PositionSelectByTicket(ticket))
            continue;
            
        // Get position details
        string symbol = PositionGetString(POSITION_SYMBOL);
        int type = (int)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        
        // Only manage our symbol positions
        if(symbol != _Symbol)
            continue;
            
        // Manage trailing stop if enabled
        if(UseTrailingStop)
        {
            Risk.ManageTrailingStop(ticket, type, openPrice, currentSL);
        }
        
        // Manage break even if enabled
        if(UseBreakEven)
        {
            Risk.ManageBreakEven(ticket, type, openPrice, currentSL);
        }
    }
}