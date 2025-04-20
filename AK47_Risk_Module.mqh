//+------------------------------------------------------------------+
//|                                       AK47_Risk_Module.mqh    |
//|                        Copyright 2025, JonusNattapong                 |
//|                                     https://github.com/JonusNattapong  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, JonusNattapong"
#property link      "https://github.com/JonusNattapong"
#property version   "1.00"

// Include necessary files
#include <Trade\Trade.mqh>

// Risk Management Module
class CAK47RiskModule
{
private:
    double          m_riskPercent;          // Risk percent per trade
    bool            m_useFixedLotSize;      // Use fixed lot size
    double          m_fixedLotSize;         // Fixed lot size if enabled
    int             m_stopLossPoints;       // Stop loss points
    int             m_takeProfitPoints;     // Take profit points
    bool            m_useTrailingStop;      // Use trailing stop
    int             m_trailingStopPoints;   // Trailing stop points
    int             m_trailingStopStart;    // Trailing stop start points
    bool            m_useBreakEven;         // Use break even
    int             m_breakEvenPoints;      // Break even points
    
    // New risk management parameters
    enum ENUM_RISK_MODEL {
        RISK_FIXED_PERCENT,       // Fixed percentage of account
        RISK_KELLY_CRITERION,     // Kelly criterion-based sizing
        RISK_VOLATILITY_BASED,    // Volatility-based sizing
        RISK_MARTINGALE,          // Martingale strategy (use with caution)
        RISK_ANTI_MARTINGALE      // Anti-martingale strategy
    };
    
    ENUM_RISK_MODEL   m_riskModel;           // Risk calculation model
    double            m_maxDrawdownPercent;  // Maximum allowed drawdown percentage
    double            m_riskRewardRatio;     // Target risk-to-reward ratio
    bool              m_useATRForSL;         // Use ATR for stop loss calculation
    int               m_atrPeriod;           // ATR period for volatility calculation
    double            m_atrMultiplier;       // Multiplier for ATR-based stop loss
    bool              m_partialClose;        // Use partial position closing
    double            m_partialClosePercent; // Percentage to close at first target
    double            m_partialCloseProfit;  // Profit in points to trigger partial close
    
    CTrade*         m_trade;                // Trade object for order management
    
    // Private methods
    double          GetAccountBalance();
    double          CalculateRiskAmount();
    double          GetPointValue();
    bool            ModifyPosition(ulong ticket, double newSL, double newTP);
    double          CalculateATR(int period);
    double          ApplyKellyCriterion(double winRate, double winLossRatio);
    double          CalculateVolatilityBasedLotSize(double atr);
    bool            CheckMaxDrawdown();
    double          GetTotalRiskExposure();
    bool            ApplyPartialClose(ulong ticket, int posType, double openPrice, double currentProfit);
    
public:
                    CAK47RiskModule(double riskPercent, bool useFixedLotSize, double fixedLotSize,
                                    int stopLossPoints, int takeProfitPoints,
                                    bool useTrailingStop, int trailingStopPoints, int trailingStopStart,
                                    bool useBreakEven, int breakEvenPoints);
                   ~CAK47RiskModule();
    
    double          CalculateLotSize(int stopLossPoints);
    bool            ManageTrailingStop(ulong ticket, int posType, double openPrice, double currentSL);
    bool            ManageBreakEven(ulong ticket, int posType, double openPrice, double currentSL);
    string          GetRiskStats();
    double          GetMaxLossAmount();
    
    // New public methods
    void            SetRiskModel(ENUM_RISK_MODEL model) { m_riskModel = model; }
    void            SetMaxDrawdown(double maxDrawdownPercent) { m_maxDrawdownPercent = maxDrawdownPercent; }
    void            SetRiskRewardRatio(double ratio) { m_riskRewardRatio = ratio; }
    void            SetATRParameters(bool useATR, int period, double multiplier);
    void            EnablePartialClose(bool enable, double percent, double profitPoints);
    double          CalculateDynamicTakeProfit(int stopLossPoints);
    double          GetCurrentDrawdownPercent();
    bool            ManageAllPositions();
    bool            UseTimedExit(ulong ticket, datetime openTime, int maxMinutes);
    double          GetWinRate();
};

//+------------------------------------------------------------------+
//|                    Constructor                                   |
//+------------------------------------------------------------------+
CAK47RiskModule::CAK47RiskModule(double riskPercent, bool useFixedLotSize, double fixedLotSize,
                                 int stopLossPoints, int takeProfitPoints,
                                 bool useTrailingStop, int trailingStopPoints, int trailingStopStart,
                                 bool useBreakEven, int breakEvenPoints)
{
    m_riskPercent = riskPercent;
    m_useFixedLotSize = useFixedLotSize;
    m_fixedLotSize = fixedLotSize;
    m_stopLossPoints = stopLossPoints;
    m_takeProfitPoints = takeProfitPoints;
    m_useTrailingStop = useTrailingStop;
    m_trailingStopPoints = trailingStopPoints;
    m_trailingStopStart = trailingStopStart;
    m_useBreakEven = useBreakEven;
    m_breakEvenPoints = breakEvenPoints;
    
    // Initialize new parameters with default values
    m_riskModel = RISK_FIXED_PERCENT;
    m_maxDrawdownPercent = 20.0;
    m_riskRewardRatio = 1.5;
    m_useATRForSL = false;
    m_atrPeriod = 14;
    m_atrMultiplier = 2.0;
    m_partialClose = false;
    m_partialClosePercent = 50.0;
    m_partialCloseProfit = 100;
    
    // Initialize trade object
    m_trade = new CTrade();
    
    Print("Risk Module initialized with risk percent: ", riskPercent, "%");
}

//+------------------------------------------------------------------+
//|                    Destructor                                    |
//+------------------------------------------------------------------+
CAK47RiskModule::~CAK47RiskModule()
{
    // Clean up resources
    delete m_trade;
    
    Print("Risk Module destroyed");
}

//+------------------------------------------------------------------+
//|                 Get Account Balance                             |
//+------------------------------------------------------------------+
double CAK47RiskModule::GetAccountBalance()
{
    return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//|                 Calculate Risk Amount                           |
//+------------------------------------------------------------------+
double CAK47RiskModule::CalculateRiskAmount()
{
    return GetAccountBalance() * (m_riskPercent / 100.0);
}

//+------------------------------------------------------------------+
//|                 Get Point Value                                 |
//+------------------------------------------------------------------+
double CAK47RiskModule::GetPointValue()
{
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    if(tickSize <= 0 || point <= 0)
        return 0;
        
    return tickValue * (point / tickSize);
}

//+------------------------------------------------------------------+
//|                 Calculate Lot Size based on Risk                |
//+------------------------------------------------------------------+
double CAK47RiskModule::CalculateLotSize(int stopLossPoints)
{
    // If using fixed lot size, return that
    if(m_useFixedLotSize)
        return m_fixedLotSize;
    
    // If we're already at max drawdown, return minimum lot size
    if(!CheckMaxDrawdown())
        return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    
    // Calculate stop loss points
    int slPoints = (stopLossPoints > 0) ? stopLossPoints : m_stopLossPoints;
    
    // If using ATR for stop loss
    if(m_useATRForSL)
    {
        double atr = CalculateATR(m_atrPeriod);
        slPoints = (int)(atr * m_atrMultiplier / _Point);
        
        // Ensure minimum stop loss
        if(slPoints < 10) slPoints = 10;
    }
    
    double lotSize = 0;
    
    // Choose lot size calculation based on risk model
    switch(m_riskModel)
    {
        case RISK_FIXED_PERCENT:
            {
                // Calculate based on risk percent
                double riskAmount = CalculateRiskAmount();
                double pointValue = GetPointValue();
                
                if(pointValue <= 0)
                {
                    Print("Error: Could not calculate point value");
                    return m_fixedLotSize; // Fallback to fixed lot size
                }
                
                lotSize = riskAmount / (slPoints * pointValue);
            }
            break;
            
        case RISK_KELLY_CRITERION:
            {
                // Get win rate and win/loss ratio
                double winRate = GetWinRate();
                double avgWin = 200; // Example pips, replace with actual calculation
                double avgLoss = 150; // Example pips, replace with actual calculation
                double winLossRatio = avgWin / avgLoss;
                
                // Calculate Kelly percentage
                double kellyPercent = ApplyKellyCriterion(winRate, winLossRatio);
                
                // Apply Kelly percentage to account
                double riskAmount = GetAccountBalance() * kellyPercent;
                double pointValue = GetPointValue();
                
                lotSize = riskAmount / (slPoints * pointValue);
            }
            break;
            
        case RISK_VOLATILITY_BASED:
            {
                // Get current ATR
                double atr = CalculateATR(m_atrPeriod);
                
                // Calculate volatility-adjusted lot size
                lotSize = CalculateVolatilityBasedLotSize(atr);
            }
            break;
            
        case RISK_MARTINGALE:
            {
                // WARNING: Martingale can be very dangerous!
                // Implement only if you understand the risks
                
                // Get last trade result
                // If last trade was a loss, double position size
                // If last trade was a win, revert to base size
                
                // This is just a placeholder implementation
                lotSize = CalculateRiskAmount() / (slPoints * GetPointValue());
            }
            break;
            
        case RISK_ANTI_MARTINGALE:
            {
                // Anti-martingale: increase size after wins, decrease after losses
                // For simplicity, we'll use a base calculation here
                lotSize = CalculateRiskAmount() / (slPoints * GetPointValue());
            }
            break;
            
        default:
            lotSize = CalculateRiskAmount() / (slPoints * GetPointValue());
            break;
    }
    
    // Round to valid lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Ensure we have valid values
    if(minLot <= 0) minLot = 0.01;
    if(maxLot <= 0) maxLot = 100.0;
    if(lotStep <= 0) lotStep = 0.01;
    
    // Round to nearest valid lot size
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    // Ensure lot size is within valid range
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    
    return lotSize;
}

//+------------------------------------------------------------------+
//|                 Modify Position (SL/TP)                         |
//+------------------------------------------------------------------+
bool CAK47RiskModule::ModifyPosition(ulong ticket, double newSL, double newTP)
{
    m_trade.PositionModify(ticket, newSL, newTP);
    
    if(m_trade.ResultRetcode() != TRADE_RETCODE_DONE)
    {
        Print("Error modifying position: ", m_trade.ResultRetcodeDescription());
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//|                 Manage Trailing Stop                            |
//+------------------------------------------------------------------+
bool CAK47RiskModule::ManageTrailingStop(ulong ticket, int posType, double openPrice, double currentSL)
{
    if(!m_useTrailingStop) return false;
    
    // Get current price
    MqlTick lastTick;
    SymbolInfoTick(_Symbol, lastTick);
    
    // Determine if position is in profit enough to start trailing
    bool inProfitEnough = false;
    double newSL = 0;
    
    // For buy positions
    if(posType == POSITION_TYPE_BUY)
    {
        // Check if price has moved enough to start trailing
        inProfitEnough = (lastTick.bid - openPrice) >= m_trailingStopStart * _Point;
        
        if(inProfitEnough)
        {
            // Calculate new stop loss level
            newSL = lastTick.bid - m_trailingStopPoints * _Point;
            
            // Only modify if new SL is higher than current SL
            if(newSL > currentSL)
            {
                return ModifyPosition(ticket, newSL, 0); // 0 means don't change TP
            }
        }
    }
    // For sell positions
    else if(posType == POSITION_TYPE_SELL)
    {
        // Check if price has moved enough to start trailing
        inProfitEnough = (openPrice - lastTick.ask) >= m_trailingStopStart * _Point;
        
        if(inProfitEnough)
        {
            // Calculate new stop loss level
            newSL = lastTick.ask + m_trailingStopPoints * _Point;
            
            // Only modify if new SL is lower than current SL or current SL is zero
            if(currentSL == 0 || newSL < currentSL)
            {
                return ModifyPosition(ticket, newSL, 0); // 0 means don't change TP
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//|                 Manage Break Even                               |
//+------------------------------------------------------------------+
bool CAK47RiskModule::ManageBreakEven(ulong ticket, int posType, double openPrice, double currentSL)
{
    if(!m_useBreakEven) return false;
    
    // Get current price
    MqlTick lastTick;
    SymbolInfoTick(_Symbol, lastTick);
    
    // For buy positions
    if(posType == POSITION_TYPE_BUY)
    {
        // Check if price has moved enough to set break even
        if((lastTick.bid - openPrice) >= m_breakEvenPoints * _Point)
        {
            // Only modify if break even level is higher than current SL
            if(openPrice > currentSL)
            {
                return ModifyPosition(ticket, openPrice, 0); // Set SL to entry
            }
        }
    }
    // For sell positions
    else if(posType == POSITION_TYPE_SELL)
    {
        // Check if price has moved enough to set break even
        if((openPrice - lastTick.ask) >= m_breakEvenPoints * _Point)
        {
            // Only modify if break even level is lower than current SL or current SL is zero
            if(currentSL == 0 || openPrice < currentSL)
            {
                return ModifyPosition(ticket, openPrice, 0); // Set SL to entry
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//|                 Get Risk Statistics                             |
//+------------------------------------------------------------------+
string CAK47RiskModule::GetRiskStats()
{
    string stats = "";
    stats += "Risk Management Statistics\n";
    stats += "Risk Percent: " + DoubleToString(m_riskPercent, 2) + "%\n";
    stats += "Account Balance: " + DoubleToString(GetAccountBalance(), 2) + "\n";
    stats += "Max Risk Amount: " + DoubleToString(CalculateRiskAmount(), 2) + "\n";
    stats += "Current Drawdown: " + DoubleToString(GetCurrentDrawdownPercent(), 2) + "%\n";
    stats += "Max Allowed Drawdown: " + DoubleToString(m_maxDrawdownPercent, 2) + "%\n";
    
    // Display different information based on risk model
    string riskModelName = "";
    switch(m_riskModel)
    {
        case RISK_FIXED_PERCENT: riskModelName = "Fixed Percent"; break;
        case RISK_KELLY_CRITERION: riskModelName = "Kelly Criterion"; break;
        case RISK_VOLATILITY_BASED: riskModelName = "Volatility Based"; break;
        case RISK_MARTINGALE: riskModelName = "Martingale"; break;
        case RISK_ANTI_MARTINGALE: riskModelName = "Anti-Martingale"; break;
        default: riskModelName = "Unknown";
    }
    
    stats += "Risk Model: " + riskModelName + "\n";
    
    if(m_useFixedLotSize)
    {
        stats += "Using Fixed Lot Size: " + DoubleToString(m_fixedLotSize, 2) + "\n";
    }
    else
    {
        stats += "Dynamic Lot Sizing: Enabled\n";
        stats += "Calculated Lot Size: " + DoubleToString(CalculateLotSize(m_stopLossPoints), 2) + "\n";
    }
    
    if(m_useATRForSL)
    {
        double atr = CalculateATR(m_atrPeriod);
        stats += "ATR-based SL: Enabled, ATR(" + IntegerToString(m_atrPeriod) + "): " + DoubleToString(atr, _Digits) + "\n";
        stats += "ATR Multiplier: " + DoubleToString(m_atrMultiplier, 1) + " (SL: ~" + IntegerToString((int)(atr * m_atrMultiplier / _Point)) + " points)\n";
    }
    else
    {
        stats += "Stop Loss: " + IntegerToString(m_stopLossPoints) + " points\n";
    }
    
    stats += "Take Profit: " + IntegerToString(m_takeProfitPoints) + " points\n";
    stats += "Risk:Reward Ratio: 1:" + DoubleToString(m_riskRewardRatio, 1) + "\n";
    
    if(m_partialClose)
    {
        stats += "Partial Close: Enabled, " + DoubleToString(m_partialClosePercent, 0) + "% at " + DoubleToString(m_partialCloseProfit, 0) + " points profit\n";
    }
    
    if(m_useTrailingStop)
    {
        stats += "Trailing Stop: Enabled, " + IntegerToString(m_trailingStopPoints) + " points, activates at " + IntegerToString(m_trailingStopStart) + " points profit\n";
    }
    
    if(m_useBreakEven)
    {
        stats += "Break Even: Enabled, activates at " + IntegerToString(m_breakEvenPoints) + " points profit\n";
    }
    
    // Add total risk exposure
    double exposure = GetTotalRiskExposure();
    double exposurePercent = (exposure / GetAccountBalance()) * 100.0;
    stats += "Current Risk Exposure: " + DoubleToString(exposure, 2) + " (" + DoubleToString(exposurePercent, 2) + "% of balance)\n";
    
    return stats;
}

//+------------------------------------------------------------------+
//|                 Get Maximum Loss Amount                         |
//+------------------------------------------------------------------+
double CAK47RiskModule::GetMaxLossAmount()
{
    return CalculateRiskAmount();
}

//+------------------------------------------------------------------+
//|                 Calculate ATR                                    |
//+------------------------------------------------------------------+
double CAK47RiskModule::CalculateATR(int period)
{
    double atr[];
    int handle = iATR(_Symbol, PERIOD_CURRENT, period);
    
    if(handle == INVALID_HANDLE)
    {
        Print("Error creating ATR indicator: ", GetLastError());
        return 0;
    }
    
    if(CopyBuffer(handle, 0, 0, 1, atr) <= 0)
    {
        Print("Error copying ATR data: ", GetLastError());
        IndicatorRelease(handle);
        return 0;
    }
    
    IndicatorRelease(handle);
    return atr[0];
}

//+------------------------------------------------------------------+
//|                 Apply Kelly Criterion                           |
//+------------------------------------------------------------------+
double CAK47RiskModule::ApplyKellyCriterion(double winRate, double winLossRatio)
{
    // Kelly formula: K% = W - [(1-W)/R]
    // Where: W = Win rate, R = Win/Loss ratio
    
    if(winLossRatio <= 0 || winRate <= 0)
        return 0.01; // Default to 1% if parameters are invalid
        
    double kellyPercent = winRate - ((1 - winRate) / winLossRatio);
    
    // Limit the Kelly percentage to avoid over-betting
    kellyPercent = MathMin(kellyPercent, 0.25); // Maximum 25%
    kellyPercent = MathMax(kellyPercent, 0.01); // Minimum 1%
    
    return kellyPercent;
}

//+------------------------------------------------------------------+
//|                 Calculate Volatility-Based Lot Size             |
//+------------------------------------------------------------------+
double CAK47RiskModule::CalculateVolatilityBasedLotSize(double atr)
{
    if(atr <= 0) return m_fixedLotSize;
    
    // Base lot size on ATR relative to price
    MqlTick lastTick;
    SymbolInfoTick(_Symbol, lastTick);
    double currentPrice = (lastTick.bid + lastTick.ask) / 2;
    
    // Normalize ATR as percentage of price
    double atrPercent = (atr / currentPrice) * 100;
    
    // Inverse relationship - higher volatility = lower position size
    double volatilityFactor = 5.0 / atrPercent; // 5% is the reference volatility
    
    // Apply to risk-based lot size
    double baseLotSize = CalculateLotSize(m_stopLossPoints);
    double adjustedLotSize = baseLotSize * volatilityFactor;
    
    // Apply bounds
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Ensure we have valid values
    if(minLot <= 0) minLot = 0.01;
    if(maxLot <= 0) maxLot = 100.0;
    if(lotStep <= 0) lotStep = 0.01;
    
    // Round to nearest valid lot size
    adjustedLotSize = MathFloor(adjustedLotSize / lotStep) * lotStep;
    adjustedLotSize = MathMax(minLot, MathMin(maxLot, adjustedLotSize));
    
    return adjustedLotSize;
}

//+------------------------------------------------------------------+
//|                 Check Maximum Drawdown                          |
//+------------------------------------------------------------------+
bool CAK47RiskModule::CheckMaxDrawdown()
{
    double currentDrawdown = GetCurrentDrawdownPercent();
    return (currentDrawdown <= m_maxDrawdownPercent);
}

//+------------------------------------------------------------------+
//|                 Get Current Drawdown Percentage                 |
//+------------------------------------------------------------------+
double CAK47RiskModule::GetCurrentDrawdownPercent()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    if(balance <= 0) return 0;
    
    return ((balance - equity) / balance) * 100.0;
}

//+------------------------------------------------------------------+
//|                 Get Total Risk Exposure                         |
//+------------------------------------------------------------------+
double CAK47RiskModule::GetTotalRiskExposure()
{
    double totalRisk = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        if(symbol != _Symbol) continue;
        
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double posLots = PositionGetDouble(POSITION_VOLUME);
        int posType = (int)PositionGetInteger(POSITION_TYPE);
        
        // Skip positions without stop loss
        if(currentSL == 0) continue;
        
        // Calculate risk for this position
        double riskPoints;
        if(posType == POSITION_TYPE_BUY)
            riskPoints = (openPrice - currentSL) / _Point;
        else
            riskPoints = (currentSL - openPrice) / _Point;
            
        // Convert to monetary risk
        double pointValue = GetPointValue();
        double positionRisk = riskPoints * pointValue * posLots;
        
        totalRisk += positionRisk;
    }
    
    return totalRisk;
}

//+------------------------------------------------------------------+
//|                 Apply Partial Close                             |
//+------------------------------------------------------------------+
bool CAK47RiskModule::ApplyPartialClose(ulong ticket, int posType, double openPrice, double currentProfit)
{
    if(!m_partialClose) return false;
    
    // Check if profit has reached partial close level
    if(currentProfit < m_partialCloseProfit * _Point) return false;
    
    // Get position volume
    if(!PositionSelectByTicket(ticket)) return false;
    
    double volume = PositionGetDouble(POSITION_VOLUME);
    double closeVolume = volume * (m_partialClosePercent / 100.0);
    
    // Ensure closeVolume is valid
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(closeVolume < minLot) return false;
    
    // Round to valid lot size
    closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
    
    // Close part of the position
    m_trade.PositionClosePartial(ticket, closeVolume);
    
    if(m_trade.ResultRetcode() != TRADE_RETCODE_DONE)
    {
        Print("Error partially closing position: ", m_trade.ResultRetcodeDescription());
        return false;
    }
    
    Print("Position ", ticket, " partially closed. Volume: ", closeVolume);
    return true;
}

//+------------------------------------------------------------------+
//|                 Set ATR Parameters                              |
//+------------------------------------------------------------------+
void CAK47RiskModule::SetATRParameters(bool useATR, int period, double multiplier)
{
    m_useATRForSL = useATR;
    m_atrPeriod = period;
    m_atrMultiplier = multiplier;
}

//+------------------------------------------------------------------+
//|                 Enable Partial Close                            |
//+------------------------------------------------------------------+
void CAK47RiskModule::EnablePartialClose(bool enable, double percent, double profitPoints)
{
    m_partialClose = enable;
    m_partialClosePercent = percent;
    m_partialCloseProfit = profitPoints;
}

//+------------------------------------------------------------------+
//|                 Calculate Dynamic Take Profit                   |
//+------------------------------------------------------------------+
double CAK47RiskModule::CalculateDynamicTakeProfit(int stopLossPoints)
{
    // Use risk:reward ratio to calculate TP
    int slPoints = (stopLossPoints > 0) ? stopLossPoints : m_stopLossPoints;
    return slPoints * m_riskRewardRatio;
}

//+------------------------------------------------------------------+
//|                 Get Win Rate                                    |
//+------------------------------------------------------------------+
double CAK47RiskModule::GetWinRate()
{
    // This would require historical trade data analysis
    // For simplicity, we return a default value
    return 0.55; // 55% win rate assumption
    
    // In a real implementation, you would calculate this from trade history
    // using the CTrade history functions or a custom tracking mechanism
}

//+------------------------------------------------------------------+
//|                 Use Timed Exit                                  |
//+------------------------------------------------------------------+
bool CAK47RiskModule::UseTimedExit(ulong ticket, datetime openTime, int maxMinutes)
{
    datetime currentTime = TimeCurrent();
    int elapsedMinutes = (int)(currentTime - openTime) / 60;
    
    if(elapsedMinutes >= maxMinutes)
    {
        // Close position due to time limit
        m_trade.PositionClose(ticket);
        
        if(m_trade.ResultRetcode() != TRADE_RETCODE_DONE)
        {
            Print("Error closing timed position: ", m_trade.ResultRetcodeDescription());
            return false;
        }
        
        Print("Position ", ticket, " closed due to time limit (", maxMinutes, " minutes)");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//|                 Manage All Positions                            |
//+------------------------------------------------------------------+
bool CAK47RiskModule::ManageAllPositions()
{
    bool actionTaken = false;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(!PositionSelectByTicket(ticket)) continue;
        
        // Only manage positions for our symbol
        string symbol = PositionGetString(POSITION_SYMBOL);
        if(symbol != _Symbol) continue;
        
        // Get position details
        int posType = (int)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
        
        // Get current price
        MqlTick lastTick;
        SymbolInfoTick(_Symbol, lastTick);
        double currentPrice = (posType == POSITION_TYPE_BUY) ? lastTick.bid : lastTick.ask;
        
        // Calculate current profit in points
        double currentProfitPoints;
        if(posType == POSITION_TYPE_BUY)
            currentProfitPoints = (currentPrice - openPrice) / _Point;
        else
            currentProfitPoints = (openPrice - currentPrice) / _Point;
        
        // Apply trailing stop
        if(ManageTrailingStop(ticket, posType, openPrice, currentSL))
            actionTaken = true;
        
        // Apply break even
        if(ManageBreakEven(ticket, posType, openPrice, currentSL))
            actionTaken = true;
        
        // Apply partial close
        if(ApplyPartialClose(ticket, posType, openPrice, currentProfitPoints))
            actionTaken = true;
        
        // Use timed exit (example: close after 120 minutes)
        if(UseTimedExit(ticket, openTime, 120))
            actionTaken = true;
    }
    
    return actionTaken;
}