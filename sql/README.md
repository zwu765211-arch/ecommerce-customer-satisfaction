# SQL workflow

Target: MySQL 8.0.16 or later. Use a fresh `olist_ecommerce` database and one connection for setup and loading.

Run in this order:

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

Expected final row counts: customers 99,441; products 32,951; orders 99,441; order_items 112,650; reviews 98,673 (latest retained review per order).

Reporting window: purchases from 2017-01-01 inclusive to 2018-09-01 exclusive. Item sales exclude freight and do not represent company revenue or profit. Review comparisons are descriptive; inspect timing sensitivity before interpreting them.

Upload review: CSV header order was checked against the notebook exports. The setup migration that ran before table creation was removed, loading transaction boundaries were clarified, and personal absolute paths were replaced. These SQL scripts have not been executed against a MySQL server in this environment; result comments are supplied snapshot baselines, not newly verified SQL outputs.
