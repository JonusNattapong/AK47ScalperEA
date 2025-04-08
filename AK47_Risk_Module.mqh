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
    
    CTrade*         m_trade;                // Trade object for order management
    
    // Private methods
    double          GetAccountBalance();
    double          CalculateRiskAmount();
    double          GetPointValue();
    bool            ModifyPosition(ulong ticket, double newSL, double newTP);
    
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
    
    // Calculate based on risk percent
    double riskAmount = CalculateRiskAmount();
    
    // If stop loss is 0, use default stop loss points
    int slPoints = (stopLossPoints > 0) ? stopLossPoints : m_stopLossPoints;
    
    // Safety check
    if(slPoints <= 0) slPoints = 100; // Default to 100 points if not specified
    
    // Calculate point value
    double pointValue = GetPointValue();
    
    if(pointValue <= 0)
    {
        Print("Error: Could not calculate point value");
        return m_fixedLotSize; // Fallback to fixed lot size
    }
    
    // Calculate lot size
    double calculatedLotSize = riskAmount / (slPoints * pointValue);
    
    // Round to valid lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Ensure we have valid values
    if(minLot <= 0) minLot = 0.01;
    if(maxLot <= 0) maxLot = 100.0;
    if(lotStep <= 0) lotStep = 0.01;
    
    // Round to nearest valid lot size
    calculatedLotSize = MathFloor(calculatedLotSize / lotStep) * lotStep;
    
    // Ensure lot size is within valid range
    calculatedLotSize = MathMax(minLot, MathMin(maxLot, calculatedLotSize));
    
    return calculatedLotSize;
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
    
    if(m_useFixedLotSize)
    {
        stats += "Using Fixed Lot Size: " + DoubleToString(m_fixedLotSize, 2) + "\n";
    }
    else
    {
        stats += "Dynamic Lot Sizing: Enabled\n";
        stats += "Calculated Lot Size: " + DoubleToString(CalculateLotSize(m_stopLossPoints), 2) + "\n";
    }
    
    stats += "Stop Loss: " + IntegerToString(m_stopLossPoints) + " points\n";
    stats += "Take Profit: " + IntegerToString(m_takeProfitPoints) + " points\n";
    
    if(m_useTrailingStop)
    {
        stats += "Trailing Stop: Enabled, " + IntegerToString(m_trailingStopPoints) + " points, activates at " + IntegerToString(m_trailingStopStart) + " points profit\n";
    }
    
    if(m_useBreakEven)
    {
        stats += "Break Even: Enabled, activates at " + IntegerToString(m_breakEvenPoints) + " points profit\n";
    }
    
    return stats;
}

//+------------------------------------------------------------------+
//|                 Get Maximum Loss Amount                         |
//+------------------------------------------------------------------+
double CAK47RiskModule::GetMaxLossAmount()
{
    return CalculateRiskAmount();
}