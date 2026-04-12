AK47ScalperEA — External AI Model Guide

Overview
- The EA now supports loading a real AI model (feed‑forward MLP) from a CSV file at runtime. This replaces the previous toy, in‑terminal training with an externally trained model.
- Inference runs entirely in MQL5. Training is done offline (Python script provided) and the learned weights are imported.

Model Architecture
- Inputs: 5 features [RSI, MACD, Bollinger Band %B, Momentum, ATR]
- Network: 1 hidden layer (size is configurable by training script)
- Activation: Sigmoid for hidden and output
- Output: Single value in range [-1, 1] (after scaling)

Weight File Format (CSV)
- Order of numbers in a single CSV stream (line breaks are allowed):
  1) `IN, HIDDEN, OUT` (integers)
  2) `IN*HIDDEN` weights for W1 (row‑major: j=0..IN-1 then i=0..HIDDEN-1 index = j*HIDDEN+i)
  3) `HIDDEN` biases for b1
  4) `HIDDEN*OUT` weights for W2 (row‑major: i=0..HIDDEN-1 then k=0..OUT-1 index = i*OUT+k)
  5) `OUT` biases for b2

Location
- Place the CSV file in your terminal’s `MQL5/Files` folder as `ak47_model.csv`.
- The EA tries to load it on startup. If not found, it falls back to the built‑in lightweight model.

Training (Python)
1) Prepare historical OHLC data CSV: columns [time, open, high, low, close].
2) Run `python tools/train_ai_model.py --data path/to/data.csv --hidden 32 --epochs 200`.
3) Copy the produced `ak47_model.csv` into `MQL5/Files/`.

Notes
- The EA normalizes inputs from current data; no scaler is required in the file.
- You can change hidden size freely; input must remain 5 and output 1 for the current EA.

