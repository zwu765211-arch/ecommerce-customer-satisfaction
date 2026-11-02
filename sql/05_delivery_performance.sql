-- delivery performance
-- Exact purchase-to-delivery duration is measured in fractional days.
-- Punctuality uses calendar-date delay and delivery_analysis_valid = 1.
-- Carrier flags apply to stage-duration studies, not this overall sample.
-- Currency: BRL. Late-order item sales are exposure, not estimated losses.

USE olist_ecommerce;

SET @start_date = '2017-01-01';
SET @end_date   = '2018-09-01';
SET @min_orders = 100;

-- Delivery-date coverage among delivered orders.

SELECT
    COUNT(*) AS delivered_orders,
    SUM(
        order_delivered_customer_date IS NULL
    ) AS missing_actual_delivery_date,
    SUM(
        order_estimated_delivery_date IS NULL
    ) AS missing_estimated_delivery_date,
    SUM(delivery_days_exact IS NOT NULL) AS eligible_exact_duration_orders,
    SUM(delivery_analysis_valid = 1) AS eligible_late_rate_orders,
    SUM(delivery_analysis_valid = 0) AS ineligible_late_rate_orders
FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date;


-- Exact-duration sample does not require an estimated date.
-- Show its denominator separately from the late-rate denominator below.
SELECT COUNT(*) AS eligible_exact_duration_orders,
    ROUND(AVG(delivery_days_exact), 2) AS avg_delivery_days_exact
FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
  AND delivery_days_exact IS NOT NULL;

-- Overall delivery speed and punctuality.
-- On-time deliveries include early deliveries.
SELECT
    COUNT(*) AS eligible_orders,

    ROUND(
        AVG(delivery_days_exact), 2
    ) AS avg_delivery_days_exact,

    SUM(is_late = 1) AS late_orders,

    ROUND(
        100.0 * SUM(is_late = 1)
        / NULLIF(COUNT(*), 0), 2
    ) AS late_rate_pct,

    ROUND(
        100.0 * SUM(is_late = 0)
        / NULLIF(COUNT(*), 0), 2
    ) AS on_time_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN is_late = 1 THEN delivery_delay_days
            END
        ), 2
    ) AS avg_delay_days_among_late_orders

FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
  AND delivery_analysis_valid = 1;


-- Distribution of delivery punctuality.

WITH classified_orders AS (
    SELECT
        CASE
            WHEN delivery_delay_days < 0 THEN 1
            WHEN delivery_delay_days = 0 THEN 2
            WHEN delivery_delay_days BETWEEN 1 AND 3 THEN 3
            WHEN delivery_delay_days BETWEEN 4 AND 7 THEN 4
            ELSE 5
        END AS group_order

    FROM vw_order_summary
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= @start_date
      AND order_purchase_timestamp < @end_date
      AND delivery_analysis_valid = 1
),

group_totals AS (
    SELECT
        group_order,
        COUNT(*) AS orders
    FROM classified_orders
    GROUP BY group_order
)

SELECT
    CASE group_order
        WHEN 1 THEN 'Early'
        WHEN 2 THEN 'On estimated date'
        WHEN 3 THEN '1-3 days late'
        WHEN 4 THEN '4-7 days late'
        WHEN 5 THEN '8+ days late'
    END AS delivery_group,

    orders,

    ROUND(
        100.0 * orders
        / NULLIF(SUM(orders) OVER (), 0), 2
    ) AS order_share_pct

FROM group_totals
ORDER BY group_order;


-- Delivery performance by purchase month.

SELECT
    purchase_year_month,
    COUNT(*) AS eligible_orders,

    ROUND(
        AVG(delivery_days_exact), 2
    ) AS avg_delivery_days_exact,

    SUM(is_late = 1) AS late_orders,

    ROUND(
        100.0 * SUM(is_late = 1)
        / NULLIF(COUNT(*), 0), 2
    ) AS late_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN is_late = 1 THEN delivery_delay_days
            END
        ), 2
    ) AS avg_delay_days_among_late_orders

FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
  AND delivery_analysis_valid = 1
GROUP BY purchase_year_month
ORDER BY purchase_year_month;


-- Delivery performance by customer state.
-- Exclude groups below the chosen minimum eligible order count.
-- 100 is a presentation threshold, not a statistical-significance test.
-- Sort by late order COUNT for affected scale; also inspect late rate.

SELECT
    customer_state,
    COUNT(*) AS eligible_orders,

    ROUND(
        AVG(delivery_days_exact), 2
    ) AS avg_delivery_days_exact,

    SUM(is_late = 1) AS late_orders,
    ROUND(SUM(CASE WHEN is_late = 1 THEN item_sales ELSE 0 END), 2)
        AS late_order_item_sales_brl,

    ROUND(
        100.0 * SUM(is_late = 1)
        / NULLIF(COUNT(*), 0), 2
    ) AS late_rate_pct,

    ROUND(
        AVG(
            CASE
                WHEN is_late = 1 THEN delivery_delay_days
            END
        ), 2
    ) AS avg_delay_days_among_late_orders

FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
  AND delivery_analysis_valid = 1

GROUP BY customer_state
HAVING COUNT(*) >= @min_orders
ORDER BY late_orders DESC, late_rate_pct DESC;




-- Category priorities: one unique order/category pair, not one item.
-- Multi-category orders contribute to each category; order and risk counts
-- are NOT additive across categories.
-- Category sales below cover only items from that category in eligible
-- orders, not the full order value repeated for each category.
WITH order_categories AS (
    SELECT order_id, product_category, SUM(price) AS category_item_sales
    FROM vw_order_item_detail
    GROUP BY order_id, product_category
)
SELECT oc.product_category,
    COUNT(*) AS eligible_orders_with_category,
    ROUND(SUM(oc.category_item_sales), 2) AS eligible_category_item_sales_brl,
    SUM(o.is_late = 1) AS late_orders,
    ROUND(100.0 * SUM(o.is_late = 1) / NULLIF(COUNT(*), 0), 2) AS late_rate_pct,
    ROUND(AVG(CASE WHEN o.is_late = 1 THEN o.delivery_delay_days END), 2)
        AS avg_delay_days_among_late_orders,
    COUNT(o.review_score) AS reviewed_orders,
    ROUND(100.0 * COUNT(o.review_score) / NULLIF(COUNT(*), 0), 2) AS review_coverage_pct,
    SUM(CASE WHEN o.review_score <= 2 THEN 1 ELSE 0 END) AS low_rating_orders,
    ROUND(100.0 * SUM(CASE WHEN o.review_score <= 2 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(o.review_score), 0), 2) AS low_rating_rate_pct,
    SUM(CASE WHEN o.is_late = 1 AND o.review_score <= 2 THEN 1 ELSE 0 END)
        AS late_and_low_rating_orders
FROM order_categories AS oc
JOIN vw_order_summary AS o ON oc.order_id = o.order_id
WHERE o.order_purchase_timestamp >= @start_date
  AND o.order_purchase_timestamp < @end_date
  AND o.delivery_analysis_valid = 1
GROUP BY oc.product_category
HAVING COUNT(*) >= @min_orders
ORDER BY late_and_low_rating_orders DESC, late_orders DESC;

-- Evaluation: inspect frequency, affected count, severity and reviewed
-- negative-experience count together. Late-and-low-rated overlap is a
-- prioritization clue, not causal attribution. No loss or effect is estimated.
