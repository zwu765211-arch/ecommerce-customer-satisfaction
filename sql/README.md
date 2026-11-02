# SQL workflow

Target: MySQL 8.0.16 or later. Use a fresh `olist_ecommerce` database and one connection for setup and loading.

## Notebook inputs

Install the notebook dependencies from the project root with `python3 -m pip install -r requirements.txt`. This lists the required packages; exact package versions are not locked.

Place these six Kaggle source files in `data/raw/`:

- `olist_orders_dataset.csv`
- `olist_order_items_dataset.csv`
- `olist_order_reviews_dataset.csv`
- `olist_products_dataset.csv`
- `olist_customers_dataset.csv`
- `product_category_name_translation.csv`

Run all notebook cells from `notebooks/`. If the saved `ecommerce-analysis` kernel is unavailable, select the Python kernel for the environment where the dependencies were installed.

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

## Tableau and final-brief reproducibility

The packaged workbook and [final brief](../reports/Olist_Analytical_Brief_Final.pdf) are saved deliverables. The brief uses the order-summary and order-item CSVs packaged in the workbook. Running the notebook and SQL scripts does not automatically rebuild those workbook CSVs or refresh Tableau.

The committed SQL outputs support the main sales, delivery and review baselines. Script 06 currently groups severe delays as `8+ days late`; it does not separately reproduce the brief's `8–14 days` and `15+ days` review-timing rows. Reproducing those rows requires those two delay groups with the same purchase window, delivery eligibility and review-response timing rule. A scripted workbook-export step and saved outputs for those finer groups remain future work.

The notebook removes review text from the cleaned review table. The brief's proposed review-text classification would therefore require returning to the original review CSV and is not an implemented analysis.
