
-- Purpose:
-- Validate that the five cleaned datasets were loaded completely
-- and retain the expected grain, relationships and business rules.

USE olist_ecommerce;


WITH row_count_checks AS (
    SELECT 'customers' AS table_name, 99441 AS expected_rows,
           COUNT(*) AS actual_rows
    FROM customers

    UNION ALL
    SELECT 'products', 32951, COUNT(*) FROM products

    UNION ALL
    SELECT 'orders', 99441, COUNT(*) FROM orders

    UNION ALL
    SELECT 'order_items', 112650, COUNT(*) FROM order_items

    UNION ALL
    SELECT 'reviews', 98673, COUNT(*) FROM reviews
)

SELECT
    table_name,
    expected_rows,
    actual_rows,
    actual_rows - expected_rows AS row_difference,
    CASE
        WHEN actual_rows = expected_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS check_result
FROM row_count_checks;


WITH grain_checks AS (
    SELECT
        'customers' AS table_name,
        'customer_id' AS expected_grain,
        COUNT(*) AS total_rows,
        COUNT(DISTINCT customer_id) AS unique_keys
    FROM customers

    UNION ALL
    SELECT 'products', 'product_id', COUNT(*),
           COUNT(DISTINCT product_id)
    FROM products

    UNION ALL
    SELECT 'orders', 'order_id', COUNT(*),
           COUNT(DISTINCT order_id)
    FROM orders

    UNION ALL
    SELECT 'order_items', '(order_id, order_item_id)', COUNT(*),
           COUNT(DISTINCT order_id, order_item_id)
    FROM order_items

    UNION ALL
    SELECT 'reviews', 'order_id', COUNT(*),
           COUNT(DISTINCT order_id)
    FROM reviews
)

SELECT
    table_name,
    expected_grain,
    total_rows,
    unique_keys,
    total_rows - unique_keys AS duplicate_rows,
    CASE
        WHEN total_rows = unique_keys THEN 'PASS'
        ELSE 'FAIL'
    END AS check_result
FROM grain_checks;


SELECT
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(order_status IS NULL) AS missing_order_status,
    SUM(order_purchase_timestamp IS NULL)
        AS missing_purchase_timestamp,
    SUM(order_estimated_delivery_date IS NULL)
        AS missing_estimated_delivery_date,
    SUM(order_approved_at IS NULL)
        AS missing_approved_at,
    SUM(order_delivered_carrier_date IS NULL)
        AS missing_carrier_date,
    SUM(order_delivered_customer_date IS NULL)
        AS missing_customer_delivery_date,
    SUM(delivery_days IS NULL)
        AS missing_delivery_days,
    SUM(delivery_delay_days IS NULL)
        AS missing_delivery_delay_days,
    SUM(is_late IS NULL) AS missing_is_late,
    SUM(delivery_days_exact IS NULL) AS missing_exact_delivery_days,
    SUM(delivery_analysis_valid = 1) AS eligible_late_rate_orders
FROM orders;

-- Structural delivery NULLs should be concentrated in incomplete
-- order statuses rather than silently removed during CSV import.

SELECT
    order_status,
    COUNT(*) AS order_count,
    SUM(order_delivered_carrier_date IS NULL)
        AS missing_carrier_date,
    SUM(order_delivered_customer_date IS NULL)
        AS missing_customer_delivery_date,
    SUM(delivery_days IS NULL)
        AS missing_delivery_days
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- All invalid_rows values should equal 0.

WITH domain_checks AS (
    SELECT 'orders.order_status' AS field_checked,
           COUNT(*) AS invalid_rows
    FROM orders
    WHERE order_status NOT IN (
        'delivered', 'shipped', 'canceled', 'unavailable',
        'invoiced', 'processing', 'created', 'approved'
    )

    UNION ALL
    SELECT 'orders.purchase_month', COUNT(*)
    FROM orders
    WHERE purchase_month NOT BETWEEN 1 AND 12

    UNION ALL
    SELECT 'orders.is_late', COUNT(*)
    FROM orders
    WHERE is_late IS NOT NULL
      AND is_late NOT IN (0, 1)

    UNION ALL
    SELECT 'reviews.review_score', COUNT(*)
    FROM reviews
    WHERE review_score NOT BETWEEN 1 AND 5
       OR review_score IS NULL

    UNION ALL
    SELECT 'products.missing_physical_attributes', COUNT(*)
    FROM products
    WHERE missing_physical_attributes NOT IN (0, 1)
       OR missing_physical_attributes IS NULL
    UNION ALL
    SELECT 'orders.delivery_analysis_valid', COUNT(*) FROM orders
    WHERE delivery_analysis_valid IS NULL OR delivery_analysis_valid NOT IN (0, 1)
    UNION ALL
    SELECT 'orders.carrier_before_purchase', COUNT(*) FROM orders
    WHERE carrier_before_purchase IS NULL OR carrier_before_purchase NOT IN (0, 1)
    UNION ALL
    SELECT 'orders.delivery_before_carrier', COUNT(*) FROM orders
    WHERE delivery_before_carrier IS NULL OR delivery_before_carrier NOT IN (0, 1)
    UNION ALL
    SELECT 'orders.non_delivered_with_delivery_date', COUNT(*) FROM orders
    WHERE non_delivered_with_delivery_date IS NULL
       OR non_delivered_with_delivery_date NOT IN (0, 1)
    UNION ALL
    SELECT 'reviews.review_before_delivery', COUNT(*) FROM reviews
    WHERE review_before_delivery IS NOT NULL AND review_before_delivery NOT IN (0, 1)

)

SELECT
    field_checked,
    invalid_rows,
    CASE
        WHEN invalid_rows = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS check_result
FROM domain_checks;


-- Retained as a one-time range check for source coverage.

SELECT
    MIN(order_purchase_timestamp) AS earliest_purchase,
    MAX(order_purchase_timestamp) AS latest_purchase,
    MIN(order_delivered_customer_date) AS earliest_delivery,
    MAX(order_delivered_customer_date) AS latest_delivery
FROM orders;


-- All exception_rows values should equal 0.
-- Recompute expected fields directly from source timestamps.
-- CTE = a named intermediate query, not a stored procedure.
WITH expected_order_fields AS (
    SELECT o.*,
        CASE WHEN order_status = 'delivered'
                   AND order_delivered_customer_date >= order_purchase_timestamp
             THEN TIMESTAMPDIFF(SECOND, order_purchase_timestamp,
                               order_delivered_customer_date) * 1.00000000 / 86400
        END AS expected_exact_days,
        CASE WHEN order_status = 'delivered'
                   AND order_delivered_customer_date >= order_purchase_timestamp
                   AND DATE(order_estimated_delivery_date) >= DATE(order_purchase_timestamp)
             THEN 1 ELSE 0 END AS expected_analysis_valid
    FROM orders AS o
),
order_rule_checks AS (
    SELECT 'inconsistent_purchase_date' AS rule_checked, COUNT(*) AS exception_rows
    FROM orders WHERE purchase_date <> DATE(order_purchase_timestamp)
    UNION ALL
    SELECT 'inconsistent_purchase_year', COUNT(*) FROM orders
    WHERE purchase_year <> YEAR(order_purchase_timestamp)
    UNION ALL
    SELECT 'inconsistent_purchase_month', COUNT(*) FROM orders
    WHERE purchase_month <> MONTH(order_purchase_timestamp)
    UNION ALL
    SELECT 'inconsistent_analysis_valid', COUNT(*) FROM expected_order_fields
    WHERE delivery_analysis_valid IS NULL OR delivery_analysis_valid <> expected_analysis_valid
    UNION ALL
    SELECT 'inconsistent_exact_duration', COUNT(*) FROM expected_order_fields
    WHERE (delivery_days_exact IS NULL AND expected_exact_days IS NOT NULL)
       OR (delivery_days_exact IS NOT NULL AND expected_exact_days IS NULL)
       OR ABS(delivery_days_exact - expected_exact_days) > 0.00000001
    UNION ALL
    SELECT 'inconsistent_whole_elapsed_days', COUNT(*) FROM orders
    WHERE (order_delivered_customer_date IS NULL AND delivery_days IS NOT NULL)
       OR (order_delivered_customer_date IS NOT NULL AND delivery_days IS NULL)
       OR delivery_days <> FLOOR(TIMESTAMPDIFF(SECOND, order_purchase_timestamp,
                                               order_delivered_customer_date) * 1.00000000 / 86400)
    UNION ALL
    SELECT 'inconsistent_calendar_delay', COUNT(*) FROM orders
    WHERE ((order_delivered_customer_date IS NULL OR order_estimated_delivery_date IS NULL)
           AND delivery_delay_days IS NOT NULL)
       OR (order_delivered_customer_date IS NOT NULL
           AND order_estimated_delivery_date IS NOT NULL AND delivery_delay_days IS NULL)
       OR delivery_delay_days <> DATEDIFF(order_delivered_customer_date,
                                          order_estimated_delivery_date)
    UNION ALL
    SELECT 'eligible_orders_missing_late_flag', COUNT(*) FROM orders
    WHERE delivery_analysis_valid = 1 AND is_late IS NULL
    UNION ALL
    SELECT 'ineligible_orders_with_late_flag', COUNT(*) FROM orders
    WHERE delivery_analysis_valid = 0 AND is_late IS NOT NULL
    UNION ALL
    SELECT 'inconsistent_late_flag_values', COUNT(*) FROM orders
    WHERE delivery_analysis_valid = 1
      AND (delivery_delay_days IS NULL
           OR is_late <> CASE WHEN delivery_delay_days > 0 THEN 1 ELSE 0 END)
    UNION ALL
    SELECT 'inconsistent_carrier_before_purchase', COUNT(*) FROM orders
    WHERE carrier_before_purchase <> CASE
        WHEN order_delivered_carrier_date < order_purchase_timestamp THEN 1 ELSE 0 END
    UNION ALL
    SELECT 'inconsistent_delivery_before_carrier', COUNT(*) FROM orders
    WHERE delivery_before_carrier <> CASE
        WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 1 ELSE 0 END
    UNION ALL
    SELECT 'inconsistent_non_delivered_flag', COUNT(*) FROM orders
    WHERE non_delivered_with_delivery_date <> CASE
        WHEN order_status <> 'delivered' AND order_delivered_customer_date IS NOT NULL
        THEN 1 ELSE 0 END
)
SELECT rule_checked, exception_rows,
    CASE WHEN exception_rows = 0 THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM order_rule_checks;

-- Timing is comparable for delivered orders with actual delivery timestamps.
WITH expected_review_fields AS (
    SELECT r.order_id, r.review_before_delivery,
        CASE WHEN o.order_status = 'delivered'
                   AND o.order_delivered_customer_date IS NOT NULL
                   AND r.review_answer_timestamp IS NOT NULL
             THEN CASE WHEN r.review_answer_timestamp < o.order_delivered_customer_date
                       THEN 1 ELSE 0 END
        END AS expected_review_before_delivery
    FROM reviews AS r JOIN orders AS o ON r.order_id = o.order_id
)
SELECT 'inconsistent_review_timing_flag' AS rule_checked,
    COUNT(*) AS exception_rows,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM expected_review_fields
WHERE (review_before_delivery IS NULL AND expected_review_before_delivery IS NOT NULL)
   OR (review_before_delivery IS NOT NULL AND expected_review_before_delivery IS NULL)
   OR review_before_delivery <> expected_review_before_delivery;

-- Observational warnings: ALL source orders, not the reporting window.
-- Match notebook data_quality_report.csv. REVIEW is acceptable when counts
-- agree and downstream eligibility is implemented correctly.
WITH quality_observations AS (
    SELECT 'Carrier timestamp before purchase' AS observation,
        166 AS expected_rows, SUM(carrier_before_purchase) AS observed_rows FROM orders
    UNION ALL SELECT 'Customer delivery before carrier timestamp', 23,
        SUM(delivery_before_carrier) FROM orders
    UNION ALL SELECT 'Customer delivery before purchase', 0,
        COUNT(*) FROM orders WHERE order_delivered_customer_date < order_purchase_timestamp
    UNION ALL SELECT 'Estimated date before purchase date', 0,
        COUNT(*) FROM orders
        WHERE DATE(order_estimated_delivery_date) < DATE(order_purchase_timestamp)
    UNION ALL SELECT 'Non-delivered status with actual delivery timestamp', 6,
        SUM(non_delivered_with_delivery_date) FROM orders
    UNION ALL SELECT 'Delivered status missing actual delivery timestamp', 8,
        COUNT(*) FROM orders
        WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL
    UNION ALL SELECT 'Delivered orders ineligible for late-rate analysis', 8,
        COUNT(*) FROM orders WHERE order_status = 'delivered' AND delivery_analysis_valid = 0
    UNION ALL SELECT 'Retained review response before delivery (delivered orders)', 4654,
        COUNT(*) FROM reviews WHERE review_before_delivery = 1
    UNION ALL SELECT 'Retained review created before delivery (delivered orders)', 8127,
        COUNT(*) FROM reviews AS r JOIN orders AS o ON r.order_id = o.order_id
        WHERE o.order_status = 'delivered'
          AND r.review_creation_date < o.order_delivered_customer_date
    UNION ALL SELECT 'Orders without item records', 775,
        COUNT(*) FROM orders AS o LEFT JOIN
            (SELECT DISTINCT order_id FROM order_items) AS i ON o.order_id = i.order_id
        WHERE i.order_id IS NULL
    UNION ALL SELECT 'Orders without a retained review', 768,
        COUNT(*) FROM orders AS o LEFT JOIN reviews AS r ON o.order_id = r.order_id
        WHERE r.order_id IS NULL
    UNION ALL SELECT 'Products with missing physical attributes', 2,
        SUM(missing_physical_attributes) FROM products
    UNION ALL SELECT 'Products with zero weight', 4,
        COUNT(*) FROM products WHERE product_weight_g = 0
)
SELECT observation, expected_rows, observed_rows,
    CASE WHEN observed_rows = 0 THEN 'CLEAR' ELSE 'REVIEW' END AS observation_status,
    CASE WHEN observed_rows = expected_rows THEN 'PASS' ELSE 'FAIL' END AS snapshot_check
FROM quality_observations;


WITH business_rule_checks AS (
    SELECT
        'products_invalid_physical_values' AS rule_checked,
        COUNT(*) AS exception_rows
    FROM products
    WHERE product_weight_g < 0
       OR product_length_cm <= 0
       OR product_height_cm <= 0
       OR product_width_cm <= 0
       OR product_volume_cm3 <= 0

    UNION ALL
    SELECT 'products_inconsistent_volume', COUNT(*)
    FROM products
    WHERE product_length_cm IS NOT NULL
      AND product_height_cm IS NOT NULL
      AND product_width_cm IS NOT NULL
      AND product_volume_cm3 <>
          product_length_cm * product_height_cm * product_width_cm

    UNION ALL
    SELECT 'products_inconsistent_missing_flag', COUNT(*) FROM products
    WHERE missing_physical_attributes <> CASE
        WHEN product_weight_g IS NULL OR product_length_cm IS NULL
          OR product_height_cm IS NULL OR product_width_cm IS NULL THEN 1 ELSE 0 END
    UNION ALL
    SELECT 'products_inconsistent_volume_nulls', COUNT(*) FROM products
    WHERE ((product_length_cm IS NULL OR product_height_cm IS NULL OR product_width_cm IS NULL)
           AND product_volume_cm3 IS NOT NULL)
       OR (product_length_cm IS NOT NULL AND product_height_cm IS NOT NULL
           AND product_width_cm IS NOT NULL AND product_volume_cm3 IS NULL)

    UNION ALL
    SELECT 'order_items_invalid_values', COUNT(*)
    FROM order_items
    WHERE price < 0
       OR freight_value < 0
       OR order_item_id < 1

    UNION ALL
    SELECT 'orders_not_starting_at_item_one', COUNT(*)
    FROM (
        SELECT order_id
        FROM order_items
        GROUP BY order_id
        HAVING MIN(order_item_id) <> 1
    ) AS invalid_item_sequences
)

SELECT
    rule_checked,
    exception_rows,
    CASE
        WHEN exception_rows = 0 THEN 'PASS'
        ELSE 'FAIL'
    END AS check_result
FROM business_rule_checks;


-- Product missingness flag retained from the Pandas quality report.

SELECT
    COUNT(*) AS total_products,
    SUM(product_weight_g IS NULL) AS missing_weight,
    SUM(product_length_cm IS NULL) AS missing_length,
    SUM(product_height_cm IS NULL) AS missing_height,
    SUM(product_width_cm IS NULL) AS missing_width,
    SUM(missing_physical_attributes = 1)
        AS flagged_physical_missing
FROM products;


-- Review grain and score bounds should remain valid after import.

SELECT
    COUNT(*) AS total_reviews,
    COUNT(DISTINCT order_id) AS reviewed_orders,
    COUNT(DISTINCT review_id) AS unique_review_ids,
    MIN(review_score) AS minimum_review_score,
    MAX(review_score) AS maximum_review_score
FROM reviews;


-- Each joined_rows value must equal its expected_rows value.
-- This confirms that the joins neither lose nor multiply base rows.

WITH join_checks AS (
    SELECT
        'orders_to_customers' AS join_checked,
        (SELECT COUNT(*) FROM orders) AS expected_rows,
        COUNT(*) AS joined_rows
    FROM orders AS o
    JOIN customers AS c
        ON o.customer_id = c.customer_id

    UNION ALL
    SELECT
        'order_items_to_orders_and_products',
        (SELECT COUNT(*) FROM order_items),
        COUNT(*)
    FROM order_items AS oi
    JOIN orders AS o
        ON oi.order_id = o.order_id
    JOIN products AS p
        ON oi.product_id = p.product_id

    UNION ALL
    SELECT
        'reviews_to_orders',
        (SELECT COUNT(*) FROM reviews),
        COUNT(*)
    FROM reviews AS r
    JOIN orders AS o
        ON r.order_id = o.order_id
)

SELECT
    join_checked,
    expected_rows,
    joined_rows,
    joined_rows - expected_rows AS row_difference,
    CASE
        WHEN joined_rows = expected_rows THEN 'PASS'
        ELSE 'FAIL'
    END AS check_result
FROM join_checks;
