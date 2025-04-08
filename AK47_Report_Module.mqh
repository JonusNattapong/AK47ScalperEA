//+------------------------------------------------------------------+
//|                                    AK47_Report_Module.mqh    |
//|                        Copyright 2025, JonusNattapong                 |
//|                                     https://github.com/JonusNattapong  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, JonusNattapong"
#property link      "https://github.com/JonusNattapong"
#property version   "1.00"

// Include necessary files
#include <Arrays\ArrayObj.mqh>
#include <Charts\Chart.mqh>

// Structure for storing trade data
struct STrade
{
    datetime time;         // Trade entry time
    bool     isBuy;        // Trade direction (true for buy, false for sell)
    double   lotSize;      // Trade lot size
    double   openPrice;    // Entry price
    double   closePrice;   // Exit price (0 if still open)
    double   profit;       // Trade profit/loss
    double   pips;         // Trade pips gained/lost
    bool     isOpen;       // Is the trade still open
    int      stopLoss;     // Stop loss in points
    int      takeProfit;   // Take profit in points
    string   comment;      // Trade comment
};

// Report Module
class CAK47ReportModule
{
private:
    string          m_eaName;               // EA name
    bool            m_useVisualDashboard;   // Use visual dashboard
    
    STrade          m_trades[];             // Array of trades
    int             m_tradeCount;           // Total trade count
    int             m_winCount;             // Win count
    int             m_lossCount;            // Loss count
    double          m_totalProfit;          // Total profit
    double          m_totalLoss;            // Total loss
    double          m_maxDrawdown;          // Maximum drawdown
    
    datetime        m_startTime;            // EA start time
    datetime        m_currentTime;          // Current time
    
    // Dashboard objects
    CChart          m_chart;                // Chart object
    string          m_labelPrefix;          // Prefix for dashboard objects
    
    // Private methods
    void            CalculateStatistics();
    void            CreateDashboardObjects();
    void            UpdateDashboardObjects();
    double          CalculateWinRate();
    double          CalculateProfitFactor();
    double          CalculateAverageWin();
    double          CalculateAverageLoss();
    int             GetTodayTradeCount();
    
public:
                    CAK47ReportModule(string eaName, bool useVisualDashboard);
                   ~CAK47ReportModule();
    
    void            LogTrade(bool isBuy, double lotSize, double openPrice, int stopLoss, int takeProfit, string comment = "");
    void            UpdateTradeStatus(int index, double closePrice, double profit, double pips, bool isOpen);
    int             GetDailyTradeCount();
    int             GetOpenTradeCount();
    double          GetTotalProfit();
    double          GetMaxDrawdown();
    string          GetTradeStats();
    void            UpdateDashboard();
    void            UpdateMetrics();
};

//+------------------------------------------------------------------+
//|                    Constructor                                   |
//+------------------------------------------------------------------+
CAK47ReportModule::CAK47ReportModule(string eaName, bool useVisualDashboard)
{
    m_eaName = eaName;
    m_useVisualDashboard = useVisualDashboard;
    
    // Initialize trade array
    ArrayResize(m_trades, 0);
    
    // Initialize statistics
    m_tradeCount = 0;
    m_winCount = 0;
    m_lossCount = 0;
    m_totalProfit = 0.0;
    m_totalLoss = 0.0;
    m_maxDrawdown = 0.0;
    
    // Initialize times
    m_startTime = TimeCurrent();
    m_currentTime = m_startTime;
    
    // Initialize dashboard
    m_labelPrefix = "AK47_Dashboard_";
    
    if(m_useVisualDashboard)
    {
        m_chart.Attach(0); // Attach to current chart
        CreateDashboardObjects();
        UpdateDashboardObjects();
    }
    
    Print("Report Module initialized");
}

//+------------------------------------------------------------------+
//|                    Destructor                                    |
//+------------------------------------------------------------------+
CAK47ReportModule::~CAK47ReportModule()
{
    // Clean up resources
    ArrayFree(m_trades);
    
    // Cleanup dashboard objects
    if(m_useVisualDashboard)
    {
        ObjectsDeleteAll(0, m_labelPrefix);
        m_chart.Detach();
    }
    
    Print("Report Module destroyed");
}

//+------------------------------------------------------------------+
//|                  Log a new trade                                |
//+------------------------------------------------------------------+
void CAK47ReportModule::LogTrade(bool isBuy, double lotSize, double openPrice, int stopLoss, int takeProfit, string comment = "")
{
    // Resize array for new trade
    int index = m_tradeCount;
    ArrayResize(m_trades, m_tradeCount + 1);
    
    // Fill trade data
    m_trades[index].time = TimeCurrent();
    m_trades[index].isBuy = isBuy;
    m_trades[index].lotSize = lotSize;
    m_trades[index].openPrice = openPrice;
    m_trades[index].closePrice = 0;
    m_trades[index].profit = 0;
    m_trades[index].pips = 0;
    m_trades[index].isOpen = true;
    m_trades[index].stopLoss = stopLoss;
    m_trades[index].takeProfit = takeProfit;
    m_trades[index].comment = comment;
    
    // Increment trade count
    m_tradeCount++;
    
    // Update dashboard
    if(m_useVisualDashboard)
        UpdateDashboard();
        
    Print("Trade logged: ", isBuy ? "BUY" : "SELL", " at ", DoubleToString(openPrice, _Digits));
}

//+------------------------------------------------------------------+
//|                  Update trade status                            |
//+------------------------------------------------------------------+
void CAK47ReportModule::UpdateTradeStatus(int index, double closePrice, double profit, double pips, bool isOpen)
{
    if(index < 0 || index >= m_tradeCount)
        return;
        
    // Update trade data
    m_trades[index].closePrice = closePrice;
    m_trades[index].profit = profit;
    m_trades[index].pips = pips;
    m_trades[index].isOpen = isOpen;
    
    // Recalculate statistics
    CalculateStatistics();
    
    // Update dashboard
    if(m_useVisualDashboard)
        UpdateDashboard();
}

//+------------------------------------------------------------------+
//|                  Get daily trade count                          |
//+------------------------------------------------------------------+
int CAK47ReportModule::GetDailyTradeCount()
{
    return GetTodayTradeCount();
}

//+------------------------------------------------------------------+
//|                  Get open trade count                           |
//+------------------------------------------------------------------+
int CAK47ReportModule::GetOpenTradeCount()
{
    int openCount = 0;
    
    for(int i = 0; i < m_tradeCount; i++)
    {
        if(m_trades[i].isOpen)
            openCount++;
    }
    
    return openCount;
}

//+------------------------------------------------------------------+
//|                  Calculate Statistics                           |
//+------------------------------------------------------------------+
void CAK47ReportModule::CalculateStatistics()
{
    m_winCount = 0;
    m_lossCount = 0;
    m_totalProfit = 0.0;
    m_totalLoss = 0.0;
    
    double runningEquity = 0.0;
    double maxEquity = 0.0;
    double currentDrawdown = 0.0;
    
    for(int i = 0; i < m_tradeCount; i++)
    {
        if(!m_trades[i].isOpen)
        {
            if(m_trades[i].profit > 0)
            {
                m_winCount++;
                m_totalProfit += m_trades[i].profit;
            }
            else
            {
                m_lossCount++;
                m_totalLoss += MathAbs(m_trades[i].profit);
            }
            
            runningEquity += m_trades[i].profit;
            
            if(runningEquity > maxEquity)
                maxEquity = runningEquity;
                
            currentDrawdown = maxEquity - runningEquity;
            
            if(currentDrawdown > m_maxDrawdown)
                m_maxDrawdown = currentDrawdown;
        }
    }
}

//+------------------------------------------------------------------+
//|                  Get trade statistics                           |
//+------------------------------------------------------------------+
string CAK47ReportModule::GetTradeStats()
{
    CalculateStatistics();
    
    string stats = "";
    stats += "Trade Statistics for " + m_eaName + "\n";
    stats += "---------------------------------------------\n";
    stats += "Total Trades: " + IntegerToString(m_tradeCount) + "\n";
    stats += "Open Trades: " + IntegerToString(GetOpenTradeCount()) + "\n";
    stats += "Wins: " + IntegerToString(m_winCount) + "\n";
    stats += "Losses: " + IntegerToString(m_lossCount) + "\n";
    
    double winRate = CalculateWinRate();
    stats += "Win Rate: " + DoubleToString(winRate * 100.0, 2) + "%\n";
    
    double profitFactor = CalculateProfitFactor();
    stats += "Profit Factor: " + DoubleToString(profitFactor, 2) + "\n";
    
    stats += "Total Profit: " + DoubleToString(m_totalProfit - m_totalLoss, 2) + "\n";
    stats += "Maximum Drawdown: " + DoubleToString(m_maxDrawdown, 2) + "\n";
    
    double avgWin = CalculateAverageWin();
    double avgLoss = CalculateAverageLoss();
    
    stats += "Average Win: " + DoubleToString(avgWin, 2) + "\n";
    stats += "Average Loss: " + DoubleToString(avgLoss, 2) + "\n";
    
    if(avgLoss > 0)
        stats += "Risk-Reward Ratio: 1:" + DoubleToString(avgWin / avgLoss, 2) + "\n";
    
    stats += "Today's Trades: " + IntegerToString(GetTodayTradeCount()) + "\n";
    
    int runTime = (int)((TimeCurrent() - m_startTime) / 60); // in minutes
    stats += "EA Running Time: " + IntegerToString(runTime / 1440) + "d " + 
              IntegerToString((runTime % 1440) / 60) + "h " + 
              IntegerToString(runTime % 60) + "m\n";
    
    return stats;
}

//+------------------------------------------------------------------+
//|                  Calculate Win Rate                             |
//+------------------------------------------------------------------+
double CAK47ReportModule::CalculateWinRate()
{
    int closedTrades = m_winCount + m_lossCount;
    
    if(closedTrades > 0)
        return (double)m_winCount / closedTrades;
        
    return 0.0;
}

//+------------------------------------------------------------------+
//|                  Calculate Profit Factor                        |
//+------------------------------------------------------------------+
double CAK47ReportModule::CalculateProfitFactor()
{
    if(m_totalLoss > 0)
        return m_totalProfit / m_totalLoss;
        
    return (m_totalProfit > 0) ? 999.0 : 0.0;
}

//+------------------------------------------------------------------+
//|                  Calculate Average Win                          |
//+------------------------------------------------------------------+
double CAK47ReportModule::CalculateAverageWin()
{
    if(m_winCount > 0)
        return m_totalProfit / m_winCount;
        
    return 0.0;
}

//+------------------------------------------------------------------+
//|                  Calculate Average Loss                         |
//+------------------------------------------------------------------+
double CAK47ReportModule::CalculateAverageLoss()
{
    if(m_lossCount > 0)
        return m_totalLoss / m_lossCount;
        
    return 0.0;
}

//+------------------------------------------------------------------+
//|                  Get trades made today                          |
//+------------------------------------------------------------------+
int CAK47ReportModule::GetTodayTradeCount()
{
    int todayCount = 0;
    
    // Get current day
    MqlDateTime nowTime;
    TimeToStruct(TimeCurrent(), nowTime);
    int currentDay = nowTime.day;
    int currentMonth = nowTime.mon;
    int currentYear = nowTime.year;
    
    // Count trades made today
    for(int i = 0; i < m_tradeCount; i++)
    {
        MqlDateTime tradeTime;
        TimeToStruct(m_trades[i].time, tradeTime);
        
        if(tradeTime.day == currentDay && tradeTime.mon == currentMonth && tradeTime.year == currentYear)
            todayCount++;
    }
    
    return todayCount;
}

//+------------------------------------------------------------------+
//|                  Get Total Profit                              |
//+------------------------------------------------------------------+
double CAK47ReportModule::GetTotalProfit()
{
    return m_totalProfit - m_totalLoss;
}

//+------------------------------------------------------------------+
//|                  Get Maximum Drawdown                           |
//+------------------------------------------------------------------+
double CAK47ReportModule::GetMaxDrawdown()
{
    return m_maxDrawdown;
}

//+------------------------------------------------------------------+
//|                  Create Dashboard Objects                       |
//+------------------------------------------------------------------+
void CAK47ReportModule::CreateDashboardObjects()
{
    if(!m_useVisualDashboard)
        return;
    
    // Set up dashboard area
    int x = 20;
    int y = 20;
    int width = 200;
    int height = 20;
    int spacing = 5;
    
    // Background panel
    string backName = m_labelPrefix + "Background";
    ObjectCreate(0, backName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, backName, OBJPROP_XDISTANCE, x - 10);
    ObjectSetInteger(0, backName, OBJPROP_YDISTANCE, y - 10);
    ObjectSetInteger(0, backName, OBJPROP_XSIZE, width + 20);
    ObjectSetInteger(0, backName, OBJPROP_YSIZE, height * 14 + spacing * 14);
    ObjectSetInteger(0, backName, OBJPROP_COLOR, clrBlack);
    ObjectSetInteger(0, backName, OBJPROP_BGCOLOR, clrDarkSlateGray);
    ObjectSetInteger(0, backName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, backName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, backName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, backName, OBJPROP_BACK, false);
    ObjectSetInteger(0, backName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, backName, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, backName, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, backName, OBJPROP_ZORDER, 0);
    
    // Title
    string titleName = m_labelPrefix + "Title";
    ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, x + 10);
    ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, titleName, OBJPROP_TEXT, m_eaName + " Dashboard");
    ObjectSetString(0, titleName, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
    
    y += height + spacing;
    
    // Create label pairs (label + value)
    string labels[] = {
        "Total Trades:", "Win Rate:", "Profit Factor:", "Net Profit:", 
        "Max Drawdown:", "Average Win:", "Average Loss:", "Risk/Reward:", 
        "Today's Trades:", "Open Trades:", "Running Time:", "XAU/USD M1:", "AI Signal:"
    };
    
    for(int i = 0; i < ArraySize(labels); i++)
    {
        // Label
        string labelName = m_labelPrefix + "Label" + IntegerToString(i);
        ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, labelName, OBJPROP_TEXT, labels[i]);
        ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrLightGray);
        ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
        
        // Value
        string valueName = m_labelPrefix + "Value" + IntegerToString(i);
        ObjectCreate(0, valueName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, valueName, OBJPROP_XDISTANCE, x + 120);
        ObjectSetInteger(0, valueName, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, valueName, OBJPROP_TEXT, "---");
        ObjectSetString(0, valueName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, valueName, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, valueName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, valueName, OBJPROP_SELECTABLE, false);
        
        y += height + spacing;
    }
}

//+------------------------------------------------------------------+
//|                  Update Dashboard Objects                       |
//+------------------------------------------------------------------+
void CAK47ReportModule::UpdateDashboardObjects()
{
    if(!m_useVisualDashboard)
        return;
    
    // Calculate statistics
    CalculateStatistics();
    
    // Update values
    double winRate = CalculateWinRate();
    double profitFactor = CalculateProfitFactor();
    double avgWin = CalculateAverageWin();
    double avgLoss = CalculateAverageLoss();
    double riskReward = (avgLoss > 0) ? (avgWin / avgLoss) : 0.0;
    int runTime = (int)((TimeCurrent() - m_startTime) / 60); // in minutes
    
    string values[] = {
        IntegerToString(m_tradeCount),
        DoubleToString(winRate * 100.0, 2) + "%",
        DoubleToString(profitFactor, 2),
        DoubleToString(m_totalProfit - m_totalLoss, 2),
        DoubleToString(m_maxDrawdown, 2),
        DoubleToString(avgWin, 2),
        DoubleToString(avgLoss, 2),
        "1:" + DoubleToString(riskReward, 2),
        IntegerToString(GetTodayTradeCount()),
        IntegerToString(GetOpenTradeCount()),
        IntegerToString(runTime / 1440) + "d " + IntegerToString((runTime % 1440) / 60) + "h " + IntegerToString(runTime % 60) + "m",
        DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits),
        "---" // AI Signal placeholder
    };
    
    for(int i = 0; i < ArraySize(values); i++)
    {
        string valueName = m_labelPrefix + "Value" + IntegerToString(i);
        ObjectSetString(0, valueName, OBJPROP_TEXT, values[i]);
        
        // Set color based on value type
        color valueColor = clrWhite;
        
        // Net profit and win rate colors
        if(i == 1) // Win Rate
            valueColor = (winRate >= 0.5) ? clrLime : clrRed;
        else if(i == 2) // Profit Factor
            valueColor = (profitFactor >= 1.0) ? clrLime : clrRed;
        else if(i == 3) // Net Profit
            valueColor = (m_totalProfit - m_totalLoss > 0) ? clrLime : clrRed;
            
        ObjectSetInteger(0, valueName, OBJPROP_COLOR, valueColor);
    }
    
    ChartRedraw();
}

//+------------------------------------------------------------------+
//|                  Update Dashboard                               |
//+------------------------------------------------------------------+
void CAK47ReportModule::UpdateDashboard()
{
    if(m_useVisualDashboard)
        UpdateDashboardObjects();
}

//+------------------------------------------------------------------+
//|                  Update Metrics                                 |
//+------------------------------------------------------------------+
void CAK47ReportModule::UpdateMetrics()
{
    m_currentTime = TimeCurrent();
    CalculateStatistics();
    
    if(m_useVisualDashboard)
        UpdateDashboard();
}