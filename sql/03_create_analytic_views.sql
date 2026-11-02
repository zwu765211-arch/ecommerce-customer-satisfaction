-- vw_order_summary: One row per order. Combines order and customer details
-- with item totals aggregated by order and the cleaned review score.
-- LEFT JOINs retain orders without item records or reviews. Use this view
-- for order-level sales, delivery, customer, and satisfaction analysis.

USE olist_ecommerce;

CREATE OR REPLACE VIEW vw_order_summary AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,

    o.order_status,
    o.order_purchase_timestamp,
    o.purchase_date,
    o.purchase_year,
    o.purchase_month,
    DATE_FORMAT(o.purchase_date, '%Y-%m') AS purchase_year_month,

    COALESCE(i.item_count, 0) AS item_count,
    i.item_sales,
    i.freight_value,
    i.item_sales + i.freight_value AS total_order_value,

    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    o.delivery_days,
    o.delivery_days_exact,
    o.delivery_delay_days,
    o.delivery_analysis_valid,
    o.is_late,
    o.carrier_before_purchase,
    o.delivery_before_carrier,
    o.non_delivered_with_delivery_date,

    r.review_score,
    r.review_creation_date,
    r.review_answer_timestamp,
    r.review_before_delivery

FROM orders AS o

JOIN customers AS c
    ON o.customer_id = c.customer_id

LEFT JOIN (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(price) AS item_sales,
        SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
) AS i
    ON o.order_id = i.order_id

LEFT JOIN reviews AS r
    ON o.order_id = r.order_id;
    
SELECT
    COUNT(*) AS view_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    SUM(item_count = 0) AS orders_without_items,
    SUM(review_score IS NULL) AS orders_without_reviews
FROM vw_order_summary;

SELECT
    (SELECT SUM(price) FROM order_items) AS source_item_sales,
    (SELECT SUM(item_sales) FROM vw_order_summary) AS view_item_sales,
    (SELECT SUM(freight_value) FROM order_items) AS source_freight,
    (SELECT SUM(freight_value) FROM vw_order_summary) AS view_freight;

-- vw_order_item_detail: one row per order_id + order_item_id.
-- Source for exact-date category sales and the BI item fact.
-- Do NOT join items to order_summary and average repeated review scores.
-- Category delivery/review counts require unique order/category pairs.
CREATE OR REPLACE VIEW vw_order_item_detail AS
SELECT oi.order_id, oi.order_item_id, oi.product_id, oi.seller_id,
    oi.shipping_limit_date,
    o.order_purchase_timestamp, o.purchase_date,
    DATE_FORMAT(o.purchase_date, '%Y-%m') AS purchase_year_month,
    o.order_status, c.customer_state,
    p.product_category_name_english AS product_category,
    oi.price, oi.freight_value
FROM order_items AS oi
JOIN orders AS o ON oi.order_id = o.order_id
JOIN products AS p ON oi.product_id = p.product_id
JOIN customers AS c ON o.customer_id = c.customer_id;

SELECT (SELECT COUNT(*) FROM order_items) AS source_rows,
    COUNT(*) AS detail_rows,
    COUNT(DISTINCT order_id, order_item_id) AS unique_item_keys,
    (SELECT SUM(price) FROM order_items) AS source_sales,
    SUM(price) AS detail_sales,
    SUM(price) - (SELECT SUM(price) FROM order_items) AS sales_difference
FROM vw_order_item_detail;

-- vw_category_sales: One row per purchase month, product category, and
-- order status. Aggregates item counts, distinct orders, item sales,
-- and freight from order items. A multi-category order can contribute
-- to multiple categories, so do not sum orders_with_category to obtain
-- the total number of orders. Filter to 'delivered' for sales analysis.
    
-- Grain: one row per purchase month, category, and order status.
-- Sales are based on order item prices; freight is reported separately.

CREATE OR REPLACE VIEW vw_category_sales AS
SELECT
    DATE_FORMAT(o.purchase_date, '%Y-%m') AS purchase_year_month,
    o.order_status,
    p.product_category_name_english AS product_category,

    COUNT(*) AS item_count,
    COUNT(DISTINCT oi.order_id) AS orders_with_category,
    SUM(oi.price) AS item_sales,
    SUM(oi.freight_value) AS freight_value

FROM order_items AS oi

JOIN orders AS o
    ON oi.order_id = o.order_id

JOIN products AS p
    ON oi.product_id = p.product_id

GROUP BY
    DATE_FORMAT(o.purchase_date, '%Y-%m'),
    o.order_status,
    p.product_category_name_english;
    
SELECT
    (SELECT COUNT(*) FROM order_items) AS source_items,
    (SELECT SUM(item_count) FROM vw_category_sales) AS view_items,

    (SELECT SUM(price) FROM order_items) AS source_sales,
    (SELECT SUM(item_sales) FROM vw_category_sales) AS view_sales,

    (SELECT SUM(freight_value) FROM order_items) AS source_freight,
    (SELECT SUM(freight_value) FROM vw_category_sales) AS view_freight;

-- BI handoff: order_summary (one order), order_item_detail (one item).
-- category_sales remains a fixed monthly reconciliation/supporting view;
-- do not import it as a second fact to be added to item-detail amounts.
-- Missing item amounts remain NULL for orders with no items.
-- Category-filtered order metrics need distinct matching order_ids.
-- An order can belong to multiple categories; category order counts overlap.
-- README explains proposed relationships and verification baselines.
