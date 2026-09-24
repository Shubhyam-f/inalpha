# Validation Findings

## Public Synthetic Reproduction

| **Validation Query Target** | **Observed Synthetic Result** | **Finding / Status** |
|---|---|---|
| **Duplicate Candidate Keys** | `C_DUP` | FAILURE — 1 row returned |
| **Duplicate Run Keys** | `R_DUP_RUN` | FAILURE — 1 row returned |
| **Duplicate Trade (`run_key`, `seq`)** | `R_DUP_TRADE` (seq 1) | FAILURE — 1 row returned |
| **Candidate missing Run** | `C_DUP`, `C_ORPHAN`, `C_BAD_FIT` | FAILURE — 4 rows returned |
| **Run missing Candidate** | `R_ORPHAN` → `C_MISSING` | FAILURE — 1 row returned |
| **Trade missing Run** | `R_MISSING_RUN` | FAILURE — 1 row returned |
| **Trade Count mismatch** | `R_BAD_MATH` (reported: 5, actual: 1); `R_DUP_RUN` (reported: 1, actual: 2) | FAILURE — 2 rows returned |
| **Total Fees mismatch** | `R_BAD_MATH` (reported: 10, actual: 2); `R_DUP_RUN` (reported: 1, actual: 2) | FAILURE — 2 rows returned |
| **Initial Cash vs `metric_initial_cash`** | `R_BAD_MATH` (10,000 vs 5,000) | FAILURE — 1 row returned |
| **`total_return_pct` calculation error** | `R_BAD_MATH` (reported: 99.0, calculated: 300.0) | FAILURE — 1 row returned |
| **`to_ts <= from_ts`** | `R_BAD_MATH` | FAILURE — 1 row returned |
| **Negative `fee_rate`** | `R_BAD_MATH` (-0.05) | FAILURE — 1 row returned |
| **`quantity <= 0`** | `R_BAD_MATH` trade seq 1 (-5.0) | FAILURE — 1 row returned |
| **`fill_price <= 0`** | `R_BAD_MATH` trade seq 1 (-10.0) | FAILURE — 1 row returned |
| **Missing required fields** | `R_NULLS` | FAILURE — 8 rows across 8 distinct queries |
| **Non-positive `metric_initial_cash`** | `R_ZERO_CASH` (0.0) | FAILURE — 1 row returned |
| **Zero actual trades** | `R_ZERO_FILL`, `R_NULLS` | INFORMATIONAL — identifies runs with zero actual trade rows |
| **Negative fitness** | `C_BAD_FIT` (-5.0) | FAILURE — 1 row returned |
| **Global Returns (`MAX`, `AVG`, `MIN`)** | All `backtest_runs` rows | INFORMATIONAL — summary row |
| **Invalid `num_bars_processed`** | `R_NULLS`, `R_BAD_MATH` (-10) | FAILURE — 2 rows returned |
| **Unsupported timeframe** | `R_BAD_MATH` (`7d`), `R_BAD_TF` (`2d`), `R_NULLS` (`NULL`) | FAILURE — 3 rows returned |
| **Annualized Return mismatch** | `R_ANN_ERR` (reported: 99.9, calculated: 10.0) | FAILURE — 1 row returned |
| **Valid control case** | `R_VALID` (total return: 10.0, annualized return: 10.0) | PASS — reconciliation successful |
| **Path-dependent risk metrics** | Sharpe, Sortino, annualized volatility, maximum drawdown, drawdown duration | NOT INDEPENDENTLY VALIDATABLE — requires per-bar equity curve |

## Private Snapshot Validation

The same validation framework was also applied to the private sanitized snapshot supplied for the issue.

The private snapshot contained:

- 57 strategy candidates
- 56 completed backtest runs
- 1,425 simulated fills
- 44 runs containing fills
- 12 runs without fills
- 53 candidates with a latest backtest run reference

These results are **private snapshot findings only**. They are not independently reproduced by the public synthetic fixture and should not be interpreted as proof of the underlying engine's calculations.

The public repository contains only the reproducible validation logic and synthetic data required to exercise the checks. Private CSV rows, PBIX files, internal identifiers, account information, credentials, and production connection details are excluded.
