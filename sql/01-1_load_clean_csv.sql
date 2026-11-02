
-- Load ALL FIVE revised CSVs with explicit field mapping.
-- Fresh load only: final and staging tables must be empty/absent.
-- Replace /absolute/path/to/ecommerce-customer-satisfaction in all five paths.
-- Enable LOCAL INFILE in the client connection and server before loading.
-- Execute section by section; stop on any error or warning.
-- DDL implicitly commits: stage first, then transact only the INSERTs.

USE olist_ecommerce;

CREATE TABLE customers_staging (
    customer_id VARCHAR(255),
    customer_unique_id VARCHAR(255),
    customer_zip_code_prefix VARCHAR(255),
    customer_city VARCHAR(255),
    customer_state VARCHAR(255)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4;

CREATE TABLE products_staging (
    product_id VARCHAR(255),
    product_category_name VARCHAR(255),
    product_name_length VARCHAR(255),
    product_description_length VARCHAR(255),
    product_photos_qty VARCHAR(255),
    product_weight_g VARCHAR(255),
    product_length_cm VARCHAR(255),
    product_height_cm VARCHAR(255),
    product_width_cm VARCHAR(255),
    missing_physical_attributes VARCHAR(255),
    product_category_name_english VARCHAR(255),
    product_volume_cm3 VARCHAR(255)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4;

CREATE TABLE orders_staging (
    order_id VARCHAR(255),
    customer_id VARCHAR(255),
    order_status VARCHAR(255),
    order_purchase_timestamp VARCHAR(255),
    order_approved_at VARCHAR(255),
    order_delivered_carrier_date VARCHAR(255),
    order_delivered_customer_date VARCHAR(255),
    order_estimated_delivery_date VARCHAR(255),
    purchase_date VARCHAR(255),
    purchase_year VARCHAR(255),
    purchase_month VARCHAR(255),
    delivery_days VARCHAR(255),
    delivery_days_exact VARCHAR(255),
    delivery_delay_days VARCHAR(255),
    delivery_analysis_valid VARCHAR(255),
    is_late VARCHAR(255),
    carrier_before_purchase VARCHAR(255),
    delivery_before_carrier VARCHAR(255),
    non_delivered_with_delivery_date VARCHAR(255)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4;

CREATE TABLE order_items_staging (
    order_id VARCHAR(255),
    order_item_id VARCHAR(255),
    product_id VARCHAR(255),
    seller_id VARCHAR(255),
    shipping_limit_date VARCHAR(255),
    price VARCHAR(255),
    freight_value VARCHAR(255)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4;

CREATE TABLE reviews_staging (
    review_id VARCHAR(255),
    order_id VARCHAR(255),
    review_score VARCHAR(255),
    review_creation_date VARCHAR(255),
    review_answer_timestamp VARCHAR(255),
    review_before_delivery VARCHAR(255)
) ENGINE = InnoDB DEFAULT CHARACTER SET = utf8mb4;

-- Optional server administration step, only if needed and permitted:
-- SET GLOBAL local_infile = ON;
SHOW GLOBAL VARIABLES LIKE 'local_infile';

LOAD DATA LOCAL INFILE '/absolute/path/to/ecommerce-customer-satisfaction/data/clean/customers_clean.csv'
INTO TABLE customers_staging
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(customer_id,
 customer_unique_id,
 customer_zip_code_prefix,
 customer_city,
 customer_state);
SHOW WARNINGS;

LOAD DATA LOCAL INFILE '/absolute/path/to/ecommerce-customer-satisfaction/data/clean/products_clean.csv'
INTO TABLE products_staging
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id,
 product_category_name,
 product_name_length,
 product_description_length,
 product_photos_qty,
 product_weight_g,
 product_length_cm,
 product_height_cm,
 product_width_cm,
 missing_physical_attributes,
 product_category_name_english,
 product_volume_cm3);
SHOW WARNINGS;

LOAD DATA LOCAL INFILE '/absolute/path/to/ecommerce-customer-satisfaction/data/clean/orders_clean.csv'
INTO TABLE orders_staging
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id,
 customer_id,
 order_status,
 order_purchase_timestamp,
 order_approved_at,
 order_delivered_carrier_date,
 order_delivered_customer_date,
 order_estimated_delivery_date,
 purchase_date,
 purchase_year,
 purchase_month,
 delivery_days,
 delivery_days_exact,
 delivery_delay_days,
 delivery_analysis_valid,
 is_late,
 carrier_before_purchase,
 delivery_before_carrier,
 non_delivered_with_delivery_date);
SHOW WARNINGS;

LOAD DATA LOCAL INFILE '/absolute/path/to/ecommerce-customer-satisfaction/data/clean/order_items_clean.csv'
INTO TABLE order_items_staging
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_id,
 order_item_id,
 product_id,
 seller_id,
 shipping_limit_date,
 price,
 freight_value);
SHOW WARNINGS;

LOAD DATA LOCAL INFILE '/absolute/path/to/ecommerce-customer-satisfaction/data/clean/reviews_clean.csv'
INTO TABLE reviews_staging
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(review_id,
 order_id,
 review_score,
 review_creation_date,
 review_answer_timestamp,
 review_before_delivery);
SHOW WARNINGS;

SELECT 'customers' AS table_name, 99441 AS expected_rows, COUNT(*) AS staged_rows FROM customers_staging
UNION ALL
SELECT 'products' AS table_name, 32951 AS expected_rows, COUNT(*) AS staged_rows FROM products_staging
UNION ALL
SELECT 'orders' AS table_name, 99441 AS expected_rows, COUNT(*) AS staged_rows FROM orders_staging
UNION ALL
SELECT 'order_items' AS table_name, 112650 AS expected_rows, COUNT(*) AS staged_rows FROM order_items_staging
UNION ALL
SELECT 'reviews' AS table_name, 98673 AS expected_rows, COUNT(*) AS staged_rows FROM reviews_staging;

SELECT 'customers' AS table_name, COUNT(*) AS existing_rows FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'reviews', COUNT(*) FROM reviews;


-- Confirm all final tables are empty before starting.
START TRANSACTION;

INSERT INTO customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state)
SELECT
    NULLIF(TRIM(customer_id), ''),
    NULLIF(TRIM(customer_unique_id), ''),
    CAST(NULLIF(TRIM(customer_zip_code_prefix), '') AS DECIMAL(20, 0)),
    NULLIF(TRIM(customer_city), ''),
    NULLIF(TRIM(customer_state), '')
FROM customers_staging;
SHOW WARNINGS;

INSERT INTO products (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    missing_physical_attributes,
    product_category_name_english,
    product_volume_cm3)
SELECT
    NULLIF(TRIM(product_id), ''),
    NULLIF(TRIM(product_category_name), ''),
    CAST(NULLIF(TRIM(product_name_length), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(product_description_length), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(product_photos_qty), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(product_weight_g), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(product_length_cm), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(product_height_cm), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(product_width_cm), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(missing_physical_attributes), '') AS DECIMAL(20, 0)),
    NULLIF(TRIM(product_category_name_english), ''),
    CAST(NULLIF(TRIM(product_volume_cm3), '') AS DECIMAL(20, 0))
FROM products_staging;
SHOW WARNINGS;

INSERT INTO orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    purchase_date,
    purchase_year,
    purchase_month,
    delivery_days,
    delivery_days_exact,
    delivery_delay_days,
    delivery_analysis_valid,
    is_late,
    carrier_before_purchase,
    delivery_before_carrier,
    non_delivered_with_delivery_date
)
SELECT
    NULLIF(TRIM(order_id), ''),
    NULLIF(TRIM(customer_id), ''),
    NULLIF(TRIM(order_status), ''),

    STR_TO_DATE(
        TRIM(order_purchase_timestamp),
        '%Y-%m-%d %H:%i:%s'
    ),

    CASE
        WHEN TRIM(order_approved_at) = '' THEN NULL
        ELSE STR_TO_DATE(
            TRIM(order_approved_at),
            '%Y-%m-%d %H:%i:%s'
        )
    END,

    CASE
        WHEN TRIM(order_delivered_carrier_date) = '' THEN NULL
        ELSE STR_TO_DATE(
            TRIM(order_delivered_carrier_date),
            '%Y-%m-%d %H:%i:%s'
        )
    END,

    CASE
        WHEN TRIM(order_delivered_customer_date) = '' THEN NULL
        ELSE STR_TO_DATE(
            TRIM(order_delivered_customer_date),
            '%Y-%m-%d %H:%i:%s'
        )
    END,

    STR_TO_DATE(
        TRIM(order_estimated_delivery_date),
        '%Y-%m-%d'
    ),
    STR_TO_DATE(
        TRIM(purchase_date),
        '%Y-%m-%d'
    ),

    CAST(NULLIF(TRIM(purchase_year), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(purchase_month), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(delivery_days), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(delivery_days_exact), '') AS DECIMAL(12, 8)),
    CAST(NULLIF(TRIM(delivery_delay_days), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(delivery_analysis_valid), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(is_late), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(carrier_before_purchase), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(delivery_before_carrier), '') AS DECIMAL(20, 0)),
    CAST(NULLIF(TRIM(non_delivered_with_delivery_date), '') AS DECIMAL(20, 0))
FROM orders_staging;

SHOW WARNINGS;

SELECT COUNT(*) AS orders_rows
FROM orders;

INSERT INTO order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value)
SELECT
    NULLIF(TRIM(order_id), ''),
    CAST(NULLIF(TRIM(order_item_id), '') AS DECIMAL(20, 0)),
    NULLIF(TRIM(product_id), ''),
    NULLIF(TRIM(seller_id), ''),
    STR_TO_DATE(TRIM(shipping_limit_date), '%Y-%m-%d %H:%i:%s'),
    CAST(NULLIF(TRIM(price), '') AS DECIMAL(10, 2)),
    CAST(NULLIF(TRIM(freight_value), '') AS DECIMAL(10, 2))
FROM order_items_staging;
SHOW WARNINGS;

INSERT INTO reviews (
    review_id,
    order_id,
    review_score,
    review_creation_date,
    review_answer_timestamp,
    review_before_delivery)
SELECT
    NULLIF(TRIM(review_id), ''),
    NULLIF(TRIM(order_id), ''),
    CAST(NULLIF(TRIM(review_score), '') AS DECIMAL(20, 0)),
    STR_TO_DATE(TRIM(review_creation_date), '%Y-%m-%d %H:%i:%s'),
    STR_TO_DATE(TRIM(review_answer_timestamp), '%Y-%m-%d %H:%i:%s'),
    CAST(NULLIF(TRIM(review_before_delivery), '') AS DECIMAL(20, 0))
FROM reviews_staging;
SHOW WARNINGS;

-- E. Reconcile before COMMIT. Every check_result must be PASS.
-- Also confirm that all five INSERTs succeeded without warnings.
-- If any statement failed or result is FAIL: ROLLBACK; and stop.
-- Do NOT proceed to COMMIT, cleanup, or analysis.
SELECT 'customers' AS table_name,
    (SELECT COUNT(*) FROM customers_staging) AS staged_rows,
    COUNT(*) AS loaded_rows,
    CASE WHEN COUNT(*) = (SELECT COUNT(*) FROM customers_staging)
         THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM customers
UNION ALL
SELECT 'products' AS table_name,
    (SELECT COUNT(*) FROM products_staging) AS staged_rows,
    COUNT(*) AS loaded_rows,
    CASE WHEN COUNT(*) = (SELECT COUNT(*) FROM products_staging)
         THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM products
UNION ALL
SELECT 'orders' AS table_name,
    (SELECT COUNT(*) FROM orders_staging) AS staged_rows,
    COUNT(*) AS loaded_rows,
    CASE WHEN COUNT(*) = (SELECT COUNT(*) FROM orders_staging)
         THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM orders
UNION ALL
SELECT 'order_items' AS table_name,
    (SELECT COUNT(*) FROM order_items_staging) AS staged_rows,
    COUNT(*) AS loaded_rows,
    CASE WHEN COUNT(*) = (SELECT COUNT(*) FROM order_items_staging)
         THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM order_items
UNION ALL
SELECT 'reviews' AS table_name,
    (SELECT COUNT(*) FROM reviews_staging) AS staged_rows,
    COUNT(*) AS loaded_rows,
    CASE WHEN COUNT(*) = (SELECT COUNT(*) FROM reviews_staging)
         THEN 'PASS' ELSE 'FAIL' END AS check_result
FROM reviews;


-- STOP: inspect reconciliation and all INSERT warnings above.
-- Run COMMIT manually only if all checks pass; otherwise run ROLLBACK.
-- Keep staging tables until the load has been committed successfully.
-- COMMIT;

-- Optional cleanup AFTER a successful COMMIT:
-- DROP TABLE customers_staging;
-- DROP TABLE products_staging;
-- DROP TABLE orders_staging;
-- DROP TABLE order_items_staging;
-- DROP TABLE reviews_staging;

