# Olist E-Commerce Analytics

An end-to-end data analytics project using **Python, MySQL and Tableau** to explore sales performance, delivery reliability and customer satisfaction in the Brazilian Olist marketplace.

**[Read the final analytical brief](reports/Olist_Analytical_Brief_Final.pdf)** · **[Download the Tableau workbook](https://github.com/zwu765211-arch/ecommerce-customer-satisfaction/raw/refs/heads/main/Olist_Portfolio_Final_v5.twbx)**

## Project contents

| File / folder | Description |
| --- | --- |
| [Final analytical brief](reports/Olist_Analytical_Brief_Final.pdf) | Final report with findings and recommendations |
| [Tableau workbook](Olist_Portfolio_Final_v5.twbx) | Interactive dashboards; download and open in Tableau |
| [Python notebook](notebooks/01_data_cleaning.ipynb) | Data cleaning, quality checks and feature engineering |
| [SQL scripts](sql/) | Database setup, validation, analytical views and business analysis |
| [Validation results](reports/sql_validation/) | Saved MySQL outputs and reconciliation checks |

## Key results

For delivered orders purchased between **January 2017 and August 2018**:

- **96,211** delivered orders and **BRL 13.18 million** in item sales.
- **BRL 137.00** average item order value.
- **6.79%** late delivery rate among 96,203 delivery-eligible orders.

Late deliveries are associated with lower review scores. Review timing materially affects the comparison, so the analysis includes a sensitivity check. Item sales exclude freight; these findings are descriptive rather than causal.

Figures above are based on the [saved SQL results](reports/sql_validation/README.md).

## Workflow and reproduction

**Raw CSVs → Python cleaning → MySQL analysis → Tableau visualisation**

1. Download the [Olist dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) and place the six source CSVs referenced by the notebook in `data/raw/`.
2. Install the notebook dependencies from the project root with `python3 -m pip install -r requirements.txt`, then run the notebook from `notebooks/`. It generates five cleaned CSVs in `data/clean/`.
3. Follow the [SQL execution guide](sql/README.md) using MySQL 8.0.16 or later. Configure local CSV paths and enable `LOCAL INFILE`.
4. Download the packaged `.twbx` file and open it in Tableau Desktop or Tableau Public.

Raw and standalone cleaned CSV files are not tracked in this repository. The Tableau workbook is a saved snapshot and is refreshed separately.
