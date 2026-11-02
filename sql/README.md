# SQL workflow

Target: MySQL 8.0.16 or later. Use a fresh `olist_ecommerce` database and one connection for setup and loading.

## Execution order

1. `00_database_setup.sql` — connection checks and database setup.
2. `01_create_tables.sql` — five final tables, keys and constraints.
3. `01-1_load_clean_csv.sql` — CSV staging, typed inserts and reconciliation.
4. `02_data_validation.sql` — row counts, grain, rules and join checks.
5. `03_create_analytic_views.sql` — order, item and monthly category views.
6. `04_sales_performance_analysis.sql` — sales and category analysis.
7. `05_delivery_performance.sql` — delivery duration, lateness and priorities.
8. `06_delivery_satisfaction.sql` — review coverage, delay comparisons and timing sensitivity.

Generate the five clean CSVs using `../notebooks/01_data_cleaning.ipynb`. Replace all five `/absolute/path/to/ecommerce-customer-satisfaction` prefixes in the loader with your local project path. LOCAL INFILE must be enabled in both the client and server.

Run the loader section by section. Stop on errors or warnings. After all INSERTs and reconciliation checks pass, run `COMMIT;` manually; otherwise run `ROLLBACK;`. Optional staging cleanup statements are commented out and should run only after a successful commit. This is a fresh-load workflow, not an idempotent reload or existing-schema migration.

## Verified results

The full workflow was executed on 3 November 2026 against a newly initialized MySQL 8.0.46 database using clean CSVs regenerated from the project notebook.

- All five staging-to-final reconciliation checks passed.
- All 56 checks reported by `02_data_validation.sql` passed.
- The analytic views reconciled exactly to their source tables.
- Scripts `04`, `05`, and `06` completed without MySQL errors or warnings.
- Committed row counts persisted as: customers 99,441; products 32,951; orders 99,441; order_items 112,650; reviews 98,673.
- Delivered-order KPIs reconciled to 96,211 orders, BRL 13,181,027.13 item sales, and BRL 137.00 item AOV.

Machine-readable outputs are stored in [`../reports/sql_validation/`](../reports/sql_validation/).

## Analytical scope

The reporting window covers purchases from 2017-01-01 inclusive to 2018-09-01 exclusive. Item sales exclude freight and do not represent company revenue or profit. Review comparisons are descriptive; inspect timing sensitivity before interpreting them.
