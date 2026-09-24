# Power BI DAX

The confirmed prototype measure is recorded below. Additional measures should be exported from the final PBIX/model rather than reconstructed from memory.

```DAX
Realised pnl =
    backtest_runs[metric_initial_cash] - backtest_runs[final_equity]
```

**P&L convention:** Total Realized P&L is gross realized P&L from fills. Fees are separate and displayed as Total Fees.

