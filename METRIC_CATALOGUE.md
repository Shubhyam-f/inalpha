# Metric Catalogue

| Metric | Status | Convention |
|---|---|---|
| Total return | Independently validated | `(final_equity - metric_initial_cash) / metric_initial_cash * 100` |
| Annualized return | Independently validated against confirmed engine convention | `years = num_bars_processed / annualization_periods`; `annualized_return_pct = total_return_pct / years`; linear, not CAGR |
| Total fees | Independently reconciled | Sum of fill-level `fee` |
| Realized P&L | Fill-derived | Gross realized P&L; fees separate |
| Reported trade count | Independently reconciled | Corresponds to fill count in this dataset |
| Sharpe | Engine-reported | Per-bar simple returns; annual risk-free rate 0; sample standard deviation; annualization factor |
| Sortino | Engine-reported | Per-bar simple returns; target 0; annualization factor |
| Annualized volatility | Engine-reported | Sample std. dev. of bar returns × √annualization factor × 100 |
| Maximum drawdown | Engine-reported | Requires per-bar equity path |
| Maximum drawdown duration | Engine-reported | Requires per-bar equity path |
| Calmar | Partially reproducible | Stored annualized return/drawdown can be used, but path is not independently reconstructed |
| Win rate | Partially reproducible | Depends on documented fill/round-trip closure semantics |
| Profit factor | Partially reproducible | Depends on trade aggregation semantics |
| Payoff ratio | Partially reproducible | Depends on trade aggregation semantics |
| Expectancy | Partially reproducible | Depends on trade aggregation semantics |
| Exposure | Partially reproducible | Depends on fill ordering/netting assumptions |

## Crypto annualization factors

| Timeframe | Bars/year |
|---|---:|
| 5m | 105120 |
| 15m | 35040 |
| 1h | 8760 |
| 4h | 2190 |
| 1d | 365 |

Non-crypto markets require the applicable exchange/session calendar convention.

## Full-validation gap

A per-bar equity curve with `run_id`, `bar_ts`, and `equity` is the minimum additional persisted dataset required to reconstruct the equity-path metrics.
