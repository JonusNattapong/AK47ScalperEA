# Configuration Reference

This document complements the summary table in [`README.md`](../README.md) with practical setup notes for [`AK47ScalperEA.mq5`](../AK47ScalperEA.mq5).

## Core Risk Parameters

### `LotSize`

Base lot size used by the intelligence-based risk engine.

Guidance:

- start small on new brokers
- validate scaling behavior on demo first
- review any dynamic lot increase carefully

## Market Context Inputs

### `DxySymbol`

Broker-specific ticker used for Dollar Index filtering.

Examples may vary by broker:

- `DXY`
- `USDX`

If this symbol is wrong, the filter may fail or produce unusable context.

## Feature Toggles

### `UseSmcFilter`

Enables supply and demand zone filtering.

Use this when you want entries aligned with institutional zones and stricter trade selection.

### `UseAutoTuning`

Allows the EA to become more selective when recent performance declines.

Recommended for adaptive operation, but it should still be monitored in forward testing.

### `UseNewsAiFilter`

Enables the news or AI-assisted macro filter.

Use this when external context is part of your execution rules.

### `UseSelfLearning`

Enables post-trade learning behavior.

Use cautiously and validate its impact through repeatable testing.

## Configuration Recommendations

### Conservative profile

- smaller `LotSize`
- strict SMC enabled
- news filter enabled
- auto-tuning enabled

### Experimental profile

- minimal capital exposure
- self-learning enabled only on demo
- compare results with and without adaptive tuning

## Validation Checklist

After changing settings:

1. Recompile [`AK47ScalperEA.mq5`](../AK47ScalperEA.mq5).
2. Run Strategy Tester.
3. Review logs for filter activation and symbol lookups.
4. Confirm behavior on a demo account before live use.
