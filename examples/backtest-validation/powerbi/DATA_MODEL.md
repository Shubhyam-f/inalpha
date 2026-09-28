# Power BI Data Model

This document describes the Power BI analytical model used for the Inalpha
backtest validation prototype.

The Power BI model is an **analytical and exploration layer**. It is not the
primary validation engine. Data-quality and consistency validation is performed
independently through the SQLite validation queries documented in
[`../sql/validation_checks.sql`](../sql/validation_checks.sql).

---

## Model Overview

The Power BI model uses three primary tables:

```text
candidates
    │
    │ 1 → *
    ▼
backtest_runs
    │
    │ 1 → *
    ▼
backtest_trades
```

The model follows the underlying data relationships:

- one candidate can have multiple backtest runs;
- one backtest run can have multiple trade/fill records.

This creates a simple parent-to-child analytical structure from strategy
candidate → backtest run → trade/fill.

---

## Tables

### `candidates`

The `candidates` table represents strategy candidates.

Relevant fields visible in the model include:

- `candidate_key`
- `author`
- `created_at_utc`
- `fitness`
- `last_backtest_run_key`
- `status`

`candidate_key` is the candidate-level identifier used to relate candidates to
their associated backtest runs.

---

### `backtest_runs`

The `backtest_runs` table represents individual backtest executions associated
with a strategy candidate.

Fields visible in the model include, among others:

- `candidate_key`
- `created_at_utc`
- `expectancy`
- `exposure_pct`
- `fee_rate`
- `final_equity`
- `finished_at_utc`
- `fitness`
- `from_ts_utc`
- `initial_cash`
- `max_consecutive_losses`
- `max_consecutive_wins`

The table also contains the run-level performance, risk, configuration, and
validation fields used by the analytical layer.

`candidate_key` connects each run to its parent candidate.

---

### `backtest_trades`

The `backtest_trades` table contains individual simulated fill/trade records
belonging to a backtest run.

Fields visible in the model include:

- `bar_close`
- `bar_ts_utc`
- `fee`
- `fill_price`
- `intent`
- `order_type`
- `quantity`
- `realized_pnl`
- `run_key`
- `seq`
- `side`

The `realized_pnl` field is the basis of the custom Power BI measure used for
gross realized P&L analysis.

`run_key` connects each trade/fill record to its parent backtest run.

---

## Relationships

### Candidates → Backtest Runs

**Relationship:**

```text
candidates[candidate_key]
        1
        │
        │
        *
backtest_runs[candidate_key]
```

**Cardinality:** `1:*`

A single candidate can therefore be associated with multiple backtest runs.

This allows candidate-level filtering to propagate to the corresponding
backtest runs.

---

### Backtest Runs → Backtest Trades

**Relationship:**

```text
backtest_runs[run_key]
        1
        │
        │
        *
backtest_trades[run_key]
```

**Cardinality:** `1:*`

A single backtest run can contain multiple trade/fill records.

This allows a selected run to filter its associated trade/fill records for
detailed analysis.

---

## Filter Direction

The model uses parent-to-child filtering:

```text
candidates
    ↓
backtest_runs
    ↓
backtest_trades
```

This allows selections at a higher level of the model to narrow the
corresponding lower-level records.

For example:

```text
Candidate
   ↓
Backtest Run
   ↓
Trade / Fill
```

Selecting a candidate can therefore restrict the available runs and their
associated trades. Selecting a run can restrict the analysis to the fills
belonging to that run.

---

## Analytical Flow

The model is designed around the following analytical path:

### 1. Candidate level

Identify a strategy candidate and inspect its associated runs.

### 2. Backtest-run level

Select an individual backtest run and inspect its run-level characteristics
and performance.

### 3. Trade/fill level

Inspect the individual fills belonging to the selected run, including:

- sequence;
- side;
- intent;
- order type;
- quantity;
- fill price;
- fees;
- realized P&L.

This structure allows the Power BI report to move from higher-level strategy
analysis toward the underlying simulated trading activity.

---

## Role of the Model in the Validation Workflow

Power BI is intentionally **not** responsible for reproducing the SQL
validation layer.

The workflow is:

```text
Synthetic / imported data
          │
          ▼
     SQLite validation
          │
          │
          ├── data-quality checks
          ├── relationship checks
          ├── metric consistency checks
          └── annualization checks
          │
          ▼
      Analytical data
          │
          ▼
       Power BI
          │
          ├── filtering
          ├── aggregation
          ├── decomposition
          ├── visualization
          └── drill-through analysis
```

The SQL layer is therefore responsible for determining whether the underlying
data passes the defined validation checks.

Power BI is used to explore and analyze the resulting candidate, run, and
trade data.

---

## Design Rationale

The three-table model mirrors the underlying relational structure rather than
flattening all records into a single table.

This preserves the natural hierarchy:

```text
Candidate
    └── Backtest Run
          └── Trade / Fill
```

This structure is particularly useful for tracing aggregate realized P&L back
to the run and candidate from which the underlying fills originated.

---

## Scope

This model documentation describes the Power BI prototype used for analytical
exploration.

It does not claim that Power BI independently validates:

- reported trade counts;
- reported fees;
- cash consistency;
- total-return calculations;
- annualized-return calculations;
- required-field completeness;
- referential integrity.

Those checks are implemented separately in the SQL validation layer.
