//+------------------------------------------------------------------+
//|                                          AK47_AI_Module.mqh    |
//|                        Copyright 2025, JonusNattapong                 |
//|                                     https://github.com/JonusNattapong  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, JonusNattapong"
#property link      "https://github.com/JonusNattapong"
#property version   "1.00"

// Include necessary files
#include <Arrays\ArrayObj.mqh>
#include <Math\Stat\Math.mqh>
#include <Math\Alglib\alglib.mqh>

// AI Module for Signal Generation
class CAK47AIModule
{
private:
    int             m_period;           // Signal period
    double          m_threshold;        // Signal threshold
    int             m_historyBars;      // History bars for learning
    
    // Arrays for storing indicator and price data
    double          m_priceData[];      // Price data array
    double          m_rsiData[];        // RSI indicator array
    double          m_macdData[];       // MACD indicator array
    double          m_bollData[];       // Bollinger Bands data
    double          m_momData[];        // Momentum data
    double          m_atrData[];        // ATR data
    
    // Neural network variables (simplified)
    double          m_weights[10][5];   // Weights matrix for simple neural network
    double          m_bias[10];         // Bias values
    
    // Private methods
    void            CalculateIndicators();
    double          NormalizeData(double value, double min, double max);
    void            TrainModel();
    double          ActivationFunction(double x);
    
public:
                    CAK47AIModule(int period, double threshold, int historyBars);
                   ~CAK47AIModule();
    
    double          GetSignal();        // Get current AI signal (-1.0 to 1.0)
    void            UpdateModel();      // Update the AI model with new data
    string          GetModelStats();    // Get model statistics as string
};

//+------------------------------------------------------------------+
//|                    Constructor                                   |
//+------------------------------------------------------------------+
CAK47AIModule::CAK47AIModule(int period, double threshold, int historyBars)
{
    m_period = period;
    m_threshold = threshold;
    m_historyBars = historyBars;
    
    // Initialize arrays
    ArrayResize(m_priceData, m_historyBars);
    ArrayResize(m_rsiData, m_historyBars);
    ArrayResize(m_macdData, m_historyBars);
    ArrayResize(m_bollData, m_historyBars);
    ArrayResize(m_momData, m_historyBars);
    ArrayResize(m_atrData, m_historyBars);
    
    // Initialize weights with small random values
    for(int i = 0; i < 10; i++)
    {
        for(int j = 0; j < 5; j++)
        {
            m_weights[i][j] = 0.1 * (MathRand() / 32767.0) - 0.05;
        }
        m_bias[i] = 0.1 * (MathRand() / 32767.0) - 0.05;
    }
    
    // Initial calculation of indicators
    CalculateIndicators();
    
    // Initial training
    TrainModel();
    
    Print("AI Module initialized with period: ", period, " threshold: ", threshold);
}

//+------------------------------------------------------------------+
//|                    Destructor                                   |
//+------------------------------------------------------------------+
CAK47AIModule::~CAK47AIModule()
{
    // Clean up resources
    ArrayFree(m_priceData);
    ArrayFree(m_rsiData);
    ArrayFree(m_macdData);
    ArrayFree(m_bollData);
    ArrayFree(m_momData);
    ArrayFree(m_atrData);
    
    Print("AI Module destroyed");
}

//+------------------------------------------------------------------+
//|                Calculate Technical Indicators                    |
//+------------------------------------------------------------------+
void CAK47AIModule::CalculateIndicators()
{
    // Calculate RSI
    int rsiHandle = iRSI(_Symbol, PERIOD_M1, m_period, PRICE_CLOSE);
    if(rsiHandle == INVALID_HANDLE)
    {
        Print("Error creating RSI indicator: ", GetLastError());
        return;
    }
    
    CopyBuffer(rsiHandle, 0, 0, m_historyBars, m_rsiData);
    IndicatorRelease(rsiHandle);
    
    // Calculate MACD
    int macdHandle = iMACD(_Symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
    if(macdHandle == INVALID_HANDLE)
    {
        Print("Error creating MACD indicator: ", GetLastError());
        return;
    }
    
    CopyBuffer(macdHandle, 0, 0, m_historyBars, m_macdData);
    IndicatorRelease(macdHandle);
    
    // Calculate Bollinger Bands
    int bollHandle = iBands(_Symbol, PERIOD_M1, 20, 2, 0, PRICE_CLOSE);
    if(bollHandle == INVALID_HANDLE)
    {
        Print("Error creating Bollinger Bands indicator: ", GetLastError());
        return;
    }
    
    // Use the middle band as a reference, could also use upper/lower bands
    CopyBuffer(bollHandle, 0, 0, m_historyBars, m_bollData);
    IndicatorRelease(bollHandle);
    
    // Calculate Momentum
    int momHandle = iMomentum(_Symbol, PERIOD_M1, m_period, PRICE_CLOSE);
    if(momHandle == INVALID_HANDLE)
    {
        Print("Error creating Momentum indicator: ", GetLastError());
        return;
    }
    
    CopyBuffer(momHandle, 0, 0, m_historyBars, m_momData);
    IndicatorRelease(momHandle);
    
    // Calculate ATR for volatility
    int atrHandle = iATR(_Symbol, PERIOD_M1, m_period);
    if(atrHandle == INVALID_HANDLE)
    {
        Print("Error creating ATR indicator: ", GetLastError());
        return;
    }
    
    CopyBuffer(atrHandle, 0, 0, m_historyBars, m_atrData);
    IndicatorRelease(atrHandle);
    
    // Get price data
    CopyClose(_Symbol, PERIOD_M1, 0, m_historyBars, m_priceData);
}

//+------------------------------------------------------------------+
//|                  Normalize data to range [0,1]                  |
//+------------------------------------------------------------------+
double CAK47AIModule::NormalizeData(double value, double min, double max)
{
    if(max == min)
        return 0.5;
        
    return (value - min) / (max - min);
}

//+------------------------------------------------------------------+
//|                  Sigmoid activation function                    |
//+------------------------------------------------------------------+
double CAK47AIModule::ActivationFunction(double x)
{
    // Simple sigmoid function
    return 1.0 / (1.0 + MathExp(-x));
}

//+------------------------------------------------------------------+
//|                  Train the AI model                             |
//+------------------------------------------------------------------+
void CAK47AIModule::TrainModel()
{
    // This is a very simplified training method
    // In a real-world scenario, you would use proper machine learning algorithms
    
    // Find min and max values for normalization
    double minRSI = m_rsiData[ArrayMinimum(m_rsiData, 0, m_historyBars)];
    double maxRSI = m_rsiData[ArrayMaximum(m_rsiData, 0, m_historyBars)];
    
    double minMACD = m_macdData[ArrayMinimum(m_macdData, 0, m_historyBars)];
    double maxMACD = m_macdData[ArrayMaximum(m_macdData, 0, m_historyBars)];
    
    double minMom = m_momData[ArrayMinimum(m_momData, 0, m_historyBars)];
    double maxMom = m_momData[ArrayMaximum(m_momData, 0, m_historyBars)];
    
    double minATR = m_atrData[ArrayMinimum(m_atrData, 0, m_historyBars)];
    double maxATR = m_atrData[ArrayMaximum(m_atrData, 0, m_historyBars)];
    
    // Simplified learning rate
    double learningRate = 0.01;
    
    // Calculate price changes for training targets
    double priceChanges[];
    ArrayResize(priceChanges, m_historyBars - 1);
    
    for(int i = 0; i < m_historyBars - 1; i++)
    {
        priceChanges[i] = (m_priceData[i] > m_priceData[i+1]) ? 1.0 : -1.0;
    }
    
    // Very simple training approach (not realistic for production)
    for(int epoch = 0; epoch < 100; epoch++)
    {
        for(int i = 5; i < m_historyBars - 1; i++)
        {
            // Input features
            double features[5];
            features[0] = NormalizeData(m_rsiData[i], minRSI, maxRSI);
            features[1] = NormalizeData(m_macdData[i], minMACD, maxMACD);
            features[2] = NormalizeData(m_bollData[i], m_bollData[ArrayMinimum(m_bollData, 0, m_historyBars)], m_bollData[ArrayMaximum(m_bollData, 0, m_historyBars)]);
            features[3] = NormalizeData(m_momData[i], minMom, maxMom);
            features[4] = NormalizeData(m_atrData[i], minATR, maxATR);
            
            // Forward pass (very simplified)
            double neuronOutputs[10];
            for(int j = 0; j < 10; j++)
            {
                neuronOutputs[j] = 0;
                for(int k = 0; k < 5; k++)
                {
                    neuronOutputs[j] += features[k] * m_weights[j][k];
                }
                neuronOutputs[j] = ActivationFunction(neuronOutputs[j] + m_bias[j]);
            }
            
            // Output layer (simplified to a single neuron)
            double output = 0;
            for(int j = 0; j < 10; j++)
            {
                output += neuronOutputs[j];
            }
            output = output / 10.0; // Simple average
            
            // Target is based on future price movement
            double target = (priceChanges[i] > 0) ? 1.0 : 0.0;
            
            // Error
            double error = target - output;
            
            // Backpropagation (very simplified)
            for(int j = 0; j < 10; j++)
            {
                for(int k = 0; k < 5; k++)
                {
                    m_weights[j][k] += learningRate * error * features[k];
                }
                m_bias[j] += learningRate * error;
            }
        }
    }
    
    Print("AI Model training completed");
}

//+------------------------------------------------------------------+
//|                  Update AI model with new data                  |
//+------------------------------------------------------------------+
void CAK47AIModule::UpdateModel()
{
    // Recalculate indicators with latest data
    CalculateIndicators();
    
    // Retrain model with updated data
    TrainModel();
}

//+------------------------------------------------------------------+
//|                  Get AI Signal for trading                      |
//+------------------------------------------------------------------+
double CAK47AIModule::GetSignal()
{
    // Ensure we have the latest indicator data
    CalculateIndicators();
    
    // Get the latest indicator values
    double currentRSI = m_rsiData[0];
    double currentMACD = m_macdData[0];
    double currentBoll = m_bollData[0];
    double currentMom = m_momData[0];
    double currentATR = m_atrData[0];
    
    // Find min and max values for normalization
    double minRSI = m_rsiData[ArrayMinimum(m_rsiData, 0, m_historyBars)];
    double maxRSI = m_rsiData[ArrayMaximum(m_rsiData, 0, m_historyBars)];
    
    double minMACD = m_macdData[ArrayMinimum(m_macdData, 0, m_historyBars)];
    double maxMACD = m_macdData[ArrayMaximum(m_macdData, 0, m_historyBars)];
    
    double minMom = m_momData[ArrayMinimum(m_momData, 0, m_historyBars)];
    double maxMom = m_momData[ArrayMaximum(m_momData, 0, m_historyBars)];
    
    double minATR = m_atrData[ArrayMinimum(m_atrData, 0, m_historyBars)];
    double maxATR = m_atrData[ArrayMaximum(m_atrData, 0, m_historyBars)];
    
    // Normalize inputs
    double features[5];
    features[0] = NormalizeData(currentRSI, minRSI, maxRSI);
    features[1] = NormalizeData(currentMACD, minMACD, maxMACD);
    features[2] = NormalizeData(currentBoll, m_bollData[ArrayMinimum(m_bollData, 0, m_historyBars)], m_bollData[ArrayMaximum(m_bollData, 0, m_historyBars)]);
    features[3] = NormalizeData(currentMom, minMom, maxMom);
    features[4] = NormalizeData(currentATR, minATR, maxATR);
    
    // Forward pass to get prediction
    double neuronOutputs[10];
    for(int j = 0; j < 10; j++)
    {
        neuronOutputs[j] = 0;
        for(int k = 0; k < 5; k++)
        {
            neuronOutputs[j] += features[k] * m_weights[j][k];
        }
        neuronOutputs[j] = ActivationFunction(neuronOutputs[j] + m_bias[j]);
    }
    
    // Output layer (simplified to a single value)
    double output = 0;
    for(int j = 0; j < 10; j++)
    {
        output += neuronOutputs[j];
    }
    output = output / 10.0; // Simple average
    
    // Convert from [0,1] to [-1,1] range
    double signal = (output - 0.5) * 2.0;
    
    return signal;
}

//+------------------------------------------------------------------+
//|                  Get model statistics for reporting             |
//+------------------------------------------------------------------+
string CAK47AIModule::GetModelStats()
{
    string stats = "";
    stats += "AI Model Statistics\n";
    stats += "Period: " + IntegerToString(m_period) + "\n";
    stats += "Threshold: " + DoubleToString(m_threshold, 2) + "\n";
    stats += "Last Signal: " + DoubleToString(GetSignal(), 4) + "\n";
    
    // Calculate basic statistics
    double mean = 0;
    for(int i = 0; i < m_historyBars; i++)
    {
        mean += m_priceData[i];
    }
    mean /= m_historyBars;
    
    stats += "Mean Price: " + DoubleToString(mean, 2) + "\n";
    stats += "Current RSI: " + DoubleToString(m_rsiData[0], 2) + "\n";
    stats += "Current MACD: " + DoubleToString(m_macdData[0], 5) + "\n";
    
    return stats;
}