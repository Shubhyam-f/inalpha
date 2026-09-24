# Inalpha — Strategy & Backtest Validation and Power BI Prototype

## 1. Validation

Validation was performed in two environments:
- **Excel** — exploratory and record-level validation
- **SQLite** — reproducible SQL-based validation

The validation focuses on data integrity, relationships, metric reconciliation, data quality, and potential anomalies within the sanitized dataset.

### 1.1 Excel validation

#### Backtest window duration

**Check:** `to_ts_utc > from_ts_utc`.

**Result:** PASS — all observed runs have a positive testing interval.

#### Return reconciliation

**Convention:**

```text
calculated_return = (final_equity - metric_initial_cash) / metric_initial_cash
```

`total_return_pct` is stored as a percentage, so the reported value is divided by 100 when compared with the decimal Excel calculation.

**Result:** PASS — observed returns reconcile with the documented convention.

#### Fee reconciliation

The sum of fill-level `fee` values reconciles to reported `total_fees`. Result: PASS.

#### Trade/fill count

`reported_num_trades` reconciles to the number of fill records for the corresponding run. Result: PASS for observed runs.

#### Duplicate fill/sequence check

Fill uniqueness is defined by `(run_key, seq)`. The Excel check uses `COUNTIFS` over `run_key` and `seq`; the reproducible SQL form is provided below.

### 1.2 Annualized return validation

The confirmed engine convention is **linear annualization, not CAGR**:

```text
years = num_bars_processed / annualization_periods
annualized_return_pct = total_return_pct / years
```

Supported crypto timeframes in the sanitized dataset:

| Timeframe | Bars/year |
|---|---:|
| 5m | 105,120 |
| 15m | 35,040 |
| 1h | 8,760 |
| 4h | 2,190 |
| 1d | 365 |

For non-crypto markets, the applicable annualization factor is derived from the relevant exchange/session calendar rather than assuming 24/7 trading.

Validation procedure: identify timeframe → select annualization factor → calculate years → calculate expected annualized return → compare with stored `annualized_return_pct` → investigate discrepancies.

## 2. SQLite validation

### 2.1 Candidate key uniqueness

```sql
SELECT candidate_key, COUNT(*) AS candidate_count
FROM candidates
GROUP BY candidate_key
HAVING COUNT(*) > 1;
```

Expected result: 0 rows.

### 2.2 Run key uniqueness

```sql
SELECT run_key, COUNT(*) AS run_count
FROM backtest_runs
GROUP BY run_key
HAVING COUNT(*) > 1;
```

Expected result: 0 rows.

### 2.3 Run key + sequence uniqueness

```sql
SELECT run_key, seq, COUNT(*) AS fill_count
FROM backtest_trades
GROUP BY run_key, seq
HAVING COUNT(*) > 1;
```

Expected result: 0 rows.

The live database defines `(run_key, seq)` as unique. This validation therefore confirms that the sanitized export preserves the expected uniqueness constraint rather than suggesting duplicate fills are permitted in the live database.

### 2.4 Candidate → Run: candidates without runs

```sql
SELECT c.candidate_key
FROM candidates c
LEFT JOIN backtest_runs r
  ON r.candidate_key = c.candidate_key
WHERE r.run_key IS NULL;
```

Candidate → run is **1:N**: one candidate can have multiple backtest runs.

### 2.5 Run → Candidate: broken references

```sql
SELECT r.run_key, r.candidate_key
FROM backtest_runs r
LEFT JOIN candidates c
  ON r.candidate_key = c.candidate_key
WHERE c.candidate_key IS NULL;
```

Expected result: 0 rows.

### 2.6 Fill → Run: broken references

```sql
SELECT t.run_key
FROM backtest_trades t
LEFT JOIN backtest_runs r
  ON t.run_key = r.run_key
WHERE r.run_key IS NULL;
```

Expected result: 0 rows.

### 2.7 Reported trade count vs actual fills

```sql
SELECT
    r.run_key,
    r.reported_num_trades,
    COUNT(t.run_key) AS actual_fill_count
FROM backtest_runs r
LEFT JOIN backtest_trades t
  ON r.run_key = t.run_key
GROUP BY r.run_key, r.reported_num_trades
HAVING COUNT(t.run_key) <> r.reported_num_trades;
```

`reported_num_trades` represents fill records in this dataset; it should not be interpreted as round-trip count.

### 2.8 Reported fees vs fill-level fees

```sql
SELECT
    r.run_key,
    r.total_fees,
    COALESCE(SUM(t.fee), 0) AS calculated_fees
FROM backtest_runs r
LEFT JOIN backtest_trades t
  ON r.run_key = t.run_key
GROUP BY r.run_key, r.total_fees
HAVING ABS(r.total_fees - COALESCE(SUM(t.fee), 0)) > 0.00000001;
```

Expected result: 0 rows.

`realized_pnl` is **gross realized P&L**. Fill-level `fee` is separate and is not included in `realized_pnl`.

### 2.9 Requested initial cash vs metric initial cash

```sql
SELECT
    run_key,
    initial_cash,
    metric_initial_cash,
    initial_cash - metric_initial_cash AS difference
FROM backtest_runs
WHERE ABS(initial_cash - metric_initial_cash) > 0.00000001;
```

`initial_cash` is requested/configured cash. `metric_initial_cash` is the portfolio-report value and is authoritative for independent validation of `total_return_pct`.

### 2.10 Reported return vs calculated return

```sql
SELECT
    run_key,
    total_return_pct,
    ((final_equity - metric_initial_cash) / metric_initial_cash) * 100
        AS calculated_return_pct
FROM backtest_runs
WHERE ABS(
    total_return_pct -
    (((final_equity - metric_initial_cash) / metric_initial_cash) * 100)
) > 0.000001;
```

Expected result: 0 rows.

### 2.11 Invalid backtest duration

```sql
SELECT run_key, from_ts_utc, to_ts_utc
FROM backtest_runs
WHERE to_ts_utc <= from_ts_utc;
```

Expected result: 0 rows.

### 2.12 Expected NULL behavior for nullable fields

Core run/fill fields are checked for unexpected NULLs. In `candidates`, `fitness` and `last_backtest_run_key` are nullable by design. The observed NULLs for candidates 3, 8, 13, and 14 are therefore expected behavior, not validation failures.

`last_backtest_run_key` is a soft reference to the latest run and is not the required candidate-to-run relationship.

### 2.13 Invalid fee rates

```sql
SELECT run_key, fee_rate
FROM backtest_runs
WHERE fee_rate < 0;
```

Expected result: 0 rows.

### 2.14 Non-positive quantities

```sql
SELECT *
FROM backtest_trades
WHERE quantity <= 0;
```

Expected result: 0 rows.

### 2.15 Non-positive fill prices

```sql
SELECT *
FROM backtest_trades
WHERE fill_price IS NOT NULL
  AND fill_price <= 0;
```

Expected result: 0 rows.

### 2.16 Runs with zero fills

```sql
SELECT
    r.run_key,
    r.reported_num_trades,
    r.total_return_pct,
    r.total_fees
FROM backtest_runs r
LEFT JOIN backtest_trades t
  ON r.run_key = t.run_key
GROUP BY r.run_key, r.reported_num_trades, r.total_return_pct, r.total_fees
HAVING COUNT(t.run_key) = 0;
```

Zero-fill runs should be investigated alongside their reported performance metrics rather than automatically treated as errors.

### 2.17 Negative fitness

```sql
SELECT candidate_key, fitness
FROM candidates
WHERE fitness < 0;
```

This is an anomaly-screening query, not a statement that negative fitness is inherently invalid.

### 2.18 Return summary

```sql
SELECT
    MAX(total_return_pct) AS maximum_return,
    AVG(total_return_pct) AS average_return,
    MIN(total_return_pct) AS minimum_return
FROM backtest_runs;
```

## 3. Metric reproducibility limitation

The sanitized dataset does not contain a per-bar equity curve. Therefore the following metrics cannot currently be independently reconstructed from the available data:

- Sharpe ratio
- Sortino ratio
- Annualized volatility
- Maximum drawdown
- Maximum drawdown duration

They should therefore be treated as **engine-reported values** rather than independently reproduced calculations from the current bundle.

Confirmed engine conventions:

- per-bar simple equity returns;
- annual risk-free rate = 0;
- Sharpe = mean excess return / sample standard deviation × √annualization factor;
- Sortino target = 0;
- annualized volatility = sample standard deviation of bar returns × √annualization factor × 100.

The conventions are documented, but the metrics remain non-reconstructable because the underlying per-bar equity path is absent.

### Minimum additional persisted dataset

A per-bar equity curve containing at minimum:

```text
run_id
bar_ts
equity
```

with `exposure` optionally included. This supplies the equity path needed for maximum drawdown and drawdown duration. Together with the confirmed risk-free-rate and annualization conventions, it also enables independent reconstruction of Sharpe, Sortino, and annualized volatility.

## 4. Power BI prototype

### Objective

The prototype focuses on strategy-to-backtest lineage and investigation: start with an aggregate result, progressively investigate dimensions, and reach the individual fill records contributing to that result.

### Data model

```text
Candidates (1) ──── (*) Backtest Runs (1) ──── (*) Backtest Trades
```

Conceptually: `Strategy Candidate → Backtest Run → Individual Fills`.

`last_backtest_run_key` is a soft latest-run reference and should not be treated as a second active relationship path.

### Lineage dashboard

A Decomposition Tree is the primary exploration mechanism. A user can begin with Total Realized P&L and progressively break down by Candidate → Run → Symbol → Timeframe → underlying records.

### Basic Details dashboard

The Basic Details page is connected through drill-through. After identifying an interesting candidate/run, use **Right-click → Drill through → Basic Details**.

Displayed information includes Total Realized P&L, Total Fees, Total Fills, Win Rate, Fitness, realized P&L across fill sequence, fee/price information, selected Candidate, and selected Run.

**P&L treatment:** Total Realized P&L is gross realized P&L from fills. Transaction fees are separate and Total Fees is displayed separately.

### Underlying data inspection

Power BI's **Explain Data Point by Data Table** can be used to inspect the sanitized records contributing to a selected result.

The decomposition-tree exploration should be performed before navigating to Basic Details so the intended filter context is carried into the drill-through page.

## 5. Current prototype scope

The prototype intentionally focuses on the core lineage and investigation workflow rather than extensive dashboard design.

```text
Aggregate Result
      ↓
Candidate
      ↓
Backtest Run
      ↓
Underlying Fill Records
      ↓
Detailed Run Analysis
```

## 6. Findings summary

1. The sanitized dataset supports reproducible validation of keys, relationships, fill counts, fees, initial-cash consistency, total return, timestamps, and selected data-quality conditions.
2. Candidate-to-run lineage is 1:N; `last_backtest_run_key` is a soft latest-run reference.
3. `metric_initial_cash` is authoritative for independent validation of `total_return_pct`; `initial_cash` remains a separate requested-vs-reported consistency check.
4. `realized_pnl` is gross realized P&L and fees are separate.
5. Annualized return uses the confirmed linear annualization convention, not CAGR.
6. Several risk/equity-path metrics remain engine-reported because the current bundle lacks a per-bar equity curve.
7. A per-bar equity curve is the minimum additional persisted dataset needed to close the primary equity-path lineage gap.
8. The Power BI prototype provides an aggregate-to-fill investigation workflow without requiring extensive dashboard design.
