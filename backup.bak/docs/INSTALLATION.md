# Installation Guide

This guide explains how to install and prepare [`AK47ScalperEA.mq5`](../AK47ScalperEA.mq5) for MetaTrader 5.

## Requirements

- MetaTrader 5 terminal
- MetaEditor
- access to a broker that supports the intended symbols
- required market data for the configured trading instruments

## Project Files

Core files in this repository:

- [`AK47ScalperEA.mq5`](../AK47ScalperEA.mq5) — main Expert Advisor
- [`AK47_AI.mqh`](../AK47_AI.mqh) — AI and decision support logic
- [`AK47_News.mqh`](../AK47_News.mqh) — news and calendar logic

## Install Steps

1. Open MetaTrader 5.
2. Open the MT5 data folder.
3. Copy [`AK47ScalperEA.mq5`](../AK47ScalperEA.mq5) into `MQL5/Experts/`.
4. Copy [`AK47_AI.mqh`](../AK47_AI.mqh) and [`AK47_News.mqh`](../AK47_News.mqh) into the appropriate `MQL5/Include/` location if your local setup requires separated include files.
5. Open [`AK47ScalperEA.mq5`](../AK47ScalperEA.mq5) in MetaEditor.
6. Compile the EA and resolve any broker or environment-specific symbol issues.

## MT5 Preparation

Before attaching the EA to a chart:

- enable Algo Trading in MT5
- confirm the target symbol is available in Market Watch
- verify the configured DXY/USDX symbol exists at your broker
- ensure economic calendar and external data access behave as expected

## Recommended First Run

1. Attach the EA to a demo account chart.
2. Start with conservative risk settings.
3. Confirm log output and dashboard behavior.
4. Run Strategy Tester validation before live deployment.

## Troubleshooting

### Compile errors

- confirm include files are in the expected locations
- confirm MetaTrader 5 build version supports the used MQL5 features

### Symbol errors

- verify broker symbol names for DXY or correlated instruments
- update the relevant input parameter in the EA settings

### No trades opened

- review spread, volatility, news, and AI consensus filters
- check whether market conditions satisfy the strategy constraints described in [`README.md`](../README.md)
