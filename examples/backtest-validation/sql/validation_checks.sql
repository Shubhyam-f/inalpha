-- Inalpha Issue #165 — Strategy-to-backtest validation
-- Reproducible SQLite validation checks

SELECT candidate_key, COUNT(*) AS candidate_count FROM candidates GROUP BY candidate_key HAVING COUNT(*) > 1;
SELECT run_key, COUNT(*) AS run_count FROM backtest_runs GROUP BY run_key HAVING COUNT(*) > 1;
SELECT run_key, seq, COUNT(*) AS fill_count FROM backtest_trades GROUP BY run_key, seq HAVING COUNT(*) > 1;

SELECT c.candidate_key FROM candidates c LEFT JOIN backtest_runs r ON r.candidate_key = c.candidate_key WHERE r.run_key IS NULL;
SELECT r.run_key, r.candidate_key FROM backtest_runs r LEFT JOIN candidates c ON r.candidate_key = c.candidate_key WHERE c.candidate_key IS NULL;
SELECT t.run_key FROM backtest_trades t LEFT JOIN backtest_runs r ON t.run_key = r.run_key WHERE r.run_key IS NULL;

SELECT r.run_key, r.reported_num_trades, COUNT(t.run_key) AS actual_fill_count
FROM backtest_runs r LEFT JOIN backtest_trades t ON r.run_key = t.run_key
GROUP BY r.run_key, r.reported_num_trades
HAVING COUNT(t.run_key) <> r.reported_num_trades;

SELECT r.run_key, r.total_fees, COALESCE(SUM(t.fee), 0) AS calculated_fees
FROM backtest_runs r LEFT JOIN backtest_trades t ON r.run_key = t.run_key
GROUP BY r.run_key, r.total_fees
HAVING ABS(r.total_fees - COALESCE(SUM(t.fee), 0)) > 0.00000001;

SELECT run_key, initial_cash, metric_initial_cash, initial_cash - metric_initial_cash AS difference
FROM backtest_runs
WHERE ABS(initial_cash - metric_initial_cash) > 0.00000001;

SELECT run_key, total_return_pct,
       ((final_equity - metric_initial_cash) / metric_initial_cash) * 100 AS calculated_return_pct
FROM backtest_runs
WHERE ABS(total_return_pct - (((final_equity - metric_initial_cash) / metric_initial_cash) * 100)) > 0.000001;

SELECT run_key, from_ts_utc, to_ts_utc FROM backtest_runs WHERE to_ts_utc <= from_ts_utc;
SELECT run_key, fee_rate FROM backtest_runs WHERE fee_rate < 0;
SELECT * FROM backtest_trades WHERE quantity <= 0;
SELECT * FROM backtest_trades WHERE fill_price IS NOT NULL AND fill_price <= 0;

-- Required fields and invalid denominators

SELECT run_key, 'missing metric_initial_cash' AS validation_error
FROM backtest_runs
WHERE metric_initial_cash IS NULL;

SELECT run_key, 'non-positive metric_initial_cash' AS validation_error
FROM backtest_runs
WHERE metric_initial_cash <= 0;

SELECT run_key, 'missing reported_num_trades' AS validation_error
FROM backtest_runs
WHERE reported_num_trades IS NULL;

SELECT run_key, 'missing total_fees' AS validation_error
FROM backtest_runs
WHERE total_fees IS NULL;

SELECT run_key, 'missing final_equity' AS validation_error
FROM backtest_runs
WHERE final_equity IS NULL;

SELECT run_key, 'missing timeframe' AS validation_error
FROM backtest_runs
WHERE timeframe IS NULL;

SELECT run_key, 'missing num_bars_processed' AS validation_error
FROM backtest_runs
WHERE num_bars_processed IS NULL;
---     ---
SELECT r.run_key, r.reported_num_trades, r.total_return_pct, r.total_fees
FROM backtest_runs r LEFT JOIN backtest_trades t ON r.run_key = t.run_key
GROUP BY r.run_key, r.reported_num_trades, r.total_return_pct, r.total_fees
HAVING COUNT(t.run_key) = 0;

SELECT candidate_key, fitness FROM candidates WHERE fitness < 0;
SELECT MAX(total_return_pct) AS maximum_return, AVG(total_return_pct) AS average_return, MIN(total_return_pct) AS minimum_return FROM backtest_runs;
