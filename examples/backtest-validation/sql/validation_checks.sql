-- Inalpha Issue #165 — Strategy-to-backtest validation
-- Reproducible SQLite validation checks


-- 1. Duplicate candidate keys

SELECT
    'VALIDATION FAILURE: duplicate candidate keys' AS validation_check,
    candidate_key,
    COUNT(*) AS candidate_count
FROM candidates
GROUP BY candidate_key
HAVING COUNT(*) > 1;


-- 2. Duplicate run keys

SELECT
    'VALIDATION FAILURE: duplicate run keys' AS validation_check,
    run_key,
    COUNT(*) AS run_count
FROM backtest_runs
GROUP BY run_key
HAVING COUNT(*) > 1;


-- 3. Duplicate fill keys

SELECT
    'VALIDATION FAILURE: duplicate fill keys' AS validation_check,
    run_key,
    seq,
    COUNT(*) AS fill_count
FROM backtest_trades
GROUP BY run_key, seq
HAVING COUNT(*) > 1;


-- 4. Candidate without a backtest run

SELECT
    'VALIDATION FAILURE: candidate without backtest run' AS validation_check,
    c.candidate_key
FROM candidates c
LEFT JOIN backtest_runs r
    ON r.candidate_key = c.candidate_key
WHERE r.run_key IS NULL;


-- 5. Run without a candidate

SELECT
    'VALIDATION FAILURE: run without candidate' AS validation_check,
    r.run_key,
    r.candidate_key
FROM backtest_runs r
LEFT JOIN candidates c
    ON r.candidate_key = c.candidate_key
WHERE c.candidate_key IS NULL;


-- 6. Fill without a backtest run

SELECT
    'VALIDATION FAILURE: fill without backtest run' AS validation_check,
    t.run_key
FROM backtest_trades t
LEFT JOIN backtest_runs r
    ON t.run_key = r.run_key
WHERE r.run_key IS NULL;


-- 7. Reported trade count vs actual fill count

SELECT
    'VALIDATION FAILURE: reported trade count mismatch' AS validation_check,
    r.run_key,
    r.reported_num_trades,
    COUNT(t.run_key) AS actual_fill_count
FROM backtest_runs r
LEFT JOIN backtest_trades t
    ON r.run_key = t.run_key
GROUP BY r.run_key, r.reported_num_trades
HAVING COUNT(t.run_key) <> r.reported_num_trades;


-- 8. Reported fees vs calculated fill-level fees

SELECT
    'VALIDATION FAILURE: total fees mismatch' AS validation_check,
    r.run_key,
    r.total_fees,
    COALESCE(SUM(t.fee), 0) AS calculated_fees
FROM backtest_runs r
LEFT JOIN backtest_trades t
    ON r.run_key = t.run_key
GROUP BY r.run_key, r.total_fees
HAVING ABS(r.total_fees - COALESCE(SUM(t.fee), 0)) > 0.00000001;


-- 9. Initial cash vs metric initial cash

SELECT
    'VALIDATION FAILURE: initial cash mismatch' AS validation_check,
    run_key,
    initial_cash,
    metric_initial_cash,
    initial_cash - metric_initial_cash AS difference
FROM backtest_runs
WHERE ABS(initial_cash - metric_initial_cash) > 0.00000001;


-- 10. Total return reconciliation

SELECT
    'VALIDATION FAILURE: total return mismatch' AS validation_check,
    run_key,
    total_return_pct,
    (
        (CAST(final_equity AS REAL) - CAST(metric_initial_cash AS REAL))
        / CAST(metric_initial_cash AS REAL)
    ) * 100.0 AS calculated_return_pct
FROM backtest_runs
WHERE ABS(
    total_return_pct -
    (
        (
            CAST(final_equity AS REAL) - CAST(metric_initial_cash AS REAL)
        )
        / CAST(metric_initial_cash AS REAL)
    ) * 100.0
) > 0.000001;


-- 11. Invalid backtest date range

SELECT
    'VALIDATION FAILURE: invalid backtest date range' AS validation_check,
    run_key,
    from_ts_utc,
    to_ts_utc
FROM backtest_runs
WHERE to_ts_utc <= from_ts_utc;


-- 12. Negative fee rate

SELECT
    'VALIDATION FAILURE: negative fee rate' AS validation_check,
    run_key,
    fee_rate
FROM backtest_runs
WHERE fee_rate < 0;


-- 13. Non-positive trade quantity

SELECT
    'VALIDATION FAILURE: non-positive trade quantity' AS validation_check,
    *
FROM backtest_trades
WHERE quantity <= 0;


-- 14. Non-positive fill price

SELECT
    'VALIDATION FAILURE: non-positive fill price' AS validation_check,
    *
FROM backtest_trades
WHERE fill_price IS NOT NULL
  AND fill_price <= 0;


-- Required fields and invalid denominators


-- 15. Missing initial cash

SELECT
    'VALIDATION FAILURE: missing initial_cash' AS validation_check,
    run_key,
    'missing initial_cash' AS validation_error
FROM backtest_runs
WHERE initial_cash IS NULL;


-- 16. Missing total return

SELECT
    'VALIDATION FAILURE: missing total_return_pct' AS validation_check,
    run_key,
    'missing total_return_pct' AS validation_error
FROM backtest_runs
WHERE total_return_pct IS NULL;


-- 17. Missing metric initial cash

SELECT
    'VALIDATION FAILURE: missing metric_initial_cash' AS validation_check,
    run_key,
    'missing metric_initial_cash' AS validation_error
FROM backtest_runs
WHERE metric_initial_cash IS NULL;


-- 18. Non-positive metric initial cash

SELECT
    'VALIDATION FAILURE: non-positive metric_initial_cash' AS validation_check,
    run_key,
    'non-positive metric_initial_cash' AS validation_error
FROM backtest_runs
WHERE metric_initial_cash <= 0;


-- 19. Missing reported trade count

SELECT
    'VALIDATION FAILURE: missing reported_num_trades' AS validation_check,
    run_key,
    'missing reported_num_trades' AS validation_error
FROM backtest_runs
WHERE reported_num_trades IS NULL;


-- 20. Missing total fees

SELECT
    'VALIDATION FAILURE: missing total_fees' AS validation_check,
    run_key,
    'missing total_fees' AS validation_error
FROM backtest_runs
WHERE total_fees IS NULL;


-- 21. Missing final equity

SELECT
    'VALIDATION FAILURE: missing final_equity' AS validation_check,
    run_key,
    'missing final_equity' AS validation_error
FROM backtest_runs
WHERE final_equity IS NULL;


-- 22. Missing timeframe

SELECT
    'VALIDATION FAILURE: missing timeframe' AS validation_check,
    run_key,
    'missing timeframe' AS validation_error
FROM backtest_runs
WHERE timeframe IS NULL;


-- 23. Missing processed bar count

SELECT
    'VALIDATION FAILURE: missing num_bars_processed' AS validation_check,
    run_key,
    'missing num_bars_processed' AS validation_error
FROM backtest_runs
WHERE num_bars_processed IS NULL;


-- 24. Runs with zero actual trade rows
-- Informational: zero-fill runs can be legitimate.

SELECT
    'INFORMATIONAL: run has zero actual trade rows' AS validation_check,
    r.run_key,
    r.reported_num_trades,
    r.total_return_pct,
    r.total_fees
FROM backtest_runs r
LEFT JOIN backtest_trades t
    ON r.run_key = t.run_key
GROUP BY
    r.run_key,
    r.reported_num_trades,
    r.total_return_pct,
    r.total_fees
HAVING COUNT(t.run_key) = 0;


-- 25. Negative fitness

SELECT
    'VALIDATION FAILURE: negative fitness' AS validation_check,
    candidate_key,
    fitness
FROM candidates
WHERE fitness < 0;


-- 26. Global return summary
-- Informational: descriptive summary, not a validation failure.

SELECT
    'INFORMATIONAL: global return summary' AS validation_check,
    MAX(total_return_pct) AS maximum_return,
    AVG(total_return_pct) AS average_return,
    MIN(total_return_pct) AS minimum_return
FROM backtest_runs;


-- Annualization: invalid bar counts


SELECT
    'VALIDATION FAILURE: missing or non-positive num_bars_processed' AS validation_check,
    run_key,
    'missing or non-positive num_bars_processed' AS validation_error
FROM backtest_runs
WHERE num_bars_processed IS NULL
   OR num_bars_processed <= 0;


-- Annualization: unsupported timeframe


SELECT
    'VALIDATION FAILURE: unsupported timeframe for annualization' AS validation_check,
    run_key,
    timeframe,
    'unsupported timeframe for annualization' AS validation_error
FROM backtest_runs
WHERE timeframe IS NULL
   OR timeframe NOT IN (
       '1m', '3m', '5m', '15m', '30m',
       '1h', '2h', '4h', '6h', '8h', '12h',
       '1d', '3d', '1w', '1M'
   );


-- Annualization: non-crypto runs without an exchange-calendar factor
-- Informational: these runs are not independently checkable from the
-- crypto annualization factors alone.
--
-- A valid exchange-calendar factor must be supplied before these runs
-- can be reconciled.

SELECT
    'INFORMATIONAL: non-crypto annualization uncheckable without exchange-calendar factor' AS validation_check,
    run_key,
    venue,
    timeframe,
    num_bars_processed,
    total_return_pct,
    annualized_return_pct,
    'exchange-calendar annualization factor required' AS validation_status
FROM backtest_runs
WHERE LOWER(COALESCE(venue, '')) <> 'crypto'
  AND num_bars_processed > 0
  AND total_return_pct IS NOT NULL
  AND annualized_return_pct IS NOT NULL;


-- Annualization: crypto reported value vs calculated value
--
-- Crypto uses 24/7 annualization factors.
-- Formula:
-- annualized_return_pct =
-- total_return_pct * annualization_factor / num_bars_processed
--
-- This is linear annualization, not CAGR.


SELECT
    'VALIDATION FAILURE: annualized return mismatch' AS validation_check,
    r.run_key,
    r.venue,
    r.timeframe,
    r.num_bars_processed,
    r.total_return_pct,
    r.annualized_return_pct,
    ROUND(
        r.total_return_pct *
        af.annualization_factor /
        (r.num_bars_processed * 1.0),
        4
    ) AS calculated_annualized_return_pct
FROM backtest_runs r
JOIN (
    SELECT '1m' AS timeframe, 525600 AS annualization_factor
    UNION ALL SELECT '3m', 175200
    UNION ALL SELECT '5m', 105120
    UNION ALL SELECT '15m', 35040
    UNION ALL SELECT '30m', 17520
    UNION ALL SELECT '1h', 8760
    UNION ALL SELECT '2h', 4380
    UNION ALL SELECT '4h', 2190
    UNION ALL SELECT '6h', 1460
    UNION ALL SELECT '8h', 1095
    UNION ALL SELECT '12h', 730
    UNION ALL SELECT '1d', 365
    UNION ALL SELECT '3d', 121
    UNION ALL SELECT '1w', 52
    UNION ALL SELECT '1M', 12
) af
    ON r.timeframe = af.timeframe
WHERE LOWER(COALESCE(r.venue, '')) = 'crypto'
  AND r.num_bars_processed > 0
  AND r.total_return_pct IS NOT NULL
  AND r.annualized_return_pct IS NOT NULL
  AND ABS(
      r.annualized_return_pct -
      (
          r.total_return_pct *
          af.annualization_factor /
          (r.num_bars_processed * 1.0)
      )
  ) > 0.000001;
