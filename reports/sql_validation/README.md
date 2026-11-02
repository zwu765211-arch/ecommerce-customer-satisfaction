# SQL validation evidence

These TSV files contain the query outputs from a complete fresh-database run on MySQL 8.0.46 on 3 November 2026.

The run regenerated all five clean CSVs from the notebook, executed the SQL files in documented order, committed the load after reconciliation, and then reran the final row counts to confirm persistence.

## Outcome

| Check | Result |
| --- | --- |
| Staging-to-final reconciliation | 5/5 PASS |
| Data validation queries | 56 PASS, 0 FAIL |
| Order summary view | 99,441 rows and 99,441 unique orders |
| Item-detail view | 112,650 rows and zero sales difference |
| Category-sales view | Exact item, sales, and freight reconciliation |
| Analysis scripts 04–06 | Completed without MySQL errors or warnings |
| Final persisted row counts | Matched all five expected counts |

Key reporting-window results: 96,211 delivered orders, BRL 13,181,027.13 item sales, BRL 137.00 item AOV, 96,203 delivery-eligible orders, 6.79% late rate, 12.54 average exact delivery days, and 99.33% review coverage.

Each TSV preserves the tabular output of its corresponding SQL script. `persistence_counts.tsv` records the post-commit final table counts.
