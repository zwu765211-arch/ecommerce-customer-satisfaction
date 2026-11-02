# Olist E-Commerce Analytics
### Sales, Delivery Performance & Customer Satisfaction

An end-to-end analytics portfolio using **Python, MySQL and Tableau** to examine how sales performance, delivery reliability and customer reviews vary across the Brazilian Olist marketplace.

The project follows the data from raw CSV files through documented cleaning rules, a relational database, validated analytical views and an interactive Tableau workbook.

**[Download Tableau workbook](https://github.com/zwu765211-arch/ecommerce-customer-satisfaction/raw/refs/heads/main/Olist_Portfolio_Final_v5.twbx)** · **[Explore the cleaning notebook](notebooks/01_data_cleaning.ipynb)** · **[View SQL validation evidence](reports/sql_validation/README.md)**

## Business questions

- How do monthly sales, order volume and average order value change over time?
- Which product categories and customer states contribute most to item sales?
- Where are late deliveries concentrated, considering both rates and order volumes?
- How do review scores differ by delivery performance, and how does review timing affect that comparison?

## Results at a glance

The reporting window is **1 January 2017–31 August 2018**, based on purchase date. Sales metrics include delivered orders; delivery and review metrics use the eligible samples defined below.

| Metric | Result | Population / definition |
| --- | ---: | --- |
| Delivered orders | 96,211 | Delivered orders purchased in the reporting window |
| Item sales | BRL 13,181,027.13 | Sum of item prices, excluding freight |
| Item average order value | BRL 137.00 | Item sales / delivered orders |
| Delivery-eligible orders | 96,203 | Delivered orders with valid actual and estimated delivery dates |
| Late delivery rate | 6.79% | 6,531 late orders / 96,203 eligible orders |
| Average delivery duration | 12.54 days | Exact elapsed time from purchase to delivery |
| Review coverage | 99.33% | 95,560 reviewed orders / 96,203 delivery-eligible orders |

Source: committed outputs from [sales analysis](reports/sql_validation/04_sales_performance_analysis.tsv), [delivery analysis](reports/sql_validation/05_delivery_performance.tsv) and [satisfaction analysis](reports/sql_validation/06_delivery_satisfaction.tsv). These are SQL baselines; use the same dates, eligibility rules and filters when comparing Tableau views.

## Key findings

**Sales are geographically concentrated.** São Paulo (SP) accounts for **38.36%** of delivered item sales. Health & beauty is the largest category by item sales, contributing **9.33%**. The sales analysis also separates changes in order volume from changes in average order value.

**Delivery priorities depend on volume as well as rate.** SP has 1,817 late orders despite a relatively low 4.50% late rate. Rio de Janeiro (RJ) has 1,495 late orders and a 12.14% late rate. RJ also has the largest count of orders that are both late and low-rated: **1,064**, compared with **968** in SP. These results support investigating high-volume states alongside states with high late rates.

**Late deliveries are associated with substantially worse reviews.**

| Delivery group | Reviewed orders | Average score / 5 | Low-rating rate |
| --- | ---: | ---: | ---: |
| On time or early | 89,182 | 4.29 | 9.25% |
| Late | 6,378 | 2.27 | 62.40% |
| 8+ calendar days late | 2,779 | 1.70 | 79.27% |

Low ratings are scores of 1 or 2. The final row is a subset of late orders.

**Review timing materially changes the comparison.** Of the 6,378 retained reviews for late orders, **4,472 were answered before actual delivery**. Restricting late-order reviews to responses at or after delivery leaves 1,906 reviews, with an average score of **3.72** and a low-rating rate of **19.41%**. This is a different selected sample, so the results describe an association rather than a causal effect of lateness.

The review-timing sensitivity analysis is included in [SQL script 06](sql/06_delivery_satisfaction.sql) and its [saved output](reports/sql_validation/06_delivery_satisfaction.tsv).

## Analytical workflow

| Stage | Implementation |
| --- | --- |
| Python cleaning | Audit missing values and duplicates; parse timestamps; translate product categories; retain one review per order; examine outliers; derive delivery and review-timing flags |
| CSV handoff | Export five cleaned datasets and a quality report; read the CSVs back and check values, schema and key uniqueness |
| MySQL loading | Load text staging tables, map fields explicitly into typed final tables and reconcile before committing |
| Analytical views | Separate order-level totals, item-level detail and monthly category aggregates to avoid double counting |
| Business analysis | Analyse sales, delivery patterns, customer-state priorities and review-timing sensitivity |
| Tableau | Explore the packaged workbook through its dashboard tabs and available filters |

High item prices and freight values are investigated with IQR summaries rather than automatically removed. Missing delivery information remains distinguishable from an on-time delivery.

### Table grains

| Table / view | Grain | Analytical role |
| --- | --- | --- |
| `customers` | One `customer_id` | Customer records linked to orders; `customer_unique_id` identifies repeat customers |
| `products` | One `product_id` | Categories and product attributes |
| `orders` | One `order_id` | Order status, dates and delivery features |
| `order_items` | One `order_id + order_item_id` | Item prices and freight |
| `reviews` | One retained review per `order_id` | Scores and response timing |
| `vw_order_summary` | One order | Order-level sales, delivery and satisfaction |
| `vw_order_item_detail` | One order item | Exact-date category and item analysis |
| `vw_category_sales` | Purchase month × category × status | Monthly category reporting and reconciliation |

Item values are aggregated before joining to orders. An order can contain multiple categories, so category-level order counts must not be summed to obtain total orders.

## Repository guide

| Location | Contents |
| --- | --- |
| [`Olist_Portfolio_Final_v5.twbx`](Olist_Portfolio_Final_v5.twbx) | Packaged Tableau workbook, approximately 18.5 MB |
| [`notebooks/01_data_cleaning.ipynb`](notebooks/01_data_cleaning.ipynb) | Data audit, cleaning, feature engineering and CSV exports |
| [`sql/`](sql/) | Database setup, loading, validation, views and business analysis |
| [`sql/README.md`](sql/README.md) | SQL execution order, configuration and loading guidance |
| [`reports/sql_validation/`](reports/sql_validation/) | Saved MySQL outputs and post-commit row counts |

Raw data and standalone cleaned CSV files are not tracked in this repository. The notebook generates `data/clean/` and `reports/data_quality_report.csv` locally. A separate narrative PDF report is not currently included.

## Explore the Tableau workbook

1. [Download the workbook](https://github.com/zwu765211-arch/ecommerce-customer-satisfaction/raw/refs/heads/main/Olist_Portfolio_Final_v5.twbx). GitHub does not render the interactive workbook in the repository page.
2. Open the downloaded `.twbx` file in Tableau Desktop or Tableau Public.
3. Browse its dashboard tabs and use the available date, category and geographic controls.
4. Reset selections before comparing totals with the SQL baselines above.

The workbook is a saved analytical snapshot. Running the Python and SQL workflow does not automatically refresh it; regenerate the relevant CSV exports and refresh the workbook connections when updating the analysis.

## Reproduce the Python and SQL analysis

### 1. Download the source data

Source: [Brazilian E-Commerce Public Dataset by Olist on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce).

Place these six source files in `data/raw/` under the project root:

- `olist_orders_dataset.csv`
- `olist_order_items_dataset.csv`
- `olist_order_reviews_dataset.csv`
- `olist_products_dataset.csv`
- `olist_customers_dataset.csv`
- `product_category_name_translation.csv`

Follow the source dataset's attribution and usage terms.

### 2. Run the notebook

Use Python 3 with pandas, NumPy, Matplotlib and Jupyter:

```bash
python3 -m pip install pandas numpy matplotlib jupyter
cd notebooks
jupyter notebook 01_data_cleaning.ipynb
```

Run all cells in order with the notebook working directory set to `notebooks/`, so its `../data/` paths resolve correctly. The notebook exports:

- `data/clean/customers_clean.csv`
- `data/clean/products_clean.csv`
- `data/clean/orders_clean.csv`
- `data/clean/order_items_clean.csv`
- `data/clean/reviews_clean.csv`
- `reports/data_quality_report.csv`

### 3. Execute the SQL workflow

Use **MySQL 8.0.16 or later** and follow the detailed [SQL workflow guide](sql/README.md).

| Order | Script | Purpose |
| --- | --- | --- |
| 1 | [`00_database_setup.sql`](sql/00_database_setup.sql) | Connection checks and database setup |
| 2 | [`01_create_tables.sql`](sql/01_create_tables.sql) | Final tables, keys and constraints |
| 3 | [`01-1_load_clean_csv.sql`](sql/01-1_load_clean_csv.sql) | Staging, typed loading and reconciliation |
| 4 | [`02_data_validation.sql`](sql/02_data_validation.sql) | Data quality, grain and join checks |
| 5 | [`03_create_analytic_views.sql`](sql/03_create_analytic_views.sql) | Order, item and monthly category views |
| 6 | [`04_sales_performance_analysis.sql`](sql/04_sales_performance_analysis.sql) | Sales trends, categories and states |
| 7 | [`05_delivery_performance.sql`](sql/05_delivery_performance.sql) | Delivery duration, lateness and priorities |
| 8 | [`06_delivery_satisfaction.sql`](sql/06_delivery_satisfaction.sql) | Review coverage, rating comparisons and timing sensitivity |

Replace all five `/absolute/path/to/ecommerce-customer-satisfaction` prefixes in the loader with the local project path. Enable `LOCAL INFILE` in both the client connection and server.

Use a fresh database and one connection for setup and loading. Execute the loader section by section, inspect errors and warnings, and run `COMMIT;` manually only after the inserts and reconciliation checks pass; otherwise run `ROLLBACK;`. This is a fresh-load workflow, not an idempotent reload.

## Validation evidence

The committed execution evidence records a complete fresh-database run on **MySQL 8.0.46 on 3 November 2026**:

- **5/5** staging-to-final reconciliation checks passed.
- **56** data-validation checks passed, with **0** failures.
- Analytical views reconciled to source row counts and monetary totals.
- Scripts 04–06 completed without MySQL errors or warnings.
- Final row counts were checked again after committing the load.

| Final table | Persisted rows |
| --- | ---: |
| Customers | 99,441 |
| Products | 32,951 |
| Orders | 99,441 |
| Order items | 112,650 |
| Reviews | 98,673 |

These full-dataset counts differ from the date-filtered analytical samples. See [validation documentation](reports/sql_validation/README.md) and [persisted counts](reports/sql_validation/persistence_counts.tsv).

## Metric definitions and limitations

- **Item sales:** sum of item prices; excludes freight and is not Olist's company revenue or profit.
- **Item AOV:** item sales divided by delivered orders in the selected purchase-date window.
- **Delivery duration:** exact elapsed purchase-to-delivery time in days. The separate `delivery_days` field contains rounded-down whole days.
- **Lateness:** actual delivery calendar date is later than the estimated delivery calendar date. Delivery on the estimated date is on time.
- **Eligibility:** invalid or missing delivery dates are excluded from the relevant delivery calculations; ineligible orders are not labelled on time.
- **Review retention:** keep the latest row per order, sorted by review creation date and then response timestamp. Review coverage and timing are assessed separately.
- **Low-rating rate:** reviewed orders with scores of 1–2 divided by reviewed orders in the relevant group.
- **Interpretation:** descriptive comparisons do not control for all differences in geography, product mix or other potential confounders. Small groups and review timing require care.
