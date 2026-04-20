# Contributing to AK47ScalperEA

This repository contains the source code and documentation for [`AK47ScalperEA.mq5`](AK47ScalperEA.mq5) and its related modules.

## Scope

Contributions should focus on:

- improving stability and readability of [`AK47ScalperEA.mq5`](AK47ScalperEA.mq5)
- refining AI and signal logic in [`AK47_AI.mqh`](AK47_AI.mqh)
- improving news and calendar filtering in [`AK47_News.mqh`](AK47_News.mqh)
- strengthening project documentation such as [`README.md`](README.md) and [`CHANGELOG.md`](CHANGELOG.md)

## Contribution Rules

1. Keep changes small and reviewable.
2. Preserve trading safety checks and risk-management behavior.
3. Update [`CHANGELOG.md`](CHANGELOG.md) for user-visible changes.
4. Update [`README.md`](README.md) when parameters, workflows, or architecture change.
5. Avoid committing generated binaries such as `.ex5` files unless a release explicitly requires them.

## Suggested Workflow

1. Create a feature branch.
2. Make focused edits.
3. Recompile [`AK47ScalperEA.mq5`](AK47ScalperEA.mq5) in MetaEditor.
4. Validate behavior in MT5 Strategy Tester or demo trading.
5. Submit a pull request with a concise change summary and risk notes.

## Pull Request Checklist

- [ ] Code compiles without new warnings that affect execution
- [ ] Risk, entry, and exit logic were reviewed
- [ ] Documentation was updated if needed
- [ ] Changelog entry was added if behavior changed
- [ ] Testing notes were included in the PR description

## Testing Notes

Before merging, document:

- symbol and timeframe used
- broker-specific assumptions
- spread/slippage conditions
- whether testing was done in backtest, forward demo, or both

## Security and Safety

Do not remove safeguards around:

- lot sizing
- spread filters
- news filters
- drawdown protection
- order validation

Trading code changes should always be validated on demo before any live use.
