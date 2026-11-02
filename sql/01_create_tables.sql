
-- Purpose:
-- Create five relational tables for the cleaned CSV files.
-- No data is imported in this script.
-- Target: five CSVs exported by 01_data_cleaning_revised.ipynb.
-- CREATE TABLE IF NOT EXISTS does not upgrade an existing table.
-- For an existing database, compare its schema and apply a separately reviewed migration.


USE olist_ecommerce;

-- Customers
CREATE TABLE IF NOT EXISTS customers (
    customer_id CHAR(32) NOT NULL,
    customer_unique_id CHAR(32) NOT NULL,
    customer_zip_code_prefix INT UNSIGNED NOT NULL,
    customer_city VARCHAR(100) NOT NULL,
    customer_state CHAR(2) NOT NULL,

    CONSTRAINT pk_customers
        PRIMARY KEY (customer_id),

    INDEX idx_customers_unique_id (customer_unique_id),
    INDEX idx_customers_state (customer_state)
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;


-- Products
CREATE TABLE IF NOT EXISTS products (
    product_id CHAR(32) NOT NULL,
    product_category_name VARCHAR(100) NOT NULL,
    product_name_length SMALLINT UNSIGNED NULL,
    product_description_length SMALLINT UNSIGNED NULL,
    product_photos_qty SMALLINT UNSIGNED NULL,
    product_weight_g INT UNSIGNED NULL,
    product_length_cm SMALLINT UNSIGNED NULL,
    product_height_cm SMALLINT UNSIGNED NULL,
    product_width_cm SMALLINT UNSIGNED NULL,
    missing_physical_attributes TINYINT UNSIGNED NOT NULL,
    product_category_name_english VARCHAR(100) NOT NULL,
    product_volume_cm3 INT UNSIGNED NULL,

    CONSTRAINT pk_products
        PRIMARY KEY (product_id),

    CONSTRAINT chk_products_missing_physical
        CHECK (missing_physical_attributes IN (0, 1)),

    INDEX idx_products_category_english (
        product_category_name_english
    )
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;


-- Orders
CREATE TABLE IF NOT EXISTS orders (
    order_id CHAR(32) NOT NULL,
    customer_id CHAR(32) NOT NULL,
    order_status VARCHAR(20) NOT NULL,

    order_purchase_timestamp DATETIME NOT NULL,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NOT NULL,

    purchase_date DATE NOT NULL,
    purchase_year SMALLINT UNSIGNED NOT NULL,
    purchase_month TINYINT UNSIGNED NOT NULL,

    -- Raw whole-day and calendar-delay fields are kept for compatibility.
    delivery_days SMALLINT NULL,
    delivery_days_exact DECIMAL(12, 8) NULL,
    delivery_delay_days SMALLINT NULL,
    delivery_analysis_valid TINYINT UNSIGNED NOT NULL,
    is_late TINYINT UNSIGNED NULL,
    carrier_before_purchase TINYINT UNSIGNED NOT NULL,
    delivery_before_carrier TINYINT UNSIGNED NOT NULL,
    non_delivered_with_delivery_date TINYINT UNSIGNED NOT NULL,

    CONSTRAINT pk_orders
        PRIMARY KEY (order_id),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id),

    CONSTRAINT chk_orders_month
        CHECK (purchase_month BETWEEN 1 AND 12),

    -- Raw differences may retain source anomalies; eligible durations cannot.
    CONSTRAINT chk_orders_delivery_days_exact
        CHECK (delivery_days_exact IS NULL OR delivery_days_exact >= 0),
    CONSTRAINT chk_orders_delivery_analysis_valid
        CHECK (delivery_analysis_valid IN (0, 1)),
    CONSTRAINT chk_orders_carrier_before_purchase
        CHECK (carrier_before_purchase IN (0, 1)),
    CONSTRAINT chk_orders_delivery_before_carrier
        CHECK (delivery_before_carrier IN (0, 1)),
    CONSTRAINT chk_orders_non_delivered_with_delivery_date
        CHECK (non_delivered_with_delivery_date IN (0, 1)),

    CONSTRAINT chk_orders_is_late
        CHECK (
            is_late IS NULL
            OR is_late IN (0, 1)
        ),

    INDEX idx_orders_purchase_timestamp (
        order_purchase_timestamp
    ),

    INDEX idx_orders_status (
        order_status
    )
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- Order Items
CREATE TABLE IF NOT EXISTS order_items (
    order_id CHAR(32) NOT NULL,
    order_item_id SMALLINT UNSIGNED NOT NULL,
    product_id CHAR(32) NOT NULL,
    seller_id CHAR(32) NOT NULL,
    shipping_limit_date DATETIME NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    freight_value DECIMAL(10, 2) NOT NULL,

    CONSTRAINT pk_order_items
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products (product_id),

    CONSTRAINT chk_order_items_price
        CHECK (price >= 0),

    CONSTRAINT chk_order_items_freight
        CHECK (freight_value >= 0),

    INDEX idx_order_items_product (
        product_id
    )
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;

-- Reviews
CREATE TABLE IF NOT EXISTS reviews (
    review_id CHAR(32) NOT NULL,
    order_id CHAR(32) NOT NULL,
    review_score TINYINT UNSIGNED NOT NULL,
    review_creation_date DATETIME NOT NULL,
    review_answer_timestamp DATETIME NOT NULL,
    -- NULL means the response/delivery comparison is not applicable.
    review_before_delivery TINYINT UNSIGNED NULL,

    CONSTRAINT pk_reviews
        PRIMARY KEY (order_id),

    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES orders (order_id),

    CONSTRAINT chk_reviews_score
        CHECK (review_score BETWEEN 1 AND 5),

    CONSTRAINT chk_reviews_before_delivery
        CHECK (review_before_delivery IS NULL OR review_before_delivery IN (0, 1)),

    INDEX idx_reviews_score (
        review_score
    )
) ENGINE = InnoDB
  DEFAULT CHARACTER SET = utf8mb4
  COLLATE = utf8mb4_unicode_ci;
  

SHOW TABLES;