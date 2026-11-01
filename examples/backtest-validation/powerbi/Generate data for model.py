import os
import sys
import pandas as pd
from datetime import datetime, timedelta
import json

def generate_powerbi_dataset():
    output_dir = "fixture_output"
    
    if os.path.exists(output_dir):
        print(f"Error: The directory '{output_dir}' already exists.")
        print("Please delete or rename it to prevent overwriting existing data.")
        sys.exit(1)
        
    os.makedirs(output_dir)

    configs = [
        {"symbol": "BTC/USDT", "timeframe": "1h", "venue": "binance", "strategy_kind": "trend_following"},
        {"symbol": "ETH/USDT", "timeframe": "4h", "venue": "binance", "strategy_kind": "mean_reversion"},
        {"symbol": "SOL/USDT", "timeframe": "1d", "venue": "binance", "strategy_kind": "breakout"},
        {"symbol": "AAPL", "timeframe": "1d", "venue": "baostock", "strategy_kind": "stat_arb"},
        {"symbol": "MSFT", "timeframe": "1d", "venue": "baostock", "strategy_kind": "mean_reversion"}
    ]

    candidates = []
    runs = []
    trades = []

    global_run_counter = 1
    
    for c_idx in range(1, 6):
        candidate_key = f'C{c_idx:03d}'
        c_status = 'active' if c_idx % 2 != 0 else 'archived'
        
        candidates.append({
            'candidate_key': candidate_key,
            'status': c_status,
            'author': f'algo_dev_{c_idx}',
            'fitness': 1.0 + (c_idx * 0.25),
            'last_backtest_run_key': '',
            'created_at_utc': '2023-01-01T10:00:00Z',
            'updated_at_utc': '2023-01-02T10:00:00Z'
        })
        
        for r_idx in range(1, 3):
            run_key = f'R{global_run_counter:03d}'
            candidates[-1]['last_backtest_run_key'] = run_key 
            
            config = configs[(global_run_counter - 1) % len(configs)]
            initial_cash = 10000.00 + (global_run_counter * 1000.00)
            num_trades = 10 
            
            run_trades = []
            run_fees = 0.0
            run_start_date = datetime(2023, 1, 1, 0, 0, 0) + timedelta(days=(global_run_counter - 1) * 15)
            pnl_pattern = [28.0, 42.0, -18.0, 35.0, 15.0]
            
            for seq in range(1, num_trades + 1):
                trade_dt = run_start_date + timedelta(days=seq - 1)
                bar_ts_utc = trade_dt.strftime('%Y-%m-%dT%H:%M:%SZ')
                is_entry = (seq % 2 != 0)
                intent = 'entry' if is_entry else 'exit'
                side = 'buy' if is_entry else 'sell'
                
                bar_close = 100.0 + (global_run_counter * 10) + seq
                qty = 0.5 + (seq * 0.1)
                fill_price = bar_close
                fee = round(qty * fill_price * 0.001, 2)
                
                if is_entry:
                    realized_pnl = 0.0
                else:
                    exit_idx = (seq // 2) - 1
                    base_pnl = pnl_pattern[exit_idx % len(pnl_pattern)]
                    realized_pnl = base_pnl * (1.0 + (global_run_counter * 0.05))
                    
                realized_pnl = round(realized_pnl, 2)
                
                run_trades.append({
                    'run_key': run_key,
                    'seq': seq,
                    'bar_ts_utc': bar_ts_utc,
                    'bar_close': bar_close,
                    'side': side,
                    'quantity': round(qty, 4),
                    'order_type': 'limit' if seq % 3 == 0 else 'market',
                    'fill_price': fill_price,
                    'fee': fee,
                    'realized_pnl': realized_pnl,
                    'intent': intent
                })
                run_fees += fee
                
            trades.extend(run_trades)
            
            total_pnl = sum([t['realized_pnl'] for t in run_trades])
            expected_final_eq = initial_cash + total_pnl - run_fees
            final_eq = expected_final_eq
            
            if run_key == "R002":
                final_eq += 50.0 
                
            # FIX: Calculate return and immediately lock in the 6-decimal rounding
            ret_pct = round((final_eq - initial_cash) / initial_cash * 100, 6)
            
            all_realized = [t['realized_pnl'] for t in run_trades if t['realized_pnl'] != 0]
            winning_trades = [p for p in all_realized if p > 0]
            win_rate = len(winning_trades) / len(all_realized) if all_realized else 0.0
            best_pnl = max(all_realized) if all_realized else 0.0
            worst_pnl = min(all_realized) if all_realized else 0.0
            
            num_bars = 1000 + (global_run_counter * 100)
            if config['venue'] == 'binance':
                if config['timeframe'] == '1h':
                    bars_per_year = 365 * 24
                elif config['timeframe'] == '4h':
                    bars_per_year = 365 * 6
                else:
                    bars_per_year = 365
            else:
                bars_per_year = 252
                
            # FIX: Calculate annualized return strictly from the already-rounded ret_pct to prevent SQL tolerance failure
            annualized_return_pct = round(ret_pct * (bars_per_year / num_bars), 6)
            
            runs.append({
                'run_key': run_key,
                'candidate_key': candidate_key,
                'strategy_kind': config['strategy_kind'],
                'status': 'completed',
                'venue': config['venue'],
                'symbol': config['symbol'],
                'timeframe': config['timeframe'],
                'from_ts_utc': run_trades[0]['bar_ts_utc'],
                'to_ts_utc': run_trades[-1]['bar_ts_utc'],
                'initial_cash': initial_cash,
                'fee_rate': 0.001,
                'params_json': json.dumps({"risk": 0.02, "sl": 0.05}),
                'num_bars_processed': num_bars,
                'reported_num_trades': num_trades,
                'metric_initial_cash': initial_cash,
                'final_equity': round(final_eq, 2),
                'total_return_pct': ret_pct,
                'annualized_return_pct': annualized_return_pct,
                'annualized_volatility_pct': 15.0 + global_run_counter,
                'max_drawdown_pct': -5.0 - (global_run_counter * 0.5),
                'sharpe': round(1.0 + (global_run_counter * 0.1), 2),
                'sortino': round(1.2 + (global_run_counter * 0.1), 2),
                'calmar': round(0.8 + (global_run_counter * 0.1), 2),
                'win_rate': round(win_rate, 4),
                'profit_factor': round(1.5 + (global_run_counter * 0.05), 2),
                'payoff_ratio': round(1.2 + (global_run_counter * 0.05), 2),
                'expectancy': round(5.0 + global_run_counter, 2),
                'exposure_pct': round(45.0 + (global_run_counter * 2.0), 2),
                'total_fees': round(run_fees, 2),
                'best_trade_pnl': best_pnl,
                'worst_trade_pnl': worst_pnl,
                'max_consecutive_wins': 3,
                'max_consecutive_losses': 1,
                'max_drawdown_duration_bars': 20 + global_run_counter,
                'fitness': round(1.0 + (global_run_counter * 0.2), 2),
                'validation_json': json.dumps({"structural_checks_passed": True, "metrics_validated": False}),
                'created_at_utc': '2023-01-01T10:00:00Z',
                'updated_at_utc': '2023-01-02T10:00:00Z'
            })
            global_run_counter += 1

    c_df = pd.DataFrame(candidates)
    r_df = pd.DataFrame(runs)
    t_df = pd.DataFrame(trades)

    # Automatically map the exact math for R002 to the exception dataset
    exceptions = [{
        "run_key": "R002",
        "check_name": "equity_consistency_check",
        "status": "failed",
        "details": "Equity mismatch detected: expected 12110.87, actual 12160.87"
    }]
    e_df = pd.DataFrame(exceptions)
    
    e_df.to_csv(os.path.join(output_dir, "validation_exceptions.csv"), index=False)
    c_df.to_csv(os.path.join(output_dir, "candidates.csv"), index=False)
    r_df.to_csv(os.path.join(output_dir, "backtest_runs.csv"), index=False)
    t_df.to_csv(os.path.join(output_dir, "backtest_trades.csv"), index=False)

    print(f"Power BI synthetic dataset generated successfully in '{output_dir}/'.\n")

if __name__ == "__main__":
    generate_powerbi_dataset()
