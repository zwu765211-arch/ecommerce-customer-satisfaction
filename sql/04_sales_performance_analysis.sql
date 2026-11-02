-- Olist E-Commerce Analysis: Sales Performance
--
-- Scope:
-- Delivered orders purchased from January 2017 to August 2018.
-- Sales are attributed to the purchase date.
--
-- Definitions:
-- Item Sales: sum of item prices, excluding freight.
-- Total Order Value: item sales plus freight.
-- Item AOV: item sales divided by the corresponding order count.
--
-- Currency: BRL. Amounts do not represent company revenue or profit.
-- Full source retained; sparse 2016/September-October 2018 boundary data is
-- outside this chosen window. Recent delivery outcomes may be incomplete
-- at extraction; no extraction timestamp is supplied.
-- Status overview uses all orders in the window; sales KPIs use delivered status.

USE olist_ecommerce;

SET @start_date = '2017-01-01';
SET @end_date   = '2018-09-01';

-- Status overview: denominator includes ALL statuses.
-- Cancellation rate = canceled / all orders, not a browsing conversion rate.
SELECT COUNT(*) AS total_orders,
    SUM(order_status = 'delivered') AS delivered_orders,
    SUM(order_status = 'canceled') AS canceled_orders,
    SUM(order_status = 'unavailable') AS unavailable_orders,
    ROUND(100.0 * SUM(order_status = 'canceled') / NULLIF(COUNT(*), 0), 2)
        AS cancellation_rate_pct
FROM vw_order_summary
WHERE order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date;

SELECT order_status, COUNT(*) AS orders
FROM vw_order_summary
WHERE order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
GROUP BY order_status
ORDER BY orders DESC;

-- Coverage by purchase month helps identify partial/sparse periods.
SELECT purchase_year_month, COUNT(*) AS all_status_orders,
    SUM(order_status = 'delivered') AS delivered_orders,
    SUM(order_status = 'canceled') AS canceled_orders,
    ROUND(100.0 * SUM(order_status = 'canceled') / NULLIF(COUNT(*), 0), 2)
        AS cancellation_rate_pct
FROM vw_order_summary
WHERE order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
GROUP BY purchase_year_month
ORDER BY purchase_year_month;

-- Confirm that every included order has item amounts.

SELECT
    COUNT(*) AS delivered_orders,
    SUM(item_sales IS NULL) AS orders_without_item_sales,
    SUM(freight_value IS NULL) AS orders_without_freight
FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date;
  
  
-- Overall sales KPIs.

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(SUM(item_sales), 2) AS item_sales,
    ROUND(SUM(freight_value), 2) AS freight_value,
    ROUND(SUM(total_order_value), 2) AS total_order_value,

    ROUND(
        SUM(item_sales) / NULLIF(COUNT(*), 0),
        2
    ) AS item_aov

FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date;
  
-- Monthly sales, month-over-month growth, and cumulative sales.
-- LAG gets the previous row's month; SUM OVER accumulates monthly sales.
-- These two window functions are retained from the original script.
-- This source window has all 20 months present. If source/window changes,
-- check missing months before interpreting LAG as previous calendar month.
-- MoM needs whole months; exact-date sales totals do not.

WITH monthly_sales AS (
    SELECT
        purchase_year_month,
        COUNT(*) AS delivered_orders,
        SUM(item_sales) AS item_sales
    FROM vw_order_summary
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= @start_date
      AND order_purchase_timestamp < @end_date
    GROUP BY purchase_year_month
),

monthly_comparison AS (
    SELECT
        purchase_year_month,
        delivered_orders,
        item_sales,

        LAG(delivered_orders) OVER (
            ORDER BY purchase_year_month
        ) AS previous_month_orders,

        LAG(item_sales) OVER (
            ORDER BY purchase_year_month
        ) AS previous_month_sales,

        LAG(item_sales / NULLIF(delivered_orders, 0)) OVER (
            ORDER BY purchase_year_month
        ) AS previous_month_aov,

        SUM(item_sales) OVER (
            ORDER BY purchase_year_month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_item_sales

    FROM monthly_sales
)

SELECT
    purchase_year_month,
    delivered_orders,
    ROUND(item_sales, 2) AS item_sales,

    ROUND(
        item_sales / NULLIF(delivered_orders, 0),
        2
    ) AS item_aov,

    ROUND(
        100.0 * (delivered_orders - previous_month_orders)
        / NULLIF(previous_month_orders, 0),
        2
    ) AS orders_mom_pct,

    ROUND(
        100.0 * (item_sales - previous_month_sales)
        / NULLIF(previous_month_sales, 0),
        2
    ) AS sales_mom_pct,

    ROUND(
        100.0 * (item_sales / NULLIF(delivered_orders, 0) - previous_month_aov)
        / NULLIF(previous_month_aov, 0), 2
    ) AS aov_mom_pct,

    ROUND(cumulative_item_sales, 2) AS cumulative_item_sales

FROM monthly_comparison
ORDER BY purchase_year_month;

-- Category sales ordered by sales amount and contribution.
-- Item detail supports exact date filtering, including mid-month dates.

WITH category_totals AS (
    SELECT
        product_category,
        COUNT(*) AS items_sold,
        SUM(price) AS item_sales
    FROM vw_order_item_detail
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= @start_date
      AND order_purchase_timestamp < @end_date
    GROUP BY product_category
)

SELECT
    product_category,
    items_sold,
    ROUND(item_sales, 2) AS item_sales,

    ROUND(
        100.0 * item_sales
        / NULLIF(SUM(item_sales) OVER (), 0),
        2
    ) AS sales_share_pct

FROM category_totals
ORDER BY item_sales DESC, product_category;

-- Sales performance by customer state.

WITH state_totals AS (
    SELECT
        customer_state,
        COUNT(*) AS delivered_orders,
        SUM(item_sales) AS item_sales
    FROM vw_order_summary
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= @start_date
      AND order_purchase_timestamp < @end_date
    GROUP BY customer_state
)

SELECT
    customer_state,
    delivered_orders,
    ROUND(item_sales, 2) AS item_sales,

    ROUND(
        100.0 * item_sales
        / NULLIF(SUM(item_sales) OVER (), 0),
        2
    ) AS sales_share_pct,

    ROUND(
        item_sales / NULLIF(delivered_orders, 0),
        2
    ) AS item_aov

FROM state_totals
ORDER BY item_sales DESC;

-- Reconcile item sales across the source and both analytical views.

WITH source_total AS (
    SELECT
        SUM(oi.price) AS item_sales
    FROM order_items AS oi
    JOIN orders AS o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= @start_date
      AND o.order_purchase_timestamp < @end_date
),

order_view_total AS (
    SELECT
        SUM(item_sales) AS item_sales
    FROM vw_order_summary
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= @start_date
      AND order_purchase_timestamp < @end_date
),

item_detail_total AS (
    SELECT
        SUM(price) AS item_sales
    FROM vw_order_item_detail
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= @start_date
      AND order_purchase_timestamp < @end_date
)

SELECT
    s.item_sales AS source_item_sales,
    o.item_sales AS order_view_item_sales,
    c.item_sales AS item_detail_sales,

    o.item_sales - s.item_sales AS order_view_difference,
    c.item_sales - s.item_sales AS item_detail_difference

FROM source_total AS s
CROSS JOIN order_view_total AS o
CROSS JOIN item_detail_total AS c;


-- Sales-change contributors: August 2018 versus July 2018 by default.
-- Pick two COMPLETE months within the reporting window; inspect the guard.
-- Four date literals make the comparison explicit and easy to change.
SET @previous_month_start = '2018-07-01';
SET @previous_month_end   = '2018-08-01';
SET @current_month_start  = '2018-08-01';
SET @current_month_end    = '2018-09-01';

SELECT CASE
    WHEN @previous_month_start >= @start_date
     AND @current_month_end <= @end_date
     AND @previous_month_end = @current_month_start
     AND DAY(@previous_month_start) = 1 AND DAY(@current_month_start) = 1
     AND @previous_month_end = DATE_ADD(@previous_month_start, INTERVAL 1 MONTH)
     AND @current_month_end = DATE_ADD(@current_month_start, INTERVAL 1 MONTH)
    THEN 'PASS' ELSE 'FAIL' END AS comparison_window_check;
-- If FAIL, adjust dates before running the comparisons below.

-- Conditional sums measure the two periods in a single grouped query.
WITH state_change AS (
    SELECT customer_state,
        SUM(CASE WHEN order_purchase_timestamp >= @previous_month_start
                  AND order_purchase_timestamp < @previous_month_end
                 THEN item_sales ELSE 0 END) AS previous_sales,
        SUM(CASE WHEN order_purchase_timestamp >= @current_month_start
                  AND order_purchase_timestamp < @current_month_end
                 THEN item_sales ELSE 0 END) AS current_sales
    FROM vw_order_summary
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= @previous_month_start
      AND order_purchase_timestamp < @current_month_end
    GROUP BY customer_state
)
SELECT customer_state, ROUND(previous_sales, 2) AS previous_sales,
    ROUND(current_sales, 2) AS current_sales,
    ROUND(current_sales - previous_sales, 2) AS sales_change_brl
FROM state_change
ORDER BY ABS(current_sales - previous_sales) DESC, customer_state;

WITH category_change AS (
    SELECT product_category,
        SUM(CASE WHEN order_purchase_timestamp >= @previous_month_start
                  AND order_purchase_timestamp < @previous_month_end
                 THEN price ELSE 0 END) AS previous_sales,
        SUM(CASE WHEN order_purchase_timestamp >= @current_month_start
                  AND order_purchase_timestamp < @current_month_end
                 THEN price ELSE 0 END) AS current_sales
    FROM vw_order_item_detail
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= @previous_month_start
      AND order_purchase_timestamp < @current_month_end
    GROUP BY product_category
)
SELECT product_category, ROUND(previous_sales, 2) AS previous_sales,
    ROUND(current_sales, 2) AS current_sales,
    ROUND(current_sales - previous_sales, 2) AS sales_change_brl
FROM category_change
ORDER BY ABS(current_sales - previous_sales) DESC, product_category;

-- Interpretation: sales = delivered orders * item AOV.
-- Read orders_mom_pct and aov_mom_pct together, then locate larger changes
-- in states/categories. A contribution to observed change is not its cause.
-- Sum all state changes OR all category changes to reconcile net change;
-- do not add state and category changes together (same underlying sales).
