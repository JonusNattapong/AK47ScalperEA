//+------------------------------------------------------------------+
//|                                         AK47_SMC_Module.mqh    |
//|                        Copyright 2025, JonusNattapong                 |
//|                                     https://github.com/JonusNattapong  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, JonusNattapong"
#property link      "https://github.com/JonusNattapong"
#property version   "1.00"

// Include necessary files
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayDouble.mqh>

// Structure for storing order blocks
struct SOrderBlock
{
    datetime time;        // Time of the order block formation
    double   high;        // High price of the order block
    double   low;         // Low price of the order block
    bool     isBullish;   // Bullish or bearish order block
    bool     isActive;    // Is the order block still active
    double   strength;    // Strength of the order block (0-100)
};

// Structure for storing market structure points
struct SStructurePoint
{
    datetime time;        // Time of the structure point
    double   price;       // Price level
    bool     isHigh;      // Is it a higher high/lower high (true) or higher low/lower low (false)
    bool     isBreakup;   // Is it a breakup (true) or breakdown (false)
};

// SMC Analysis Module
class CAK47SMCModule
{
private:
    int             m_orderBlockLookback;      // Number of bars to look back for order blocks
    bool            m_useSDZones;              // Use supply/demand zones
    bool            m_useBreakOfStructure;     // Use break of structure
    
    SOrderBlock     m_orderBlocks[];           // Array of order blocks
    SStructurePoint m_structurePoints[];       // Array of structure points
    
    double          m_supplyZones[];           // Array of supply zone prices
    double          m_demandZones[];           // Array of demand zone prices
    
    // Private methods
    void            IdentifyOrderBlocks();
    void            IdentifyStructurePoints();
    void            IdentifySupplyDemandZones();
    bool            IsKeyReversal(int barIndex);
    
public:
                    CAK47SMCModule(int orderBlockLookback, bool useSDZones, bool useBreakOfStructure);
                   ~CAK47SMCModule();
    
    int             GetSignal();                // Get current SMC signal (-1, 0, 1)
    void            UpdateAnalysis();           // Update SMC analysis
    double          GetNearestSupportLevel();   // Get nearest support level
    double          GetNearestResistanceLevel();// Get nearest resistance level
    string          GetSMCStats();              // Get SMC statistics as string
    
    // Drawing methods (for visualization)
    void            DrawOrderBlocks();
    void            DrawStructurePoints();
    void            DrawSupplyDemandZones();
};

//+------------------------------------------------------------------+
//|                    Constructor                                   |
//+------------------------------------------------------------------+
CAK47SMCModule::CAK47SMCModule(int orderBlockLookback, bool useSDZones, bool useBreakOfStructure)
{
    m_orderBlockLookback = orderBlockLookback;
    m_useSDZones = useSDZones;
    m_useBreakOfStructure = useBreakOfStructure;
    
    // Initialize arrays
    ArrayResize(m_orderBlocks, 0);
    ArrayResize(m_structurePoints, 0);
    ArrayResize(m_supplyZones, 0);
    ArrayResize(m_demandZones, 0);
    
    // Perform initial analysis
    UpdateAnalysis();
    
    Print("SMC Module initialized with orderBlockLookback: ", orderBlockLookback);
}

//+------------------------------------------------------------------+
//|                    Destructor                                    |
//+------------------------------------------------------------------+
CAK47SMCModule::~CAK47SMCModule()
{
    // Clean up resources
    ArrayFree(m_orderBlocks);
    ArrayFree(m_structurePoints);
    ArrayFree(m_supplyZones);
    ArrayFree(m_demandZones);
    
    // Remove drawings
    ObjectsDeleteAll(0, "AK47_SMC_");
    
    Print("SMC Module destroyed");
}

//+------------------------------------------------------------------+
//|                    Update SMC Analysis                           |
//+------------------------------------------------------------------+
void CAK47SMCModule::UpdateAnalysis()
{
    // Clear previous analysis
    ArrayFree(m_orderBlocks);
    ArrayFree(m_structurePoints);
    ArrayFree(m_supplyZones);
    ArrayFree(m_demandZones);
    
    // Identify order blocks
    IdentifyOrderBlocks();
    
    // Identify market structure points
    IdentifyStructurePoints();
    
    // Identify supply/demand zones if enabled
    if(m_useSDZones)
    {
        IdentifySupplyDemandZones();
    }
    
    // Draw elements if needed (for visual representation)
    DrawOrderBlocks();
    DrawStructurePoints();
    if(m_useSDZones) DrawSupplyDemandZones();
}

//+------------------------------------------------------------------+
//|                    Identify Order Blocks                         |
//+------------------------------------------------------------------+
void CAK47SMCModule::IdentifyOrderBlocks()
{
    int lookback = MathMin(m_orderBlockLookback, Bars(_Symbol, PERIOD_M1) - 1);
    
    // Initialize the order blocks array
    int initialSize = 10; // Initial size estimate
    ArrayResize(m_orderBlocks, initialSize);
    int blockCount = 0;
    
    // Loop through recent bars to identify order blocks
    for(int i = 1; i < lookback - 2; i++)
    {
        // Get candle data
        double high1 = iHigh(_Symbol, PERIOD_M1, i);
        double low1 = iLow(_Symbol, PERIOD_M1, i);
        double open1 = iOpen(_Symbol, PERIOD_M1, i);
        double close1 = iClose(_Symbol, PERIOD_M1, i);
        
        double high2 = iHigh(_Symbol, PERIOD_M1, i+1);
        double low2 = iLow(_Symbol, PERIOD_M1, i+1);
        double open2 = iOpen(_Symbol, PERIOD_M1, i+1);
        double close2 = iClose(_Symbol, PERIOD_M1, i+1);
        
        double high3 = iHigh(_Symbol, PERIOD_M1, i+2);
        double low3 = iLow(_Symbol, PERIOD_M1, i+2);
        
        // Bullish Order Block: Bearish candle followed by a strong bullish move
        if(close1 < open1 && close2 > open2 && close2 > high1 && open2 > close1)
        {
            // Ensure we have enough space in the array
            if(blockCount >= ArraySize(m_orderBlocks))
                ArrayResize(m_orderBlocks, ArraySize(m_orderBlocks) + 10);
                
            // Add the order block
            m_orderBlocks[blockCount].time = iTime(_Symbol, PERIOD_M1, i);
            m_orderBlocks[blockCount].high = high1;
            m_orderBlocks[blockCount].low = low1;
            m_orderBlocks[blockCount].isBullish = true;
            m_orderBlocks[blockCount].isActive = true;
            
            // Calculate strength based on subsequent price movement
            double moveSize = MathAbs(high2 - low1);
            double relativeSize = moveSize / (high1 - low1);
            m_orderBlocks[blockCount].strength = MathMin(relativeSize * 50, 100);
            
            blockCount++;
        }
        
        // Bearish Order Block: Bullish candle followed by a strong bearish move
        if(close1 > open1 && close2 < open2 && close2 < low1 && open2 < close1)
        {
            // Ensure we have enough space in the array
            if(blockCount >= ArraySize(m_orderBlocks))
                ArrayResize(m_orderBlocks, ArraySize(m_orderBlocks) + 10);
                
            // Add the order block
            m_orderBlocks[blockCount].time = iTime(_Symbol, PERIOD_M1, i);
            m_orderBlocks[blockCount].high = high1;
            m_orderBlocks[blockCount].low = low1;
            m_orderBlocks[blockCount].isBullish = false;
            m_orderBlocks[blockCount].isActive = true;
            
            // Calculate strength based on subsequent price movement
            double moveSize = MathAbs(low2 - high1);
            double relativeSize = moveSize / (high1 - low1);
            m_orderBlocks[blockCount].strength = MathMin(relativeSize * 50, 100);
            
            blockCount++;
        }
    }
    
    // Resize array to actual number of blocks found
    ArrayResize(m_orderBlocks, blockCount);
    
    // Check for order blocks that have been mitigated
    MqlTick lastTick;
    SymbolInfoTick(_Symbol, lastTick);
    double currentPrice = (lastTick.bid + lastTick.ask) / 2;
    
    for(int i = 0; i < blockCount; i++)
    {
        if(m_orderBlocks[i].isBullish && currentPrice < m_orderBlocks[i].low)
        {
            m_orderBlocks[i].isActive = false;
        }
        else if(!m_orderBlocks[i].isBullish && currentPrice > m_orderBlocks[i].high)
        {
            m_orderBlocks[i].isActive = false;
        }
    }
}

//+------------------------------------------------------------------+
//|                Identify Market Structure Points                  |
//+------------------------------------------------------------------+
void CAK47SMCModule::IdentifyStructurePoints()
{
    if(!m_useBreakOfStructure) return;
    
    int lookback = MathMin(m_orderBlockLookback, Bars(_Symbol, PERIOD_M1) - 2);
    
    // Initialize structure points array
    int initialSize = 10; // Initial size estimate
    ArrayResize(m_structurePoints, initialSize);
    int pointCount = 0;
    
    // Variables to track last swing high/low
    double lastSwingHigh = 0;
    double lastSwingLow = DBL_MAX;
    int lastSwingHighIndex = -1;
    int lastSwingLowIndex = -1;
    
    // Loop through recent bars to identify swing highs/lows
    for(int i = 2; i < lookback - 2; i++)
    {
        double high1 = iHigh(_Symbol, PERIOD_M1, i);
        double low1 = iLow(_Symbol, PERIOD_M1, i);
        double high0 = iHigh(_Symbol, PERIOD_M1, i-1);
        double low0 = iLow(_Symbol, PERIOD_M1, i-1);
        double high2 = iHigh(_Symbol, PERIOD_M1, i+1);
        double low2 = iLow(_Symbol, PERIOD_M1, i+1);
        
        // Identify swing high
        if(high1 > high0 && high1 > high2)
        {
            // Ensure we have enough space in the array
            if(pointCount >= ArraySize(m_structurePoints))
                ArrayResize(m_structurePoints, ArraySize(m_structurePoints) + 10);
                
            // Add the structure point
            m_structurePoints[pointCount].time = iTime(_Symbol, PERIOD_M1, i);
            m_structurePoints[pointCount].price = high1;
            m_structurePoints[pointCount].isHigh = true;
            m_structurePoints[pointCount].isBreakup = (high1 > lastSwingHigh);
            
            // Update swing tracking
            lastSwingHigh = high1;
            lastSwingHighIndex = i;
            
            pointCount++;
        }
        
        // Identify swing low
        if(low1 < low0 && low1 < low2)
        {
            // Ensure we have enough space in the array
            if(pointCount >= ArraySize(m_structurePoints))
                ArrayResize(m_structurePoints, ArraySize(m_structurePoints) + 10);
                
            // Add the structure point
            m_structurePoints[pointCount].time = iTime(_Symbol, PERIOD_M1, i);
            m_structurePoints[pointCount].price = low1;
            m_structurePoints[pointCount].isHigh = false;
            m_structurePoints[pointCount].isBreakup = (low1 > lastSwingLow);
            
            // Update swing tracking
            lastSwingLow = low1;
            lastSwingLowIndex = i;
            
            pointCount++;
        }
    }
    
    // Resize array to actual number of points found
    ArrayResize(m_structurePoints, pointCount);
}

//+------------------------------------------------------------------+
//|                Identify Supply/Demand Zones                      |
//+------------------------------------------------------------------+
void CAK47SMCModule::IdentifySupplyDemandZones()
{
    if(!m_useSDZones) return;
    
    int lookback = MathMin(m_orderBlockLookback * 2, Bars(_Symbol, PERIOD_M1) - 1);
    
    // Arrays to store potential zones
    double potentialSupplyZones[];
    double potentialDemandZones[];
    
    int supplyCount = 0;
    int demandCount = 0;
    
    // Look for reversal patterns that indicate supply/demand zones
    for(int i = 2; i < lookback - 2; i++)
    {
        if(IsKeyReversal(i))
        {
            double high = iHigh(_Symbol, PERIOD_M1, i);
            double low = iLow(_Symbol, PERIOD_M1, i);
            double close = iClose(_Symbol, PERIOD_M1, i);
            double open = iOpen(_Symbol, PERIOD_M1, i);
            
            // For supply zones, we look for price rejection from above
            if(close < open && high > high, i-1) && high > high, i+1))
            {
                ArrayResize(potentialSupplyZones, supplyCount + 1);
                potentialSupplyZones[supplyCount] = high;
                supplyCount++;
            }
            
            // For demand zones, we look for price rejection from below
            if(close > open && low < low, i-1) && low < low, i+1))
            {
                ArrayResize(potentialDemandZones, demandCount + 1);
                potentialDemandZones[demandCount] = low;
                demandCount++;
            }
        }
    }
    
    // Find the most significant zones by clustering similar price levels
    if(supplyCount > 0)
    {
        // Sort supply zones (descending order)
        ArraySort(potentialSupplyZones, WHOLE_ARRAY, 0, MODE_DESCEND);
        
        // Cluster similar levels
        double clusterThreshold = iATR(_Symbol, PERIOD_M1, 14) * 0.5; // Half ATR as threshold
        
        ArrayResize(m_supplyZones, 0);
        double lastZone = potentialSupplyZones[0];
        ArrayResize(m_supplyZones, 1);
        m_supplyZones[0] = lastZone;
        
        for(int i = 1; i < supplyCount; i++)
        {
            if(MathAbs(potentialSupplyZones[i] - lastZone) > clusterThreshold)
            {
                ArrayResize(m_supplyZones, ArraySize(m_supplyZones) + 1);
                m_supplyZones[ArraySize(m_supplyZones) - 1] = potentialSupplyZones[i];
                lastZone = potentialSupplyZones[i];
            }
        }
    }
    
    if(demandCount > 0)
    {
        // Sort demand zones (ascending order)
        ArraySort(potentialDemandZones);
        
        // Cluster similar levels
        double clusterThreshold = iATR(_Symbol, PERIOD_M1, 14) * 0.5; // Half ATR as threshold
        
        ArrayResize(m_demandZones, 0);
        double lastZone = potentialDemandZones[0];
        ArrayResize(m_demandZones, 1);
        m_demandZones[0] = lastZone;
        
        for(int i = 1; i < demandCount; i++)
        {
            if(MathAbs(potentialDemandZones[i] - lastZone) > clusterThreshold)
            {
                ArrayResize(m_demandZones, ArraySize(m_demandZones) + 1);
                m_demandZones[ArraySize(m_demandZones) - 1] = potentialDemandZones[i];
                lastZone = potentialDemandZones[i];
            }
        }
    }
}

//+------------------------------------------------------------------+
//|                  Check for Key Reversal Patterns                 |
//+------------------------------------------------------------------+
bool CAK47SMCModule::IsKeyReversal(int barIndex)
{
    double high1 = iHigh(_Symbol, PERIOD_M1, barIndex);
    double low1 = iLow(_Symbol, PERIOD_M1, barIndex);
    double open1 = iOpen(_Symbol, PERIOD_M1, barIndex);
    double close1 = iClose(_Symbol, PERIOD_M1, barIndex);
    
    double high2 = iHigh(_Symbol, PERIOD_M1, barIndex+1);
    double low2 = iLow(_Symbol, PERIOD_M1, barIndex+1);
    double open2 = iOpen(_Symbol, PERIOD_M1, barIndex+1);
    double close2 = iClose(_Symbol, PERIOD_M1, barIndex+1);
    
    double high0 = iHigh(_Symbol, PERIOD_M1, barIndex-1);
    double low0 = iLow(_Symbol, PERIOD_M1, barIndex-1);
    
    // Pin bar or shooting star pattern
    bool pinBar = (MathAbs(open1 - close1) < 0.3 * (high1 - low1)) &&
                 ((high1 - MathMax(open1, close1)) > 2 * MathAbs(open1 - close1) ||
                  (MathMin(open1, close1) - low1) > 2 * MathAbs(open1 - close1));
    
    // Engulfing pattern
    bool bullishEngulfing = (close2 < open2) && (open1 < close2) && (close1 > open2) && (close1 > open1);
    bool bearishEngulfing = (close2 > open2) && (open1 > close2) && (close1 < open2) && (close1 < open1);
    
    // Outside bar
    bool outsideBar = (high1 > high2) && (low1 < low2);
    
    // Key rejection
    bool keyRejection = (high1 > high0 && high1 > high, barIndex+1)) || 
                        (low1 < low0 && low1 < low, barIndex+1));
    
    return pinBar || bullishEngulfing || bearishEngulfing || outsideBar || keyRejection;
}

//+------------------------------------------------------------------+
//|                  Get Overall SMC Signal                         |
//+------------------------------------------------------------------+
int CAK47SMCModule::GetSignal()
{
    MqlTick lastTick;
    SymbolInfoTick(_Symbol, lastTick);
    double currentPrice = (lastTick.bid + lastTick.ask) / 2;
    
    // Count active bullish and bearish order blocks
    int bullishBlocks = 0;
    int bearishBlocks = 0;
    
    for(int i = 0; i < ArraySize(m_orderBlocks); i++)
    {
        if(m_orderBlocks[i].isActive)
        {
            if(m_orderBlocks[i].isBullish) bullishBlocks++;
            else bearishBlocks++;
        }
    }
    
    // Analyze structure points if enabled
    int structureSignal = 0;
    
    if(m_useBreakOfStructure && ArraySize(m_structurePoints) >= 2)
    {
        // Check the latest two structure points
        if(m_structurePoints[ArraySize(m_structurePoints)-1].isBreakup && 
           m_structurePoints[ArraySize(m_structurePoints)-2].isBreakup)
        {
            structureSignal = 1; // Uptrend structure
        }
        else if(!m_structurePoints[ArraySize(m_structurePoints)-1].isBreakup && 
                !m_structurePoints[ArraySize(m_structurePoints)-2].isBreakup)
        {
            structureSignal = -1; // Downtrend structure
        }
    }
    
    // Analyze supply/demand zones if enabled
    int zoneSignal = 0;
    
    if(m_useSDZones)
    {
        // Find nearest zones
        double nearestSupply = DBL_MAX;
        double nearestDemand = 0;
        
        for(int i = 0; i < ArraySize(m_supplyZones); i++)
        {
            if(m_supplyZones[i] > currentPrice && m_supplyZones[i] < nearestSupply)
            {
                nearestSupply = m_supplyZones[i];
            }
        }
        
        for(int i = 0; i < ArraySize(m_demandZones); i++)
        {
            if(m_demandZones[i] < currentPrice && m_demandZones[i] > nearestDemand)
            {
                nearestDemand = m_demandZones[i];
            }
        }
        
        // Calculate distance to nearest zones
        double distToSupply = (nearestSupply != DBL_MAX) ? nearestSupply - currentPrice : DBL_MAX;
        double distToDemand = (nearestDemand != 0) ? currentPrice - nearestDemand : DBL_MAX;
        
        // Determine signal based on proximity
        double atr = iATR(_Symbol, PERIOD_M1, 14);
        
        if(distToSupply < atr && distToSupply < distToDemand)
        {
            zoneSignal = -1; // Near supply zone, bearish
        }
        else if(distToDemand < atr && distToDemand < distToSupply)
        {
            zoneSignal = 1; // Near demand zone, bullish
        }
    }
    
    // Combine all signals for final decision
    int finalSignal = 0;
    int signals = 0;
    
    // Order blocks signal
    if(bullishBlocks > bearishBlocks)
    {
        finalSignal += 1;
        signals++;
    }
    else if(bearishBlocks > bullishBlocks)
    {
        finalSignal -= 1;
        signals++;
    }
    
    // Structure signal
    if(structureSignal != 0)
    {
        finalSignal += structureSignal;
        signals++;
    }
    
    // Zone signal
    if(zoneSignal != 0)
    {
        finalSignal += zoneSignal;
        signals++;
    }
    
    // Average the signals
    if(signals > 0)
    {
        finalSignal = (finalSignal > 0) ? 1 : ((finalSignal < 0) ? -1 : 0);
    }
    
    return finalSignal;
}

//+------------------------------------------------------------------+
//|                  Get Nearest Support Level                       |
//+------------------------------------------------------------------+
double CAK47SMCModule::GetNearestSupportLevel()
{
    MqlTick lastTick;
    SymbolInfoTick(_Symbol, lastTick);
    double currentPrice = (lastTick.bid + lastTick.ask) / 2;
    
    double nearestSupport = 0;
    double minDistance = DBL_MAX;
    
    // Check active bullish order blocks
    for(int i = 0; i < ArraySize(m_orderBlocks); i++)
    {
        if(m_orderBlocks[i].isActive && m_orderBlocks[i].isBullish && m_orderBlocks[i].high < currentPrice)
        {
            double distance = currentPrice - m_orderBlocks[i].high;
            if(distance < minDistance)
            {
                minDistance = distance;
                nearestSupport = m_orderBlocks[i].high;
            }
        }
    }
    
    // Check demand zones
    for(int i = 0; i < ArraySize(m_demandZones); i++)
    {
        if(m_demandZones[i] < currentPrice)
        {
            double distance = currentPrice - m_demandZones[i];
            if(distance < minDistance)
            {
                minDistance = distance;
                nearestSupport = m_demandZones[i];
            }
        }
    }
    
    return nearestSupport;
}

//+------------------------------------------------------------------+
//|                  Get Nearest Resistance Level                    |
//+------------------------------------------------------------------+
double CAK47SMCModule::GetNearestResistanceLevel()
{
    MqlTick lastTick;
    SymbolInfoTick(_Symbol, lastTick);
    double currentPrice = (lastTick.bid + lastTick.ask) / 2;
    
    double nearestResistance = DBL_MAX;
    double minDistance = DBL_MAX;
    
    // Check active bearish order blocks
    for(int i = 0; i < ArraySize(m_orderBlocks); i++)
    {
        if(m_orderBlocks[i].isActive && !m_orderBlocks[i].isBullish && m_orderBlocks[i].low > currentPrice)
        {
            double distance = m_orderBlocks[i].low - currentPrice;
            if(distance < minDistance)
            {
                minDistance = distance;
                nearestResistance = m_orderBlocks[i].low;
            }
        }
    }
    
    // Check supply zones
    for(int i = 0; i < ArraySize(m_supplyZones); i++)
    {
        if(m_supplyZones[i] > currentPrice)
        {
            double distance = m_supplyZones[i] - currentPrice;
            if(distance < minDistance)
            {
                minDistance = distance;
                nearestResistance = m_supplyZones[i];
            }
        }
    }
    
    return nearestResistance;
}

//+------------------------------------------------------------------+
//|                  Get SMC Statistics                              |
//+------------------------------------------------------------------+
string CAK47SMCModule::GetSMCStats()
{
    string stats = "";
    stats += "SMC Analysis Statistics\n";
    stats += "Order Blocks: " + IntegerToString(ArraySize(m_orderBlocks)) + "\n";
    stats += "Structure Points: " + IntegerToString(ArraySize(m_structurePoints)) + "\n";
    stats += "Supply Zones: " + IntegerToString(ArraySize(m_supplyZones)) + "\n";
    stats += "Demand Zones: " + IntegerToString(ArraySize(m_demandZones)) + "\n";
    
    MqlTick lastTick;
    SymbolInfoTick(_Symbol, lastTick);
    double currentPrice = (lastTick.bid + lastTick.ask) / 2;
    
    double nearestSupport = GetNearestSupportLevel();
    double nearestResistance = GetNearestResistanceLevel();
    
    stats += "Nearest Support: " + DoubleToString(nearestSupport, _Digits) + "\n";
    stats += "Nearest Resistance: " + DoubleToString(nearestResistance, _Digits) + "\n";
    stats += "Current SMC Signal: " + IntegerToString(GetSignal()) + "\n";
    
    return stats;
}

//+------------------------------------------------------------------+
//|                  Draw Order Blocks                               |
//+------------------------------------------------------------------+
void CAK47SMCModule::DrawOrderBlocks()
{
    // Remove previous drawings
    ObjectsDeleteAll(0, "AK47_SMC_OB_");
    
    // Draw order blocks
    for(int i = 0; i < ArraySize(m_orderBlocks); i++)
    {
        if(!m_orderBlocks[i].isActive) continue;
        
        string name = "AK47_SMC_OB_" + IntegerToString(i);
        datetime time1 = m_orderBlocks[i].time;
        datetime time2 = TimeCurrent() + 60 * 60; // 1 hour ahead
        
        color blockColor = m_orderBlocks[i].isBullish ? clrGreen : clrRed;
        
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, m_orderBlocks[i].high, time2, m_orderBlocks[i].low);
        ObjectSetInteger(0, name, OBJPROP_COLOR, blockColor);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        
        // Add transparency based on strength
        int transparency = 255 - (int)(m_orderBlocks[i].strength * 2.0);
        if(transparency < 10) transparency = 10;
        if(transparency > 240) transparency = 240;
        
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, blockColor & 0xFFFFFF | (transparency << 24));
    }
}

//+------------------------------------------------------------------+
//|                  Draw Structure Points                          |
//+------------------------------------------------------------------+
void CAK47SMCModule::DrawStructurePoints()
{
    if(!m_useBreakOfStructure) return;
    
    // Remove previous drawings
    ObjectsDeleteAll(0, "AK47_SMC_SP_");
    
    // Draw structure points
    for(int i = 0; i < ArraySize(m_structurePoints); i++)
    {
        string name = "AK47_SMC_SP_" + IntegerToString(i);
        datetime time = m_structurePoints[i].time;
        double price = m_structurePoints[i].price;
        
        color pointColor = m_structurePoints[i].isHigh ? 
                          (m_structurePoints[i].isBreakup ? clrLime : clrGreen) : 
                          (m_structurePoints[i].isBreakup ? clrMagenta : clrRed);
        
        ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
        ObjectSetInteger(0, name, OBJPROP_ARROWCODE, m_structurePoints[i].isHigh ? 119 : 119);
        ObjectSetInteger(0, name, OBJPROP_COLOR, pointColor);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    }
}

//+------------------------------------------------------------------+
//|                  Draw Supply/Demand Zones                       |
//+------------------------------------------------------------------+
void CAK47SMCModule::DrawSupplyDemandZones()
{
    if(!m_useSDZones) return;
    
    // Remove previous drawings
    ObjectsDeleteAll(0, "AK47_SMC_SZ_");
    ObjectsDeleteAll(0, "AK47_SMC_DZ_");
    
    // Draw supply zones
    for(int i = 0; i < ArraySize(m_supplyZones); i++)
    {
        string name = "AK47_SMC_SZ_" + IntegerToString(i);
        datetime time1 = TimeCurrent() - 60 * 60; // 1 hour back
        datetime time2 = TimeCurrent() + 60 * 60; // 1 hour ahead
        
        double zoneHigh = m_supplyZones[i] + iATR(_Symbol, PERIOD_M1, 14) * 0.2;
        double zoneLow = m_supplyZones[i] - iATR(_Symbol, PERIOD_M1, 14) * 0.2;
        
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, zoneHigh, time2, zoneLow);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrRed & 0xFFFFFF | (180 << 24));
    }
    
    // Draw demand zones
    for(int i = 0; i < ArraySize(m_demandZones); i++)
    {
        string name = "AK47_SMC_DZ_" + IntegerToString(i);
        datetime time1 = TimeCurrent() - 60 * 60; // 1 hour back
        datetime time2 = TimeCurrent() + 60 * 60; // 1 hour ahead
        
        double zoneHigh = m_demandZones[i] + iATR(_Symbol, PERIOD_M1, 14) * 0.2;
        double zoneLow = m_demandZones[i] - iATR(_Symbol, PERIOD_M1, 14) * 0.2;
        
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, zoneHigh, time2, zoneLow);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(0, name, OBJPROP_FILL, true);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrGreen & 0xFFFFFF | (180 << 24));
    }
}