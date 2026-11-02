-- Olist E-Commerce Analysis | 06_delivery_satisfaction.sql
-- Primary descriptive analysis keeps all retained valid review scores.
-- Low rating = 1 or 2. Denominator = reviewed eligible orders.
-- Sensitivity restricts review RESPONSE time, not review creation time.

USE olist_ecommerce;

SET @start_date = '2017-01-01';
SET @end_date   = '2018-09-01';
SET @min_reviewed_orders = 100;

-- Review coverage among orders eligible for delivery analysis.

SELECT
    COUNT(*) AS eligible_delivery_orders,
    COUNT(review_score) AS reviewed_orders,
    SUM(review_score IS NULL) AS orders_without_reviews,
    ROUND(
        100.0 * COUNT(review_score)
        / NULLIF(COUNT(*), 0), 2
    ) AS review_coverage_pct

FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
  AND delivery_analysis_valid = 1;
  
  -- Distribution of review scores in the analytical sample.

SELECT
    review_score,
    COUNT(*) AS reviewed_orders,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (), 2
    ) AS order_share_pct

FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
  AND delivery_analysis_valid = 1
  AND review_score BETWEEN 1 AND 5

GROUP BY review_score
ORDER BY review_score;

-- Scores, coverage and low-rating rates: on-time versus late.
-- Unreviewed orders stay in COUNT(*); COUNT(review_score) excludes NULL.
SELECT
    CASE is_late WHEN 0 THEN 'On time or early' WHEN 1 THEN 'Late' END AS delivery_status,
    COUNT(*) AS eligible_delivery_orders,
    COUNT(review_score) AS reviewed_orders,
    ROUND(100.0 * COUNT(review_score) / NULLIF(COUNT(*), 0), 2) AS review_coverage_pct,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) AS low_rating_orders,
    ROUND(100.0 * SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(review_score), 0), 2) AS low_rating_rate_pct
FROM vw_order_summary
WHERE order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
  AND delivery_analysis_valid = 1
GROUP BY is_late
ORDER BY is_late;

-- Satisfaction and review coverage by calendar-delay severity.
WITH classified_orders AS (
    SELECT review_score,
        CASE
            WHEN delivery_delay_days < 0 THEN 1
            WHEN delivery_delay_days = 0 THEN 2
            WHEN delivery_delay_days BETWEEN 1 AND 3 THEN 3
            WHEN delivery_delay_days BETWEEN 4 AND 7 THEN 4
            ELSE 5
        END AS group_order
    FROM vw_order_summary
    WHERE order_purchase_timestamp >= @start_date
      AND order_purchase_timestamp < @end_date
      AND delivery_analysis_valid = 1
)
SELECT
    CASE group_order
        WHEN 1 THEN 'Early' WHEN 2 THEN 'On estimated date'
        WHEN 3 THEN '1-3 days late' WHEN 4 THEN '4-7 days late'
        WHEN 5 THEN '8+ days late'
    END AS delivery_group,
    COUNT(*) AS eligible_delivery_orders,
    COUNT(review_score) AS reviewed_orders,
    ROUND(100.0 * COUNT(review_score) / NULLIF(COUNT(*), 0), 2) AS review_coverage_pct,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) AS low_rating_orders,
    ROUND(100.0 * SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(review_score), 0), 2) AS low_rating_rate_pct
FROM classified_orders
GROUP BY group_order
ORDER BY group_order;

-- Satisfaction by exact total delivery duration (reviewed sample).
-- Fractional intervals: [0,7], (7,14], (14,30], (30,infinity).
-- Calendar-delay severity above uses integer calendar-date differences.

WITH classified_orders AS (
    SELECT
        review_score,

        CASE
            WHEN delivery_days_exact <= 7 THEN 1
            WHEN delivery_days_exact <= 14 THEN 2
            WHEN delivery_days_exact <= 30 THEN 3
            ELSE 4
        END AS group_order

    FROM vw_order_summary
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp >= @start_date
      AND order_purchase_timestamp < @end_date
      AND delivery_analysis_valid = 1
      AND review_score BETWEEN 1 AND 5
)

SELECT
    CASE group_order
        WHEN 1 THEN '0-7 days inclusive'
        WHEN 2 THEN '>7 to 14 days inclusive'
        WHEN 3 THEN '>14 to 30 days inclusive'
        WHEN 4 THEN '>30 days'
    END AS delivery_duration_group,

    COUNT(*) AS reviewed_orders,

    ROUND(
        AVG(review_score), 2
    ) AS avg_review_score,

    ROUND(
        100.0 * SUM(review_score <= 2)
        / NULLIF(COUNT(*), 0), 2
    ) AS low_rating_rate_pct

FROM classified_orders
GROUP BY group_order
ORDER BY group_order;

-- Within-state comparison of on-time and late review scores.
-- Require at least @min_reviewed_orders in EACH group.
-- This display threshold does not establish statistical significance.

SELECT
    customer_state,

    SUM(is_late = 0) AS on_time_reviewed_orders,
    SUM(is_late = 1) AS late_reviewed_orders,

    ROUND(
        AVG(CASE WHEN is_late = 0 THEN review_score END), 2
    ) AS on_time_avg_score,

    ROUND(
        AVG(CASE WHEN is_late = 1 THEN review_score END), 2
    ) AS late_avg_score,

    ROUND(
        AVG(CASE WHEN is_late = 1 THEN review_score END)
        - AVG(CASE WHEN is_late = 0 THEN review_score END), 2
    ) AS late_minus_on_time_score,
    ROUND(100.0 * SUM(CASE WHEN is_late = 0 AND review_score <= 2 THEN 1 ELSE 0 END)
          / NULLIF(SUM(is_late = 0), 0), 2) AS on_time_low_rating_rate_pct,
    ROUND(100.0 * SUM(CASE WHEN is_late = 1 AND review_score <= 2 THEN 1 ELSE 0 END)
          / NULLIF(SUM(is_late = 1), 0), 2) AS late_low_rating_rate_pct,
    ROUND(
        100.0 * SUM(CASE WHEN is_late = 1 AND review_score <= 2 THEN 1 ELSE 0 END)
            / NULLIF(SUM(is_late = 1), 0)
      - 100.0 * SUM(CASE WHEN is_late = 0 AND review_score <= 2 THEN 1 ELSE 0 END)
            / NULLIF(SUM(is_late = 0), 0), 2
    ) AS late_minus_on_time_low_rating_pp

FROM vw_order_summary
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
  AND delivery_analysis_valid = 1
  AND review_score BETWEEN 1 AND 5

GROUP BY customer_state

HAVING SUM(is_late = 0) >= @min_reviewed_orders
   AND SUM(is_late = 1) >= @min_reviewed_orders

ORDER BY late_minus_on_time_score;



-- Timing sensitivity: compare ALL retained reviews with responses at/after
-- delivery. Both samples appear in the same row with their sizes/coverage.
-- Keep the original eligible-order denominator for coverage.
-- Restriction changes population; it is not a correction of invalid reviews.
WITH timing_comparison AS (
    SELECT is_late, COUNT(*) AS eligible_delivery_orders,
        COUNT(review_score) AS all_reviewed_orders,
        AVG(review_score) AS all_avg_score,
        SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END) AS all_low_rating_orders,
        SUM(CASE WHEN review_before_delivery = 1 THEN 1 ELSE 0 END)
            AS responses_before_delivery,
        SUM(CASE WHEN review_before_delivery = 0 AND review_score IS NOT NULL
                 THEN 1 ELSE 0 END) AS at_or_after_reviewed_orders,
        AVG(CASE WHEN review_before_delivery = 0 THEN review_score END)
            AS at_or_after_avg_score,
        SUM(CASE WHEN review_before_delivery = 0 AND review_score <= 2
                 THEN 1 ELSE 0 END) AS at_or_after_low_rating_orders
    FROM vw_order_summary
    WHERE order_purchase_timestamp >= @start_date
      AND order_purchase_timestamp < @end_date
      AND delivery_analysis_valid = 1
    GROUP BY is_late
)
SELECT
    CASE is_late WHEN 0 THEN 'On time or early' WHEN 1 THEN 'Late' END AS delivery_status,
    eligible_delivery_orders, all_reviewed_orders, responses_before_delivery,
    ROUND(100.0 * all_reviewed_orders / NULLIF(eligible_delivery_orders, 0), 2)
        AS all_review_coverage_pct,
    ROUND(all_avg_score, 2) AS all_avg_score,
    ROUND(100.0 * all_low_rating_orders / NULLIF(all_reviewed_orders, 0), 2)
        AS all_low_rating_rate_pct,
    at_or_after_reviewed_orders,
    ROUND(100.0 * at_or_after_reviewed_orders / NULLIF(all_reviewed_orders, 0), 2)
        AS retained_share_of_reviews_pct,
    ROUND(100.0 * at_or_after_reviewed_orders / NULLIF(eligible_delivery_orders, 0), 2)
        AS at_or_after_review_coverage_pct,
    ROUND(at_or_after_avg_score, 2) AS at_or_after_avg_score,
    ROUND(100.0 * at_or_after_low_rating_orders
          / NULLIF(at_or_after_reviewed_orders, 0), 2) AS at_or_after_low_rating_rate_pct
FROM timing_comparison
ORDER BY is_late;

-- State priorities: include affected scale, review coverage and risk overlap.
SELECT customer_state, COUNT(*) AS eligible_delivery_orders,
    SUM(is_late = 1) AS late_orders,
    ROUND(100.0 * SUM(is_late = 1) / NULLIF(COUNT(*), 0), 2) AS late_rate_pct,
    COUNT(review_score) AS reviewed_orders,
    ROUND(100.0 * COUNT(review_score) / NULLIF(COUNT(*), 0), 2) AS review_coverage_pct,
    ROUND(100.0 * SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)
          / NULLIF(COUNT(review_score), 0), 2) AS low_rating_rate_pct,
    SUM(CASE WHEN is_late = 1 AND review_score <= 2 THEN 1 ELSE 0 END)
        AS late_and_low_rating_orders
FROM vw_order_summary
WHERE order_purchase_timestamp >= @start_date
  AND order_purchase_timestamp < @end_date
  AND delivery_analysis_valid = 1
GROUP BY customer_state
HAVING COUNT(review_score) >= @min_reviewed_orders
ORDER BY late_and_low_rating_orders DESC, late_orders DESC;

-- ============================================================
-- Findings and Evaluation | baseline snapshot, default date window
-- ============================================================
-- Re-run queries before quoting these values under different filters.
--
-- 1. Business Context
-- Delivered purchases in Jan 2017-Aug 2018 generated approximately
-- BRL 13.18 million in item sales across 96,211 delivered orders;
-- item AOV was BRL 137.00, excluding freight. Sales are not revenue/profit.
-- The window avoids sparse outer months; extraction timing is unknown,
-- so some recent orders' final outcomes may not be observed.
--
-- 2. Delivery Performance
-- 96,203 orders were eligible for late-rate analysis; 6,531 were late.
-- On-time/early share was 93.21%, late share 6.79%.
-- Mean exact purchase-to-delivery duration was 12.54 days in this sample,
-- replacing the old whole-day average of 12.07 days.
-- Late orders were delayed by 10.62 calendar days on average.
--
-- 3. Primary Satisfaction Analysis
-- 95,560 eligible orders had a retained review (99.33% coverage).
-- On-time/early: 89,182 reviewed, mean 4.29, low-rating rate 9.25%.
-- Late: 6,378 reviewed, mean 2.27, low-rating rate 62.40%.
-- Low-rating gap: 53.15 percentage points.
-- 1-3 days late: mean 3.29, low-rating rate 32.14%.
-- 4-7 days late: mean 2.10, low-rating rate 67.62%.
-- 8+ days late: mean 1.70, low-rating rate 79.27%.
--
-- 4. Important Timing Sensitivity
-- Restricting responses to at/after delivery retains 89,005 on-time/early
-- reviews and only 1,906 late reviews (29.88% of the late reviews).
-- Restricted on-time/early: mean 4.29, low-rating rate 9.23%.
-- Restricted late: mean 3.72, low-rating rate 19.41%.
-- Restricted gap is 10.18 percentage points, far smaller than 53.15.
-- The association is timing-sensitive. Before-delivery responses may
-- reflect experience while waiting; retain them rather than automatically
-- labelling them invalid. Their meaning is not established by dates alone.
-- Restriction is selective and does not establish an unbiased post-delivery
-- or causal effect.
--
-- 5. Interpretation and Action
-- Use frequency, severity, scale and review timing together.
-- Investigate states/categories with substantial late-and-low-rating counts.
-- Test delay alerts or support outreach in a defined pilot, tracking delay
-- frequency/severity and low-rating rates with consistent populations.
-- The dataset supports investigations, not claimed achieved improvement.
-- Product quality, seller service, regional mix and timing may affect scores.
-- Within-state comparisons do not control all confounding factors.
-- These descriptive comparisons show neither causality nor significance.
-- Results exclude canceled/undelivered customers from delivery analysis;
-- they are not a complete account of all customers' experiences.
