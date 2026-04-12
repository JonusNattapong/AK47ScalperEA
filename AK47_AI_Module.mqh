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
#include <Indicators\Indicator.mqh>

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
    double          m_priceChanges[];   // Price changes for training
    
    // Neural network variables
    // Built-in fallback small MLP for on-terminal training
#define INPUT_SIZE 5      // Number of input features
#define HIDDEN_SIZE 32    // Number of hidden neurons (fallback)
#define OUTPUT_SIZE 1     // Single output for signal prediction
    
    // Built-in fallback weights (used if no external model is loaded)
    double          m_inputWeights[INPUT_SIZE][HIDDEN_SIZE];
    double          m_hiddenWeights[HIDDEN_SIZE][OUTPUT_SIZE];
    double          m_bias[HIDDEN_SIZE + OUTPUT_SIZE];

    // External model (real AI) loaded from file
    bool            m_modelLoaded;        // true if external model weights are loaded
    int             m_extInput;           // input size from model file
    int             m_extHidden;          // hidden size from model file
    int             m_extOutput;          // output size from model file
    double          m_W1[];               // flattened [m_extInput * m_extHidden]
    double          m_b1[];               // [m_extHidden]
    double          m_W2[];               // flattened [m_extHidden * m_extOutput]
    double          m_b2[];               // [m_extOutput]
    
// Private methods
    void            CalculateIndicators();
    void            PrepareTrainingData();
    void            TrainModel();
    
    // External model support
    bool            LoadModelFromCSV(string filename);
    double          PredictWithExternal(double &features[]);
    double          NormalizeData(double value, double min, double max);
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
    m_modelLoaded = false;
    
    // Initialize arrays
    ArrayResize(m_priceData, m_historyBars);
    ArrayResize(m_rsiData, m_historyBars);
    ArrayResize(m_macdData, m_historyBars);
    ArrayResize(m_bollData, m_historyBars);
    ArrayResize(m_momData, m_historyBars);
    ArrayResize(m_atrData, m_historyBars);
    
// Initialize neural network weights with random values
for(int i = 0; i < INPUT_SIZE; i++) {
    for(int j = 0; j < HIDDEN_SIZE; j++) {
        m_inputWeights[i][j] = 0.1 * MathRand() / 32767.0 - 0.05;
    }
}

for(int i = 0; i < HIDDEN_SIZE; i++) {
    for(int j = 0; j < OUTPUT_SIZE; j++) {
        m_hiddenWeights[i][j] = 0.1 * MathRand() / 32767.0 - 0.05;
    }
    m_bias[i] = 0.1 * MathRand() / 32767.0 - 0.05;
}

for(int i = 0; i < OUTPUT_SIZE; i++) {
    m_bias[HIDDEN_SIZE + i] = 0.1 * MathRand() / 32767.0 - 0.05;
}
    
// Initial calculation of indicators
CalculateIndicators();
    
// Try load external model from MQL5/Files (place ak47_model.csv there)
if(!LoadModelFromCSV("ak47_model.csv"))
{
    // Fallback to lightweight on-terminal training
    TrainModel();
}
    
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
//|                  Prepare training data                          |
//+------------------------------------------------------------------+
void CAK47AIModule::PrepareTrainingData()
{
    // This is a very simplified training method
    // In a real-world scenario, you would use proper machine learning algorithms
    
    // Calculate price changes for training targets
    ArrayResize(m_priceChanges, m_historyBars - 1);
    
    for(int i = 0; i < m_historyBars - 1; i++)
    {
        m_priceChanges[i] = (m_priceData[i] > m_priceData[i+1]) ? 1.0 : -1.0;
    }
    
    Print("Training data prepared with ", m_historyBars, " historical bars");
}

//+------------------------------------------------------------------+
//|                  Train the AI model                             |
//+------------------------------------------------------------------+
void CAK47AIModule::TrainModel()
{
    PrepareTrainingData();
    
    if(m_historyBars < 10) {
        Print("Warning: Not enough history bars for training. Need at least 10 bars.");
        return;
    }
    
    // Find min and max values for normalization
    double minRSI = m_rsiData[ArrayMinimum(m_rsiData, 0, m_historyBars)];
    double maxRSI = m_rsiData[ArrayMaximum(m_rsiData, 0, m_historyBars)];
    
    double minMACD = m_macdData[ArrayMinimum(m_macdData, 0, m_historyBars)];
    double maxMACD = m_macdData[ArrayMaximum(m_macdData, 0, m_historyBars)];
    
    double minMom = m_momData[ArrayMinimum(m_momData, 0, m_historyBars)];
    double maxMom = m_momData[ArrayMaximum(m_momData, 0, m_historyBars)];
    
    double minATR = m_atrData[ArrayMinimum(m_atrData, 0, m_historyBars)];
    double maxATR = m_atrData[ArrayMaximum(m_atrData, 0, m_historyBars)];
    
    // Learning rate
    double learningRate = 0.01;
    
    // Very simple training approach (not realistic for production)
    for(int epoch = 0; epoch < 100; epoch++)
    {
        for(int i = 5; i < m_historyBars - 1; i++)
        {
            // Input features
            double features[INPUT_SIZE];
            features[0] = NormalizeData(m_rsiData[i], minRSI, maxRSI);
            features[1] = NormalizeData(m_macdData[i], minMACD, maxMACD);
            features[2] = NormalizeData(m_bollData[i], m_bollData[ArrayMinimum(m_bollData, 0, m_historyBars)], m_bollData[ArrayMaximum(m_bollData, 0, m_historyBars)]);
            features[3] = NormalizeData(m_momData[i], minMom, maxMom);
            features[4] = NormalizeData(m_atrData[i], minATR, maxATR);
            
            // Forward pass - Hidden layer
            double hiddenOutputs[HIDDEN_SIZE];
            for(int j = 0; j < HIDDEN_SIZE; j++)
            {
                hiddenOutputs[j] = 0.0;
                for(int k = 0; k < INPUT_SIZE; k++)
                {
                    hiddenOutputs[j] += features[k] * m_inputWeights[k][j];
                }
                hiddenOutputs[j] = ActivationFunction(hiddenOutputs[j] + m_bias[j]);
            }
            
            // Output layer
            double output = 0.0;
            for(int j = 0; j < HIDDEN_SIZE; j++)
            {
                output += hiddenOutputs[j] * m_hiddenWeights[j][0];
            }
            output = ActivationFunction(output + m_bias[HIDDEN_SIZE]);
            
            // Target is based on future price movement
            double target = (m_priceChanges[i] > 0) ? 1.0 : 0.0;
            
            // Error
            double error = target - output;
            
            // Backpropagation - Output layer
            double outputDelta = error * output * (1.0 - output); // Derivative of sigmoid
            
            // Update hidden to output weights
            for(int j = 0; j < HIDDEN_SIZE; j++)
            {
                m_hiddenWeights[j][0] += learningRate * outputDelta * hiddenOutputs[j];
            }
            
            // Update output bias
            m_bias[HIDDEN_SIZE] += learningRate * outputDelta;
            
            // Backpropagation - Hidden layer
            for(int j = 0; j < HIDDEN_SIZE; j++)
            {
                double hiddenDelta = hiddenOutputs[j] * (1.0 - hiddenOutputs[j]) * outputDelta * m_hiddenWeights[j][0];
                
                // Update input to hidden weights
                for(int k = 0; k < INPUT_SIZE; k++)
                {
                    m_inputWeights[k][j] += learningRate * hiddenDelta * features[k];
                }
                
                // Update hidden bias
                m_bias[j] += learningRate * hiddenDelta;
            }
        }
        
        // Print progress every 20 epochs
        if(epoch % 20 == 0)
            Print("Training epoch ", epoch, " completed");
    }
    
    Print("AI Model training completed successfully");
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

    // Prefer external model if available
    if(m_modelLoaded && m_extInput == 5 && m_extOutput >= 1)
    {
        return PredictWithExternal(features);
    }

// Use simple neural network to get prediction
// Forward pass through the network

// Hidden layer
double hiddenOutputs[HIDDEN_SIZE];
for(int i = 0; i < HIDDEN_SIZE; i++) {
    hiddenOutputs[i] = 0.0;
    for(int j = 0; j < INPUT_SIZE; j++) {
        hiddenOutputs[i] += features[j] * m_inputWeights[j][i];
    }
    hiddenOutputs[i] = ActivationFunction(hiddenOutputs[i] + m_bias[i]);
}

// Output layer
double output = 0.0;
for(int i = 0; i < HIDDEN_SIZE; i++) {
    output += hiddenOutputs[i] * m_hiddenWeights[i][0];
}
output = ActivationFunction(output + m_bias[HIDDEN_SIZE]);

// Scale to range [-1, 1]
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

//+------------------------------------------------------------------+
//|                  Load external model (CSV)                       |
//+------------------------------------------------------------------+
bool CAK47AIModule::LoadModelFromCSV(string filename)
{
    m_modelLoaded = false;
    int fh = FileOpen(filename, FILE_READ | FILE_CSV | FILE_ANSI);
    if(fh == INVALID_HANDLE)
    {
        // Not an error: simply means external model not supplied yet
        Print("AI: External model not found (", filename, "). Using fallback model.");
        return false;
    }
    // Expected layout (CSV, numbers only):
    // in, hidden, out, [W1(in*hidden)], [b1(hidden)], [W2(hidden*out)], [b2(out)]
    int in  = (int)FileReadNumber(fh);
    int hid = (int)FileReadNumber(fh);
    int out = (int)FileReadNumber(fh);
    if(in <= 0 || hid <= 0 || out <= 0)
    {
        FileClose(fh);
        Print("AI: Invalid model header in ", filename);
        return false;
    }
    ArrayResize(m_W1, in * hid);
    ArrayResize(m_b1, hid);
    ArrayResize(m_W2, hid * out);
    ArrayResize(m_b2, out);
    for(int i = 0; i < in * hid; i++) m_W1[i] = FileReadNumber(fh);
    for(int i = 0; i < hid; i++)      m_b1[i] = FileReadNumber(fh);
    for(int i = 0; i < hid * out; i++) m_W2[i] = FileReadNumber(fh);
    for(int i = 0; i < out; i++)       m_b2[i] = FileReadNumber(fh);
    FileClose(fh);
    m_extInput = in;
    m_extHidden = hid;
    m_extOutput = out;
    m_modelLoaded = true;
    Print("AI: Loaded external model (", in, "x", hid, "x", out, ") from ", filename);
    return true;
}

//+------------------------------------------------------------------+
//|                  Predict with external model                     |
//+------------------------------------------------------------------+
double CAK47AIModule::PredictWithExternal(double &features[])
{
    if(!m_modelLoaded) return 0.0;
    if(ArraySize(features) < m_extInput) return 0.0;
    // Hidden layer
    double hidden[];
    ArrayResize(hidden, m_extHidden);
    for(int i = 0; i < m_extHidden; i++)
    {
        double s = 0.0;
        for(int j = 0; j < m_extInput; j++)
        {
            s += features[j] * m_W1[j * m_extHidden + i];
        }
        hidden[i] = ActivationFunction(s + m_b1[i]);
    }
    // Output layer (assume single output)
    double out = 0.0;
    for(int i = 0; i < m_extHidden; i++)
        out += hidden[i] * m_W2[i * m_extOutput + 0];
    out = ActivationFunction(out + m_b2[0]);
    // Scale to [-1, 1]
    return (out - 0.5) * 2.0;
}
