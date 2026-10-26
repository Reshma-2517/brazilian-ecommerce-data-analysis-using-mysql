-- PROJECT: MySQL Analytics Intelligence & Business Performance Control Framework
-- FILE 2 OF 5: DATA QUALITY & VALIDATION
-- PURPOSE: Profile source data, investigate exceptions, and set up reusable quality checks.

-- ==============================================================================
-- SECTION: M02 — Data profiling and relationship validation
-- ==============================================================================

-- ============================================================
-- DATABASE: olist_analytics
--
-- OBJECTIVE:
-- Examine relationships between source tables, profile payment
-- and review data, and investigate potential data-quality issues.
-- ============================================================


-- ============================================================
-- SECTION 1: REFERENTIAL INTEGRITY VALIDATION
-- PURPOSE:
-- Identify records that reference entities missing from the
-- corresponding parent table.
--
-- METHOD:
-- LEFT JOIN retains records from the source table. A NULL
-- parent identifier indicates that no matching record exists.
--
-- OUTPUT:
-- One row per relationship, with the number of orphan records.
-- ============================================================

USE olist_analytics;

-- 1. Orders referencing customers that do not exist
SELECT
    'orders_to_customers' AS relationship_name,
    COUNT(*) AS orphan_rows
FROM olist_orders_dataset o
LEFT JOIN olist_customers_dataset c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

-- 2. Order items referencing orders that do not exist
SELECT
    'items_to_orders',
    COUNT(*)
FROM olist_order_items_dataset i
LEFT JOIN olist_orders_dataset o
    ON i.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

-- 3. Order items referencing missing products
SELECT
    'items_to_products',
    COUNT(*)
FROM olist_order_items_dataset i
LEFT JOIN olist_products_dataset p
    ON i.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

-- 4. Order items referencing missing sellers
SELECT
    'items_to_sellers',
    COUNT(*)
FROM olist_order_items_dataset i
LEFT JOIN olist_sellers_dataset s
    ON i.seller_id = s.seller_id
WHERE s.seller_id IS NULL

UNION ALL

-- 5. Payments referencing missing orders
SELECT
    'payments_to_orders',
    COUNT(*)
FROM olist_order_payments_dataset p
LEFT JOIN olist_orders_dataset o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

-- 6. Reviews referencing missing orders
SELECT
    'reviews_to_orders',
    COUNT(*)
FROM olist_order_reviews_dataset r
LEFT JOIN olist_orders_dataset o
    ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


-- ============================================================
-- SECTION 2: PAYMENT DATA PROFILING
-- PURPOSE:
-- Assess payment-record completeness and identify unusual
-- payment values before performing financial reconciliation.
--
-- METRICS:
-- - Total number of payment records
-- - Missing order identifiers and payment values
-- - Negative and zero payment values
-- - Minimum and maximum recorded payment values
-- ============================================================

USE olist_analytics;

-- 1. Payment data profile
SELECT
    COUNT(*) AS total_rows,
    SUM(order_id IS NULL) AS null_order_ids,
    SUM(payment_value IS NULL) AS null_payment_values,
    SUM(payment_value < 0) AS negative_payment_values,
    SUM(payment_value = 0) AS zero_payment_values,
    MIN(payment_value) AS min_payment_value,
    MAX(payment_value) AS max_payment_value
FROM olist_order_payments_dataset;


-- ============================================================
-- SECTION 3: REVIEW DATA PROFILING
-- PURPOSE:
-- Evaluate review completeness, score validity, and identifier
-- uniqueness to understand the structure of the review dataset.
--
-- VALIDATION:
-- Review scores are expected to fall within the range 1–5.
-- Duplicate review identifiers are investigated separately
-- rather than automatically treated as invalid records.
-- ============================================================

-- 2. Review data profile
SELECT
    COUNT(*) AS total_rows,
    SUM(order_id IS NULL) AS null_order_ids,
    SUM(review_score IS NULL) AS null_review_scores,
    SUM(review_score NOT BETWEEN 1 AND 5)
        AS invalid_review_scores,
    MIN(review_score) AS min_review_score,
    MAX(review_score) AS max_review_score,
    COUNT(DISTINCT review_id) AS distinct_review_ids
FROM olist_order_reviews_dataset;


-- ============================================================
-- SECTION 4: IDENTIFY DUPLICATE REVIEW IDENTIFIERS
-- PURPOSE:
-- List review IDs appearing in multiple records.

-- OUTPUT:
-- Up to 20 review IDs, ordered by their occurrence count.
-- ============================================================

-- 3. Check duplicate review IDs
SELECT
    review_id,
    COUNT(*) AS occurrences
FROM olist_order_reviews_dataset
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;


-- ============================================================
-- SECTION 5: INVESTIGATE ZERO-VALUE PAYMENTS
-- PURPOSE:
-- Retrieve individual payment records where the recorded
-- payment value is zero.
-- ============================================================

SELECT *
FROM olist_order_payments_dataset
WHERE payment_value = 0
ORDER BY order_id, payment_sequential;


-- ============================================================
-- SECTION 6: PROFILE DUPLICATE REVIEW GROUPS
-- PURPOSE:
-- Examine repeated review IDs using additional attributes.
--
-- METRICS:
-- - Number of records per review ID
-- - Number of distinct associated orders
-- - Number of distinct review scores
-- - Number of distinct comment titles and messages

-- ============================================================

SELECT
    review_id,
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT review_score) AS distinct_scores,
    COUNT(DISTINCT review_comment_title)
        AS distinct_titles,
    COUNT(DISTINCT review_comment_message)
        AS distinct_messages
FROM olist_order_reviews_dataset
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY row_count DESC, review_id
LIMIT 20;


-- ============================================================
-- SECTION 7: INVESTIGATE ALL PAYMENT RECORDS FOR AFFECTED ORDERS
-- PURPOSE:
-- Retrieve every payment record for orders that contain at
-- least one zero-value payment.
-- ============================================================

SELECT *
FROM olist_order_payments_dataset
WHERE order_id IN (
    SELECT order_id
    FROM olist_order_payments_dataset
    WHERE payment_value = 0
)
ORDER BY order_id, payment_sequential;


-- ============================================================
-- SECTION 8: IDENTIFY A DUPLICATE REVIEW ID FOR INVESTIGATION
-- PURPOSE:
-- Return the review ID with the highest occurrence count
-- among IDs appearing more than once.
-- ============================================================

USE olist_analytics;

SELECT
    review_id,
    COUNT(*) AS row_count,
    COUNT(DISTINCT order_id) AS distinct_orders
FROM olist_order_reviews_dataset
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY row_count DESC
LIMIT 1;


-- ============================================================
-- SECTION 9: VALIDATE REVIEW-ORDER PAIR UNIQUENESS
-- PURPOSE:
-- Compare total review rows with distinct review/order pairs
-- and measure missing review and order identifiers.
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id, order_id) AS distinct_review_order_pairs,
    SUM(review_id IS NULL) AS null_review_ids,
    SUM(order_id IS NULL) AS null_order_ids
FROM olist_order_reviews_dataset;


-- ============================================================
-- SECTION 10: IDENTIFY DUPLICATE REVIEW-ORDER PAIRS
-- PURPOSE:
-- List review/order combinations appearing more than once.

-- ============================================================

SELECT
    review_id,
    order_id,
    COUNT(*) AS occurrences
FROM olist_order_reviews_dataset
GROUP BY review_id, order_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;

-- ============================================================
-- SECTION 11: PROFILE ORDER TIMESTAMP COMPLETENESS
-- PURPOSE:
-- Assess the availability of key timestamps throughout the
-- order lifecycle, from purchase through delivery.
--
-- METRICS:
-- - Missing purchase, approval, carrier, and delivery dates
-- - Missing estimated delivery dates
-- - Approval dates earlier than purchase dates
-- - Delivery dates earlier than carrier handoff or purchase

-- ============================================================

USE olist_analytics;

SELECT
    COUNT(*) AS total_orders,

    SUM(order_purchase_timestamp IS NULL)
        AS null_purchase_dates,

    SUM(order_approved_at IS NULL)
        AS null_approval_dates,

    SUM(order_delivered_carrier_date IS NULL)
        AS null_carrier_dates,

    SUM(order_delivered_customer_date IS NULL)
        AS null_delivery_dates,

    SUM(order_estimated_delivery_date IS NULL)
        AS null_estimated_dates,

    SUM(
        order_approved_at < order_purchase_timestamp
    ) AS approval_before_purchase,

    SUM(
        order_delivered_customer_date
        < order_delivered_carrier_date
    ) AS delivery_before_carrier,

    SUM(
        order_delivered_customer_date
        < order_purchase_timestamp
    ) AS delivery_before_purchase

FROM olist_orders_dataset;


-- ============================================================
-- SECTION 12: IDENTIFY ORDERS WITH CHRONOLOGICAL ANOMALIES
-- PURPOSE:
-- Retrieve individual orders whose timestamps indicate an
-- unexpected sequence in the order lifecycle.

-- OUTPUT:
-- Returns the relevant timestamps and binary indicators
-- for the three chronological conditions being tested.
-- ============================================================

SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,

    CASE
        WHEN order_approved_at < order_purchase_timestamp
        THEN 1 ELSE 0
    END AS approval_before_purchase,

    CASE
        WHEN order_delivered_customer_date
             < order_delivered_carrier_date
        THEN 1 ELSE 0
    END AS delivery_before_carrier,

    CASE
        WHEN order_delivered_customer_date
             < order_purchase_timestamp
        THEN 1 ELSE 0
    END AS delivery_before_purchase

FROM olist_orders_dataset
WHERE
    order_approved_at < order_purchase_timestamp
    OR order_delivered_customer_date
       < order_delivered_carrier_date
    OR order_delivered_customer_date
       < order_purchase_timestamp
ORDER BY order_purchase_timestamp
LIMIT 50;


-- ============================================================
-- SECTION 13: PROFILE ZERO DATES BY ORDER STATUS
-- PURPOSE:
-- Examine the distribution of zero-date timestamps across
-- order statuses.
--
-- METRICS:
-- - Total orders per status
-- - Zero approval dates
-- - Zero carrier-handoff dates
-- - Zero customer-delivery dates
-- ============================================================

USE olist_analytics;

SELECT
    order_status,
    COUNT(*) AS total_orders,

    SUM(
        DATE_FORMAT(order_approved_at, '%Y-%m-%d %H:%i:%s')
        = '0000-00-00 00:00:00'
    ) AS zero_approval_dates,

    SUM(
        DATE_FORMAT(order_delivered_carrier_date, '%Y-%m-%d %H:%i:%s')
        = '0000-00-00 00:00:00'
    ) AS zero_carrier_dates,

    SUM(
        DATE_FORMAT(order_delivered_customer_date, '%Y-%m-%d %H:%i:%s')
        = '0000-00-00 00:00:00'
    ) AS zero_delivery_dates

FROM olist_orders_dataset
GROUP BY order_status
ORDER BY total_orders DESC;


-- ============================================================
-- SECTION 14: CLASSIFY CHRONOLOGICAL ANOMALIES
-- PURPOSE:
-- Retrieve anomalous orders and label each record according
-- to the first matching chronological condition.
--
-- VALIDATION CONDITIONS:
-- - Approval before purchase
-- - Customer delivery before carrier handoff
-- - Customer delivery before purchase
-- ============================================================

SELECT
    order_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,

    CASE
        WHEN order_approved_at < order_purchase_timestamp
            THEN 'Approval before purchase'
        WHEN order_delivered_customer_date
             < order_delivered_carrier_date
            THEN 'Delivery before carrier handoff'
        WHEN order_delivered_customer_date
             < order_purchase_timestamp
            THEN 'Delivery before purchase'
    END AS anomaly_type

FROM olist_orders_dataset
WHERE
    order_approved_at IS NOT NULL
    AND order_purchase_timestamp IS NOT NULL
    AND order_approved_at > '1000-01-01'
    AND order_purchase_timestamp > '1000-01-01'
    AND order_approved_at < order_purchase_timestamp

    OR (
        order_delivered_customer_date IS NOT NULL
        AND order_delivered_carrier_date IS NOT NULL
        AND order_delivered_customer_date > '1000-01-01'
        AND order_delivered_carrier_date > '1000-01-01'
        AND order_delivered_customer_date
            < order_delivered_carrier_date
    )

    OR (
        order_delivered_customer_date IS NOT NULL
        AND order_purchase_timestamp IS NOT NULL
        AND order_delivered_customer_date > '1000-01-01'
        AND order_purchase_timestamp > '1000-01-01'
        AND order_delivered_customer_date
            < order_purchase_timestamp
    )
LIMIT 100;


-- ============================================================
-- SECTION 15: RECOUNT CHRONOLOGICAL ANOMALIES WITH DATE GUARDS
-- PURPOSE:
-- Quantify the three timestamp anomalies while excluding
-- NULL and very early date values from the comparisons.
--
-- ANALYST USE:
-- Provides aggregate counts that can be compared with the
-- initial timestamp profile and record-level investigation.
-- ============================================================

USE olist_analytics;

SELECT
    SUM(
        order_approved_at < order_purchase_timestamp
        AND order_approved_at > '1000-01-01'
        AND order_purchase_timestamp > '1000-01-01'
    ) AS approval_before_purchase,

    SUM(
        order_delivered_customer_date
            < order_delivered_carrier_date
        AND order_delivered_customer_date > '1000-01-01'
        AND order_delivered_carrier_date > '1000-01-01'
    ) AS delivery_before_carrier,

    SUM(
        order_delivered_customer_date
            < order_purchase_timestamp
        AND order_delivered_customer_date > '1000-01-01'
        AND order_purchase_timestamp > '1000-01-01'
    ) AS delivery_before_purchase

FROM olist_orders_dataset;
-- ============================================================
-- PART 3 OF 4: FINANCIAL RECONCILIATION
-- ============================================================


-- ------------------------------------------------------------
-- 1. OVERALL FINANCIAL RECONCILIATION
-- ------------------------------------------------------------
-- PURPOSE:
-- Compare order-item value plus freight charges with recorded payments.
-- Aggregate item and payment records separately at order level before
-- joining them, avoiding multiplication of totals caused by many-to-many
-- relationships between item records and payment records.
--
-- KEY METRICS:
-- matched_orders: Orders present in both aggregated datasets.
-- total_item_value: Sum of product prices.
-- total_freight_value: Sum of freight charges.
-- total_item_plus_freight: Combined item and freight value.
-- total_payments: Sum of recorded payments for matched orders.
-- total_difference: Payments minus item-plus-freight value.
-- orders_with_difference_over_1_cent: Orders whose absolute difference
-- exceeds R$0.01.

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS item_value,
        SUM(freight_value) AS freight_value,
        SUM(price + freight_value) AS item_plus_freight
    FROM olist_order_items_dataset
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total,
        COUNT(*) AS payment_record_count
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    COUNT(*) AS matched_orders,
    SUM(i.item_value) AS total_item_value,
    SUM(i.freight_value) AS total_freight_value,
    SUM(i.item_plus_freight) AS total_item_plus_freight,
    SUM(p.payment_total) AS total_payments,
    SUM(p.payment_total - i.item_plus_freight)
        AS total_difference,
    SUM(
        ABS(p.payment_total - i.item_plus_freight) > 0.01
    ) AS orders_with_difference_over_1_cent
FROM item_totals i
JOIN payment_totals p
    ON i.order_id = p.order_id;



-- ------------------------------------------------------------
-- 2. IDENTIFY ORDERS WITH FINANCIAL DISCREPANCIES
-- ------------------------------------------------------------
-- PURPOSE:
-- List individual orders whose payment total differs from the sum of
-- item prices and freight charges by more than one cent.
--
-- ANALYTICAL APPROACH:
-- Aggregate item and payment records independently at order level.
-- Join the aggregated results to the orders table to retrieve status.
-- Calculate the payment difference and sort by absolute discrepancy.
-- Return the 30 largest discrepancies for detailed investigation.
--
-- INTERPRETATION:
-- A discrepancy is a signal for investigation, not automatic proof
-- of fraud, non-payment, or incorrect data.

USE olist_analytics;

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS item_value,
        SUM(freight_value) AS freight_value
    FROM olist_order_items_dataset
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total,
        COUNT(*) AS payment_record_count
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    i.item_value,
    i.freight_value,
    p.payment_total,
    p.payment_record_count,
    ROUND(
        p.payment_total - (i.item_value + i.freight_value),
        2
    ) AS difference
FROM olist_orders_dataset o
JOIN item_totals i
    ON o.order_id = i.order_id
JOIN payment_totals p
    ON o.order_id = p.order_id
WHERE ABS(
    p.payment_total - (i.item_value + i.freight_value)
) > 0.01
ORDER BY ABS(
    p.payment_total - (i.item_value + i.freight_value)
) DESC
LIMIT 30;



-- ------------------------------------------------------------
-- 3. INSPECT ITEM AND PAYMENT RECORDS FOR A SELECTED ORDER
-- ------------------------------------------------------------
-- PURPOSE:
-- Display the underlying item and payment records for a specific order.
--
-- UNION ALL combines both record types into a common output structure.
-- ITEM rows show product references, item prices, and freight charges.
-- PAYMENT rows show payment sequence, payment type, and payment value.
-- NULL represents freight in payment rows because the payment table
-- does not provide a corresponding freight-value field.
--
-- USE CASE:
-- Investigate the individual records behind an aggregate discrepancy.

SELECT
    'ITEM' AS record_type,
    order_id,
    order_item_id AS sequence_no,
    product_id AS reference_id,
    price AS amount,
    freight_value AS freight
FROM olist_order_items_dataset
WHERE order_id = 'ce6d150fb29ad17d2082f4847107665'

UNION ALL

SELECT
    'PAYMENT',
    order_id,
    payment_sequential,
    payment_type,
    payment_value,
    NULL
FROM olist_order_payments_dataset
WHERE order_id = 'ce6d150fb29ad17d2082f4847107665';



-- ------------------------------------------------------------
-- 4. COUNT ORDERS WITHOUT ITEM OR PAYMENT RECORDS
-- ------------------------------------------------------------
-- PURPOSE:
-- Determine how many orders lack associated item records, payment
-- records, or both.
--
-- The CTEs reduce each detail table to one row per order.
-- LEFT JOIN preserves every order, including orders without matches.
-- NULL checks identify missing relationships.
--
-- KEY METRICS:
-- total_orders: Total orders represented in the orders table.
-- orders_without_items: Orders with no matching item records.
-- orders_without_payments: Orders with no matching payment records.
-- orders_without_either: Orders missing both item and payment records.

WITH item_totals AS (
    SELECT order_id
    FROM olist_order_items_dataset
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    COUNT(*) AS total_orders,
    SUM(i.order_id IS NULL) AS orders_without_items,
    SUM(p.order_id IS NULL) AS orders_without_payments,
    SUM(
        i.order_id IS NULL AND p.order_id IS NULL
    ) AS orders_without_either
FROM olist_orders_dataset o
LEFT JOIN item_totals i ON o.order_id = i.order_id
LEFT JOIN payment_totals p ON o.order_id = p.order_id;



-- ------------------------------------------------------------
-- 5. RETRIEVE THE SINGLE LARGEST FINANCIAL DISCREPANCY
-- ------------------------------------------------------------
-- PURPOSE:
-- Isolate the order with the largest absolute difference between
-- its recorded payment total and item-plus-freight value.
--
-- The calculation is performed at order level after aggregating
-- the item and payment tables separately.
-- ORDER BY ranks the absolute differences in descending order.
-- LIMIT 1 returns only the highest-ranked discrepancy.
--
-- USE CASE:
-- Select a single order for focused investigation of its status,
-- item value, freight charges, payment total, and calculated difference.

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS item_value,
        SUM(freight_value) AS freight_value
    FROM olist_order_items_dataset
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.order_status,
    i.item_value,
    i.freight_value,
    p.payment_total,
    ROUND(
        p.payment_total - (i.item_value + i.freight_value),
        2
    ) AS difference
FROM olist_orders_dataset o
JOIN item_totals i ON o.order_id = i.order_id
JOIN payment_totals p ON o.order_id = p.order_id
WHERE ABS(
    p.payment_total - (i.item_value + i.freight_value)
) > 0.01
ORDER BY ABS(
    p.payment_total - (i.item_value + i.freight_value)
) DESC
LIMIT 1;



-- ------------------------------------------------------------
-- 6. RETRIEVE RAW RECORDS FOR ANOTHER SELECTED ORDER
-- ------------------------------------------------------------
-- PURPOSE:
-- Retrieve all columns from the item and payment tables for a
-- particular order, supporting a more detailed record-level review.
--
-- These SELECT statements are kept separate so each table's original
-- structure and fields can be inspected independently.

SELECT *
FROM olist_order_items_dataset
WHERE order_id = 'ce6d150fb29ada17d2082f4847107665';

SELECT *
FROM olist_order_payments_dataset
WHERE order_id = 'ce6d150fb29ada17d2082f4847107665';



-- ------------------------------------------------------------
-- 7. ANALYZE FINANCIAL DIFFERENCES BY INSTALLMENT GROUP
-- ------------------------------------------------------------
-- PURPOSE:
-- Investigate whether financial discrepancies vary across groups
-- defined by the total number of payment installments.
--
-- CTE LOGIC:
-- item_totals:
--     Calculates the item-plus-freight total for each order.
-- payment_totals:
--     Aggregates payment values, installment counts, and payment
--     record counts for each order.
-- order_reconciliation:
--     Combines the two aggregates and calculates the difference.
--
-- INSTALLMENT GROUPS:
-- 1 installment
-- 2-6 installments
-- 7-12 installments
-- 13+ installments
--
-- OUTPUT METRICS:
-- orders: Number of matched orders in each installment group.
-- orders_with_difference: Number of orders with an absolute
-- difference greater than R$0.01.
-- average_difference: Average signed payment difference.
-- total_difference: Sum of signed payment differences.
--
-- INTERPRETATION:
-- Positive differences indicate recorded payments exceed the
-- item-plus-freight total; negative differences indicate the reverse.
-- These results describe associations in the data and do not establish
-- that installment count causes financial discrepancies.

USE olist_analytics;

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_plus_freight
    FROM olist_order_items_dataset
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total,
        SUM(payment_installments) AS total_installments,
        COUNT(*) AS payment_records
    FROM olist_order_payments_dataset
    GROUP BY order_id
),
order_reconciliation AS (
    SELECT
        i.order_id,
        i.item_plus_freight,
        p.payment_total,
        p.total_installments,
        p.payment_records,
        p.payment_total - i.item_plus_freight AS difference
    FROM item_totals i
    JOIN payment_totals p
        ON i.order_id = p.order_id
)
SELECT
    CASE
        WHEN total_installments = 1 THEN '1 installment'
        WHEN total_installments BETWEEN 2 AND 6 THEN '2-6 installments'
        WHEN total_installments BETWEEN 7 AND 12 THEN '7-12 installments'
        ELSE '13+ installments'
    END AS installment_group,
    COUNT(*) AS orders,
    SUM(ABS(difference) > 0.01) AS orders_with_difference,
    ROUND(AVG(difference), 2) AS average_difference,
    ROUND(SUM(difference), 2) AS total_difference
FROM order_reconciliation
GROUP BY installment_group
ORDER BY installment_group;

USE olist_analytics;

-- =====================================================
-- A. TABLE ROW COUNTS
-- =====================================================
-- PURPOSE:
-- Count the records in each of the nine source tables.
-- This provides a baseline for data-volume validation and
-- helps identify unexpected missing or additional records.
--
-- UNION ALL combines the individual table counts into one result.
-- It retains every row without performing duplicate elimination.

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM olist_customers_dataset
UNION ALL
SELECT 'geolocation', COUNT(*)
FROM olist_geolocation_dataset
UNION ALL
SELECT 'order_items', COUNT(*)
FROM olist_order_items_dataset
UNION ALL
SELECT 'order_payments', COUNT(*)
FROM olist_order_payments_dataset
UNION ALL
SELECT 'order_reviews', COUNT(*)
FROM olist_order_reviews_dataset
UNION ALL
SELECT 'orders', COUNT(*)
FROM olist_orders_dataset
UNION ALL
SELECT 'products', COUNT(*)
FROM olist_products_dataset
UNION ALL
SELECT 'sellers', COUNT(*)
FROM olist_sellers_dataset
UNION ALL
SELECT 'category_translation', COUNT(*)
FROM product_category_name_translation;


-- =====================================================
-- B. FINANCIAL RECONCILIATION BY ORDER STATUS
-- =====================================================
-- PURPOSE:
-- Compare item value, freight value, and recorded payment totals
-- across different order statuses.
--
-- The CTEs aggregate item and payment records separately at order
-- level before joining them to the orders table.
--
-- KEY METRICS:
-- matched_orders: Orders represented in both aggregated datasets.
-- item_value: Total product prices by order status.
-- freight_value: Total freight charges by order status.
-- payment_total: Total recorded payments by order status.
-- net_difference: Payments minus item value minus freight value.
-- orders_over_one_cent: Matched orders with an absolute difference
-- greater than R$0.01.
--
-- INTERPRETATION:
-- Differences by status may help identify patterns for investigation.
-- These results cover matched orders, not orders missing items or
-- payment records.

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price) AS item_value,
        SUM(freight_value) AS freight_value
    FROM olist_order_items_dataset
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM olist_order_payments_dataset
    GROUP BY order_id
)
SELECT
    o.order_status,
    COUNT(*) AS matched_orders,
    ROUND(SUM(i.item_value), 2) AS item_value,
    ROUND(SUM(i.freight_value), 2) AS freight_value,
    ROUND(SUM(p.payment_total), 2) AS payment_total,
    ROUND(
        SUM(p.payment_total - i.item_value - i.freight_value),
        2
    ) AS net_difference,
    SUM(
        ABS(p.payment_total - i.item_value - i.freight_value) > 0.01
    ) AS orders_over_one_cent
FROM olist_orders_dataset o
JOIN item_totals i
    ON o.order_id = i.order_id
JOIN payment_totals p
    ON o.order_id = p.order_id
GROUP BY o.order_status
ORDER BY o.order_status;


-- =====================================================
-- C. ORDERS WITHOUT ITEMS OR PAYMENTS
-- =====================================================
-- PURPOSE:
-- Count orders without associated item records or payment records,
-- grouped by order status.
--
-- DISTINCT produces one order identifier per CTE, preventing
-- multiple item or payment records from multiplying order counts.
-- LEFT JOIN preserves orders even when a matching record is absent.
-- NULL checks identify missing relationships.

WITH item_orders AS (
    SELECT DISTINCT order_id
    FROM olist_order_items_dataset
),
payment_orders AS (
    SELECT DISTINCT order_id
    FROM olist_order_payments_dataset
)
SELECT
    o.order_status,
    COUNT(*) AS total_orders,
    SUM(i.order_id IS NULL) AS orders_without_items,
    SUM(p.order_id IS NULL) AS orders_without_payments
FROM olist_orders_dataset o
LEFT JOIN item_orders i
    ON o.order_id = i.order_id
LEFT JOIN payment_orders p
    ON o.order_id = p.order_id
GROUP BY o.order_status
ORDER BY o.order_status;


-- =====================================================
-- D. PAYMENT VALUE PROFILE
-- =====================================================
-- PURPOSE:
-- Profile payment records by checking for NULL, negative, zero,
-- and positive payment values.
--
-- KEY METRICS:
-- payment_rows: Total number of payment records.
-- null_values: Records where payment_value is NULL.
-- negative_values: Records with payment_value below zero.
-- zero_values: Records with payment_value equal to zero.
-- positive_values: Records with payment_value above zero.
-- total_payment_value: Sum of recorded payment values, rounded
-- to two decimal places.
--
-- INTERPRETATION:
-- Unexpected values should be investigated in the context of the
-- source data and business rules.

SELECT
    COUNT(*) AS payment_rows,
    SUM(payment_value IS NULL) AS null_values,
    SUM(payment_value < 0) AS negative_values,
    SUM(payment_value = 0) AS zero_values,
    SUM(payment_value > 0) AS positive_values,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM olist_order_payments_dataset;


-- =====================================================
-- E. REVIEW GRAIN
-- =====================================================
-- PURPOSE:
-- Examine review-table volume, identifier uniqueness, order coverage,
-- and review-score validity.
--
-- KEY METRICS:
-- review_rows: Total review records.
-- distinct_review_ids: Number of distinct non-NULL review identifiers.
-- distinct_review_order_pairs: Number of distinct non-NULL
-- review_id/order_id combinations.
-- distinct_reviewed_orders: Number of distinct non-NULL order IDs.
-- null_scores: Records without a review score.
-- invalid_scores: Non-NULL scores outside the range 1 through 5.
--
-- ANALYTICAL NOTE:
-- Comparing row counts with distinct identifier counts helps reveal
-- repeated identifiers or multiple records associated with an order.
-- COUNT(DISTINCT review_id, order_id) excludes combinations where
-- either expression is NULL.

SELECT
    COUNT(*) AS review_rows,
    COUNT(DISTINCT review_id) AS distinct_review_ids,
    COUNT(DISTINCT review_id, order_id)
        AS distinct_review_order_pairs,
    COUNT(DISTINCT order_id) AS distinct_reviewed_orders,
    SUM(review_score IS NULL) AS null_scores,
    SUM(review_score NOT BETWEEN 1 AND 5)
        AS invalid_scores
FROM olist_order_reviews_dataset;


-- =====================================================
-- F. DATE VIOLATIONS EXCLUDING ZERO DATES
-- =====================================================
-- PURPOSE:
-- Count timestamp-ordering violations while excluding dates at
-- or below the specified sentinel boundary of '1000-01-01'.
--
-- VALIDATION CHECKS:
-- approval_before_purchase:
--     Approval timestamp occurs before purchase timestamp.
-- delivery_before_carrier:
--     Customer delivery timestamp occurs before carrier delivery.
-- delivery_before_purchase:
--     Customer delivery timestamp occurs before purchase.
--
-- INTERPRETATION:
-- These conditions identify chronology anomalies among records that
-- pass the specified date guards. They do not independently establish
-- why a timestamp is invalid.

SELECT
    SUM(
        order_approved_at < order_purchase_timestamp
        AND order_approved_at > '1000-01-01'
        AND order_purchase_timestamp > '1000-01-01'
    ) AS approval_before_purchase,

    SUM(
        order_delivered_customer_date
            < order_delivered_carrier_date
        AND order_delivered_customer_date > '1000-01-01'
        AND order_delivered_carrier_date > '1000-01-01'
    ) AS delivery_before_carrier,

    SUM(
        order_delivered_customer_date
            < order_purchase_timestamp
        AND order_delivered_customer_date > '1000-01-01'
        AND order_purchase_timestamp > '1000-01-01'
    ) AS delivery_before_purchase
FROM olist_orders_dataset;


-- =====================================================
-- G. ORDERS WITHOUT ITEM RECORDS
-- =====================================================
-- PURPOSE:
-- Retrieve individual orders that have no matching item records.
--
-- LEFT JOIN retains every order, including orders without item rows.
-- The NULL filter selects orders for which no item match exists.
-- Order status and timestamps provide context for further investigation.
--
-- ORDER BY groups results by status and then purchase timestamp.

-- Orders without item records
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_customer_date
FROM olist_orders_dataset o
LEFT JOIN olist_order_items_dataset i
    ON o.order_id = i.order_id
WHERE i.order_id IS NULL
ORDER BY o.order_status, o.order_purchase_timestamp;


-- =====================================================
-- H. ORDERS WITHOUT PAYMENT RECORDS
-- =====================================================
-- PURPOSE:
-- Retrieve individual orders with no associated payment record.
--
-- LEFT JOIN preserves orders without matching payments.
-- The NULL filter identifies those missing payment relationships.
-- Order status and timestamps support contextual investigation.

-- Orders without payment records
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date
FROM olist_orders_dataset o
LEFT JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
WHERE p.order_id IS NULL;


-- =====================================================
-- I. ORDERS WITHOUT ITEMS: STATUS AND ZERO-DATE PROFILE
-- =====================================================
-- PURPOSE:
-- Group orders without item records by order status and count
-- records with zero approval or delivery timestamps.
--
-- NOT EXISTS checks for the absence of a matching item record.
-- DATE_FORMAT converts each timestamp to the specified string format
-- before comparison with the zero-date representation.
--
-- KEY METRICS:
-- orders_without_items: Number of qualifying orders per status.
-- zero_approval_dates: Qualifying orders with a zero approval date.
-- zero_delivery_dates: Qualifying orders with a zero delivery date.
--
-- This analysis helps investigate whether missing item relationships
-- coincide with incomplete timestamp information.

SELECT
    order_status,
    COUNT(*) AS orders_without_items,
    SUM(
        DATE_FORMAT(order_approved_at, '%Y-%m-%d %H:%i:%s')
        = '0000-00-00 00:00:00'
    ) AS zero_approval_dates,
    SUM(
        DATE_FORMAT(order_delivered_customer_date, '%Y-%m-%d %H:%i:%s')
        = '0000-00-00 00:00:00'
    ) AS zero_delivery_dates
FROM olist_orders_dataset o
WHERE NOT EXISTS (
    SELECT 1
    FROM olist_order_items_dataset i
    WHERE i.order_id = o.order_id
)
GROUP BY order_status
ORDER BY orders_without_items DESC;



-- =====================================================
-- J. INVESTIGATE DELIVERED ORDERS WITHOUT PAYMENTS
-- =====================================================
-- PURPOSE:
-- Inspect item and payment fields for delivered orders that have
-- no matching payment records.
--
-- NOT EXISTS identifies orders with no payment rows.
-- LEFT JOIN retains such orders and their item records.
-- Because no payment record exists, payment-side fields will be NULL.


SELECT
    o.order_id,
    o.order_status,
    i.order_id AS item_order_id,
    i.price,
    i.freight_value,
    p.order_id AS payment_order_id,
    p.payment_value
FROM olist_orders_dataset o
LEFT JOIN olist_order_items_dataset i
    ON o.order_id = i.order_id
LEFT JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (
      SELECT 1
      FROM olist_order_payments_dataset p2
      WHERE p2.order_id = o.order_id
  );


-- =====================================================
-- K. SUMMARIZE DELIVERED ORDERS WITHOUT PAYMENTS
-- =====================================================
-- PURPOSE:
-- Produce one result row per delivered order without payment records,
-- including item counts and aggregated item and freight values.
--
-- CORRELATED SUBQUERIES:
-- item_count: Number of item records associated with the order.
-- total_item_value: Sum of item prices, rounded to two decimals.
-- total_freight_value: Sum of freight charges, rounded to two decimals.
-- payment_count: Number of associated payment records.
--
-- NOT EXISTS restricts the results to delivered orders without payments.
-- This summary helps assess the scale and potential financial value
-- associated with missing payment records.

SELECT
    o.order_id,
    o.order_status,

    (
        SELECT COUNT(*)
        FROM olist_order_items_dataset i
        WHERE i.order_id = o.order_id
    ) AS item_count,

    (
        SELECT ROUND(SUM(i.price), 2)
        FROM olist_order_items_dataset i
        WHERE i.order_id = o.order_id
    ) AS total_item_value,

    (
        SELECT ROUND(SUM(i.freight_value), 2)
        FROM olist_order_items_dataset i
        WHERE i.order_id = o.order_id
    ) AS total_freight_value,

    (
        SELECT COUNT(*)
        FROM olist_order_payments_dataset p
        WHERE p.order_id = o.order_id
    ) AS payment_count

FROM olist_orders_dataset o
WHERE o.order_status = 'delivered'
  AND NOT EXISTS (
      SELECT 1
      FROM olist_order_payments_dataset p
      WHERE p.order_id = o.order_id
  );

-- ==============================================================================
-- CONSOLIDATED SECTION: M03 — Reusable data-quality validation framework
-- ==============================================================================

USE olist_analytics;

-- =========================================================
-- M03.1: VALIDATION RULE REGISTRY
-- =========================================================
-- PURPOSE:
-- Create a central registry containing the data-quality rules
-- supported by the validation framework.
--
-- DESIGN:
-- rule_code uniquely identifies each validation rule.
-- rule_name provides a readable rule title.
-- source_table identifies the primary table being validated.
-- severity defines the operational importance of an issue.
-- rule_description explains the condition being investigated.
-- denominator_definition documents the population used to interpret
-- the rule's results.
-- is_active controls whether a rule is evaluated by the procedure.
-- created_at records when the rule was registered.
--
-- The CHECK constraint restricts severity to the four permitted
-- categories, helping maintain consistent issue classification.

CREATE TABLE IF NOT EXISTS dq_rule_registry (
    rule_code VARCHAR(60) PRIMARY KEY,
    rule_name VARCHAR(150) NOT NULL,
    source_table VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    rule_description VARCHAR(500) NOT NULL,
    denominator_definition VARCHAR(300) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_dq_rule_severity
        CHECK (severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW'))
);


-- =========================================================
-- M03.2: VALIDATION RUN HISTORY
-- =========================================================
-- PURPOSE:
-- Maintain one history record for each execution of the
-- data-quality validation procedure.
--
-- DESIGN:
-- run_id uniquely identifies each execution.
-- started_at records when the run begins.
-- completed_at records when the run finishes.
-- run_status tracks whether execution is running, completed,
-- or failed.
-- total_rules_evaluated stores the number of rule-result records.
-- total_issues stores the recorded aggregate of failed rows.
-- quality_score stores the calculated quality percentage.
-- error_message stores diagnostic context if execution fails.
--
-- The status CHECK constraint limits run_status to the supported
-- execution states.

CREATE TABLE IF NOT EXISTS dq_validation_runs (
    run_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at DATETIME NULL,
    run_status VARCHAR(20) NOT NULL DEFAULT 'RUNNING',
    total_rules_evaluated INT UNSIGNED NOT NULL DEFAULT 0,
    total_issues BIGINT UNSIGNED NOT NULL DEFAULT 0,
    quality_score DECIMAL(6,2) NULL,
    error_message TEXT NULL,

    CONSTRAINT chk_dq_run_status
        CHECK (
            run_status IN ('RUNNING', 'COMPLETED', 'FAILED')
        )
);


-- =========================================================
-- M03.3: PER-RULE RESULTS
-- =========================================================
-- PURPOSE:
-- Store the outcome of each validation rule for each execution.
--
-- DESIGN:
-- run_id links the result to a validation run.
-- rule_code identifies the evaluated rule.
-- evaluated_rows records the size of the population checked.
-- failed_rows records how many rows violated the rule.
-- pass_percentage provides a field for storing the rule's
-- calculated pass percentage.
--
-- The composite primary key prevents duplicate result records
-- for the same rule within the same run.
--
-- Foreign keys maintain relationships with the run-history and
-- rule-registry tables.
--
-- The CHECK constraint prevents failed_rows from exceeding
-- evaluated_rows.

CREATE TABLE IF NOT EXISTS dq_rule_results (
    run_id BIGINT UNSIGNED NOT NULL,
    rule_code VARCHAR(60) NOT NULL,
    evaluated_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
    failed_rows BIGINT UNSIGNED NOT NULL DEFAULT 0,
    pass_percentage DECIMAL(6,2) NULL,

    PRIMARY KEY (run_id, rule_code),

    CONSTRAINT fk_dq_result_run
        FOREIGN KEY (run_id)
        REFERENCES dq_validation_runs(run_id),

    CONSTRAINT fk_dq_result_rule
        FOREIGN KEY (rule_code)
        REFERENCES dq_rule_registry(rule_code),

    CONSTRAINT chk_dq_result_counts
        CHECK (failed_rows <= evaluated_rows)
);


-- =========================================================
-- M03.4: INDIVIDUAL ISSUE DETAILS
-- =========================================================
-- PURPOSE:
-- Store row-level details for records identified by validation rules.
--
-- DESIGN:
-- issue_id uniquely identifies an issue record.
-- run_id identifies the execution that detected the issue.
-- rule_code identifies the violated validation rule.
-- entity_table identifies the affected source table.
-- entity_key identifies the affected entity or record.
-- severity classifies the operational importance of the issue.
-- issue_description explains the detected condition.
-- observed_value captures relevant information from the record.
-- expected_condition documents the expected business condition.
-- detected_at records when the issue was logged.
--
-- The unique key prevents the same entity and rule from being
-- recorded more than once within a single validation run.
--
-- Indexes support common investigation patterns:
-- severity-based filtering, rule-based filtering, and entity lookup.
--
-- Foreign keys preserve the relationships with run history and
-- the rule registry. The CHECK constraint validates severity values.

CREATE TABLE IF NOT EXISTS dq_issue_details (
    issue_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    run_id BIGINT UNSIGNED NOT NULL,
    rule_code VARCHAR(60) NOT NULL,
    entity_table VARCHAR(100) NOT NULL,
    entity_key VARCHAR(255) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    issue_description VARCHAR(500) NOT NULL,
    observed_value TEXT NULL,
    expected_condition VARCHAR(500) NOT NULL,
    detected_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- One issue per entity and rule within a run.
    UNIQUE KEY uq_dq_issue_per_run (
        run_id, rule_code, entity_key
    ),

    KEY idx_dq_issue_severity (severity),
    KEY idx_dq_issue_rule (rule_code),
    KEY idx_dq_issue_entity (entity_table, entity_key),

    CONSTRAINT fk_dq_issue_run
        FOREIGN KEY (run_id)
        REFERENCES dq_validation_runs(run_id),

    CONSTRAINT fk_dq_issue_rule
        FOREIGN KEY (rule_code)
        REFERENCES dq_rule_registry(rule_code),

    CONSTRAINT chk_dq_issue_severity
        CHECK (
            severity IN ('CRITICAL', 'HIGH', 'MEDIUM', 'LOW')
        )
);


-- =========================================================
-- M03.5: REGISTER DATA-QUALITY RULES
-- =========================================================
-- PURPOSE:
-- Populate the rule registry with the 12 validation rules
-- implemented by the stored procedure.
--
-- RULE CATEGORIES:
-- Relationship integrity:
--     ORDER_NO_ITEMS
--     DELIVERED_NO_PAYMENT
--     ORPHAN_ITEM_ORDER
--     ORPHAN_PAYMENT_ORDER
--
-- Payment validation:
--     ZERO_PAYMENT
--     NEGATIVE_PAYMENT
--
-- Review validation:
--     INVALID_REVIEW_SCORE
--     DUPLICATE_REVIEW_PAIR
--
-- Timestamp validation:
--     DELIVERED_ZERO_DELIVERY_DATE
--     DELIVERED_ZERO_CARRIER_DATE
--     DELIVERY_BEFORE_CARRIER
--     ZERO_APPROVAL_DATE
--
-- The denominator_definition field documents the intended population
-- for interpreting the corresponding rule's failure count.
--
-- ON DUPLICATE KEY UPDATE makes registry setup repeatable:
-- existing rules are updated rather than causing duplicate-key
-- insertion errors. Fields not listed in the update clause,
-- including is_active and created_at, are not updated by this clause.

INSERT INTO dq_rule_registry (
    rule_code,
    rule_name,
    source_table,
    severity,
    rule_description,
    denominator_definition
)
VALUES
(
    'ORDER_NO_ITEMS',
    'Order has no item records',
    'olist_orders_dataset',
    'MEDIUM',
    'Identifies orders without matching order-item records.',
    'All orders'
),
(
    'DELIVERED_NO_PAYMENT',
    'Delivered order has no payment record',
    'olist_orders_dataset',
    'HIGH',
    'Identifies delivered orders without a matching payment record.',
    'All delivered orders'
),
(
    'ORPHAN_ITEM_ORDER',
    'Order item references missing order',
    'olist_order_items_dataset',
    'HIGH',
    'Identifies item records without a matching order.',
    'All order-item records'
),
(
    'ORPHAN_PAYMENT_ORDER',
    'Payment references missing order',
    'olist_order_payments_dataset',
    'HIGH',
    'Identifies payment records without a matching order.',
    'All payment records'
),
(
    'ZERO_PAYMENT',
    'Zero-value payment record',
    'olist_order_payments_dataset',
    'LOW',
    'Flags zero-value payments for investigation without assuming they are invalid.',
    'All payment records'
),
(
    'NEGATIVE_PAYMENT',
    'Negative payment value',
    'olist_order_payments_dataset',
    'HIGH',
    'Identifies negative payment values.',
    'All payment records'
),
(
    'INVALID_REVIEW_SCORE',
    'Review score outside permitted range',
    'olist_order_reviews_dataset',
    'HIGH',
    'Identifies non-NULL review scores outside 1 through 5.',
    'All review records'
),
(
    'DUPLICATE_REVIEW_PAIR',
    'Repeated review and order pair',
    'olist_order_reviews_dataset',
    'HIGH',
    'Checks whether the candidate review/order key is repeated.',
    'All review records'
),
(
    'DELIVERED_ZERO_DELIVERY_DATE',
    'Delivered order has zero delivery date',
    'olist_orders_dataset',
    'HIGH',
    'Flags delivered orders whose delivery date is represented by a zero date.',
    'All delivered orders'
),
(
    'DELIVERED_ZERO_CARRIER_DATE',
    'Delivered order has zero carrier date',
    'olist_orders_dataset',
    'MEDIUM',
    'Flags delivered orders with a zero carrier-handoff date.',
    'All delivered orders'
),
(
    'DELIVERY_BEFORE_CARRIER',
    'Delivery precedes carrier handoff',
    'olist_orders_dataset',
    'HIGH',
    'Identifies valid timestamps where customer delivery precedes carrier handoff.',
    'Orders with both timestamps valid'
),
(
    'ZERO_APPROVAL_DATE',
    'Zero approval date on an order expected to be approved',
    'olist_orders_dataset',
    'MEDIUM',
    'Flags zero approval dates for statuses expected to have progressed beyond approval.',
    'Orders in delivered, shipped, invoiced, processing or approved status'
)
ON DUPLICATE KEY UPDATE
    rule_name = VALUES(rule_name),
    source_table = VALUES(source_table),
    severity = VALUES(severity),
    rule_description = VALUES(rule_description),
    denominator_definition = VALUES(denominator_definition);
    
-- =========================================================
-- M03.6: STORED PROCEDURE SETUP
-- =========================================================
-- PURPOSE:
-- Create the stored procedure that executes the registered
-- data-quality validation rules and records their results.
--
-- DROP PROCEDURE IF EXISTS removes an existing version so the
-- procedure can be recreated when the script is rerun.
--
-- DELIMITER $$ temporarily changes the statement terminator.
-- This allows MySQL to interpret the semicolons inside the
-- procedure body without ending the CREATE PROCEDURE statement.

USE olist_analytics;

DROP PROCEDURE IF EXISTS sp_run_data_quality_checks;

DELIMITER $$

CREATE PROCEDURE sp_run_data_quality_checks()
BEGIN

    -- -----------------------------------------------------
    -- 1. DECLARE EXECUTION VARIABLES
    -- -----------------------------------------------------
    -- v_run_id identifies the current validation execution.
    -- v_rules stores the number of rule-result records created.
    -- v_issues stores the sum of failed rows across rule results.
    -- v_score stores the calculated overall quality percentage.

    DECLARE v_run_id BIGINT UNSIGNED;
    DECLARE v_rules INT DEFAULT 0;
    DECLARE v_issues BIGINT DEFAULT 0;
    DECLARE v_score DECIMAL(6,2) DEFAULT NULL;


    -- -----------------------------------------------------
    -- 2. HANDLE SQL EXCEPTIONS
    -- -----------------------------------------------------
    -- PURPOSE:
    -- Define how the procedure responds if a SQL exception occurs.
    --
    -- ROLLBACK attempts to undo transactional changes made by the
    -- current execution.
    --
    -- If a run ID has already been assigned, the corresponding
    -- run-history record is marked FAILED and an error message
    -- is stored.
    --
    -- RESIGNAL propagates the original SQL exception so that
    -- the caller can see the execution failure.

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;

        IF v_run_id IS NOT NULL THEN
            UPDATE dq_validation_runs
            SET run_status = 'FAILED',
                completed_at = NOW(),
                error_message =
                    'Validation execution failed. Inspect SQL error output.'
            WHERE run_id = v_run_id;
        END IF;

        RESIGNAL;
    END;


    -- -----------------------------------------------------
    -- 3. INITIALIZE AND START THE VALIDATION RUN
    -- -----------------------------------------------------
    -- Reset the run identifier before starting.
    -- Start a transaction so the validation operations can be
    -- committed together if execution succeeds.

    SET v_run_id = NULL;

    START TRANSACTION;

    -- Create a history record for this execution.
    -- The default status is RUNNING.

    INSERT INTO dq_validation_runs (run_status)
    VALUES ('RUNNING');

    -- Capture the automatically generated identifier for this run.

    SET v_run_id = LAST_INSERT_ID();


    -- =====================================================
    -- RULE 1: ORDERS WITHOUT ITEMS
    -- =====================================================
    -- PURPOSE:
    -- Identify orders that have no corresponding item records.
    --
    -- The rule runs only when its registry entry exists and is active.
    --
    -- RULE RESULT:
    -- evaluated_rows counts all orders.
    -- failed_rows counts orders without matching item records.
    --
    -- ISSUE DETAILS:
    -- Store the affected order ID, order status, severity,
    -- observed information, and expected business condition.
    --
    -- Orders in delivered, shipped, or invoiced status are assigned
    -- HIGH severity by this rule; other statuses receive MEDIUM.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'ORDER_NO_ITEMS'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'ORDER_NO_ITEMS',
            COUNT(*),
            SUM(
                NOT EXISTS (
                    SELECT 1
                    FROM olist_order_items_dataset i
                    WHERE i.order_id = o.order_id
                )
            )
        FROM olist_orders_dataset o;

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'ORDER_NO_ITEMS',
            'olist_orders_dataset',
            o.order_id,
            CASE
                WHEN o.order_status IN (
                    'delivered', 'shipped', 'invoiced'
                ) THEN 'HIGH'
                ELSE 'MEDIUM'
            END,
            'Order has no matching order-item records.',
            CONCAT('order_status=', o.order_status),
            'An order expected to contain items should have matching item records.'
        FROM olist_orders_dataset o
        WHERE NOT EXISTS (
            SELECT 1
            FROM olist_order_items_dataset i
            WHERE i.order_id = o.order_id
        );

    END IF;


    -- =====================================================
    -- RULE 2: DELIVERED ORDER WITHOUT PAYMENT
    -- =====================================================
    -- PURPOSE:
    -- Identify delivered orders without matching payment records.
    --
    -- RESULT:
    -- evaluated_rows counts delivered orders.
    -- failed_rows counts delivered orders for which no payment
    -- record exists.
   

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'DELIVERED_NO_PAYMENT'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'DELIVERED_NO_PAYMENT',
            COUNT(*),
            SUM(
                NOT EXISTS (
                    SELECT 1
                    FROM olist_order_payments_dataset p
                    WHERE p.order_id = o.order_id
                )
            )
        FROM olist_orders_dataset o
        WHERE o.order_status = 'delivered';

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'DELIVERED_NO_PAYMENT',
            'olist_orders_dataset',
            o.order_id,
            'HIGH',
            'Delivered order has no matching payment record.',
            CONCAT('order_status=', o.order_status),
            'A delivered order should have a traceable payment record under the selected business rule.'
        FROM olist_orders_dataset o
        WHERE o.order_status = 'delivered'
          AND NOT EXISTS (
              SELECT 1
              FROM olist_order_payments_dataset p
              WHERE p.order_id = o.order_id
          );

    END IF;


    -- =====================================================
    -- RULE 3: ORPHAN ORDER ITEMS
    -- =====================================================
    -- PURPOSE:
    -- Identify order-item records whose order_id does not exist
    -- in the main orders table.
    --
    -- RULE RESULT:
    -- evaluated_rows counts all order-item records.
    -- failed_rows counts item records without a matching order.
    --
    -- ISSUE DETAILS:
    -- The entity key combines order_id and order_item_id to identify
    -- the individual item record being investigated.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'ORPHAN_ITEM_ORDER'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'ORPHAN_ITEM_ORDER',
            COUNT(*),
            SUM(
                NOT EXISTS (
                    SELECT 1
                    FROM olist_orders_dataset o
                    WHERE o.order_id = i.order_id
                )
            )
        FROM olist_order_items_dataset i;

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'ORPHAN_ITEM_ORDER',
            'olist_order_items_dataset',
            CONCAT(i.order_id, ':', i.order_item_id),
            'HIGH',
            'Order-item record references a missing order.',
            CONCAT('order_id=', i.order_id),
            'Every item record should reference an existing order.'
        FROM olist_order_items_dataset i
        WHERE NOT EXISTS (
            SELECT 1
            FROM olist_orders_dataset o
            WHERE o.order_id = i.order_id
        );

    END IF;


    -- =====================================================
    -- RULE 4: ORPHAN PAYMENTS
    -- =====================================================
    -- PURPOSE:
    -- Identify payment records whose order_id does not exist
    -- in the main orders table.
    --
    -- RULE RESULT:
    -- evaluated_rows counts all payment records.
    -- failed_rows counts payment records without a matching order.
    --
    -- ISSUE DETAILS:
    -- The entity key combines order_id and payment_sequential
    -- to identify the specific payment record.
    -- Orphan payment records are assigned HIGH severity.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'ORPHAN_PAYMENT_ORDER'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'ORPHAN_PAYMENT_ORDER',
            COUNT(*),
            SUM(
                NOT EXISTS (
                    SELECT 1
                    FROM olist_orders_dataset o
                    WHERE o.order_id = p.order_id
                )
            )
        FROM olist_order_payments_dataset p;

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'ORPHAN_PAYMENT_ORDER',
            'olist_order_payments_dataset',
            CONCAT(p.order_id, ':', p.payment_sequential),
            'HIGH',
            'Payment record references a missing order.',
            CONCAT('order_id=', p.order_id),
            'Every payment record should reference an existing order.'
        FROM olist_order_payments_dataset p
        WHERE NOT EXISTS (
            SELECT 1
            FROM olist_orders_dataset o
            WHERE o.order_id = p.order_id
        );

    END IF;
    
    -- =====================================================
    -- RULE 5: ZERO-VALUE PAYMENTS
    -- =====================================================
    -- PURPOSE:
    -- Identify payment records where payment_value equals zero.
    --
    -- RULE RESULT:
    -- evaluated_rows counts all payment records.
    -- failed_rows counts records with a zero payment value.
    --
    -- ISSUE DETAILS:
    -- Record the order ID, payment sequence, payment type,
    -- and observed payment value for investigation.
    --
    -- Zero-value payments are classified as LOW severity.
    -- A zero amount is flagged for review, not automatically
    -- treated as invalid.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'ZERO_PAYMENT'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'ZERO_PAYMENT',
            COUNT(*),
            SUM(payment_value = 0)
        FROM olist_order_payments_dataset;

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'ZERO_PAYMENT',
            'olist_order_payments_dataset',
            CONCAT(p.order_id, ':', p.payment_sequential),
            'LOW',
            'Zero-value payment requires review.',
            CONCAT(
                'payment_type=', p.payment_type,
                '; payment_value=', p.payment_value
            ),
            'Investigate zero-value payments; zero does not automatically mean invalid.'
        FROM olist_order_payments_dataset p
        WHERE p.payment_value = 0;

    END IF;


    -- =====================================================
    -- RULE 6: NEGATIVE PAYMENTS
    -- =====================================================
    -- PURPOSE:
    -- Identify payment records with payment_value below zero.
    --
    -- RULE RESULT:
    -- evaluated_rows counts all payment records.
    -- failed_rows counts records with negative payment values.
    --
    -- ISSUE DETAILS:
    -- Store the payment identifier and observed negative amount.
    -- Negative payments are assigned HIGH severity for investigation.
    --
    -- A negative value should be checked against source records and
    -- the applicable financial definition before being classified
    -- as an actual data error.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'NEGATIVE_PAYMENT'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'NEGATIVE_PAYMENT',
            COUNT(*),
            SUM(payment_value < 0)
        FROM olist_order_payments_dataset;

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'NEGATIVE_PAYMENT',
            'olist_order_payments_dataset',
            CONCAT(p.order_id, ':', p.payment_sequential),
            'HIGH',
            'Negative payment value detected.',
            CAST(p.payment_value AS CHAR),
            'Investigate negative payment amounts against the source and financial definition.'
        FROM olist_order_payments_dataset p
        WHERE p.payment_value < 0;

    END IF;


    -- =====================================================
    -- RULE 7: INVALID REVIEW SCORES
    -- =====================================================
    -- PURPOSE:
    -- Identify non-NULL review scores outside the permitted
    -- range of 1 through 5.
    --
    -- RULE RESULT:
    -- evaluated_rows counts all review records.
    -- failed_rows counts non-NULL scores outside the permitted range.
    --
    -- ISSUE DETAILS:
    -- Store the review/order identifier pair and observed score.
    -- Invalid review scores are classified as HIGH severity.
    --
    -- NULL scores are excluded from this rule's failure condition;
    -- this rule does not evaluate missing review scores.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'INVALID_REVIEW_SCORE'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'INVALID_REVIEW_SCORE',
            COUNT(*),
            SUM(
                review_score IS NOT NULL
                AND review_score NOT BETWEEN 1 AND 5
            )
        FROM olist_order_reviews_dataset;

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'INVALID_REVIEW_SCORE',
            'olist_order_reviews_dataset',
            CONCAT(r.review_id, ':', r.order_id),
            'HIGH',
            'Review score is outside the permitted range.',
            CAST(r.review_score AS CHAR),
            'Non-NULL review scores must be integers from 1 through 5.'
        FROM olist_order_reviews_dataset r
        WHERE r.review_score IS NOT NULL
          AND r.review_score NOT BETWEEN 1 AND 5;

    END IF;


    -- =====================================================
    -- RULE 8: DUPLICATE REVIEW/ORDER PAIRS
    -- =====================================================
    -- PURPOSE:
    -- Identify review/order combinations that occur more than once.
    --
    -- RULE RESULT:
    -- The inner query groups review records by review_id and order_id.
    -- The outer query counts the resulting groups and sums the
    -- excess occurrences beyond the first record in each group.
    --
    -- For example, a pair occurring three times contributes two
    -- excess occurrences to failed_rows.
    --
    -- ISSUE DETAILS:
    -- GROUP BY identifies repeated pairs.
    -- HAVING COUNT(*) > 1 retains only pairs with multiple records.
    -- The occurrence count is stored as observed_value.
    --
    -- IMPORTANT:
    -- This rule checks a candidate composite key. A repeated pair
    -- should be investigated before assuming the records are invalid.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'DUPLICATE_REVIEW_PAIR'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'DUPLICATE_REVIEW_PAIR',
            COUNT(*),
            COALESCE(SUM(pair_count - 1), 0)
        FROM (
            SELECT COUNT(*) AS pair_count
            FROM olist_order_reviews_dataset
            GROUP BY review_id, order_id
        ) pairs;

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'DUPLICATE_REVIEW_PAIR',
            'olist_order_reviews_dataset',
            CONCAT(r.review_id, ':', r.order_id),
            'HIGH',
            'Review/order pair occurs more than once.',
            CONCAT('occurrences=', COUNT(*)),
            'Each review_id/order_id pair should occur once.'
        FROM olist_order_reviews_dataset r
        GROUP BY r.review_id, r.order_id
        HAVING COUNT(*) > 1;

    END IF;
    
        -- =====================================================
    -- RULE 9: DELIVERED ORDERS WITH ZERO DELIVERY DATE
    -- =====================================================
    -- PURPOSE:
    -- Identify delivered orders whose customer-delivery timestamp
    -- is represented by a zero date.
    --
    -- RULE RESULT:
    -- evaluated_rows counts all delivered orders.
    -- failed_rows counts delivered orders matching the zero-date
    -- comparison, with COALESCE returning zero if the aggregate is NULL.
    --
    -- ISSUE DETAILS:
    -- Record each affected order ID and the observed delivery timestamp.
    -- These issues are assigned HIGH severity.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'DELIVERED_ZERO_DELIVERY_DATE'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'DELIVERED_ZERO_DELIVERY_DATE',
            COUNT(*),
            COALESCE(SUM(
                DATE_FORMAT(
                    order_delivered_customer_date,
                    '%Y-%m-%d %H:%i:%s'
                ) = '0000-00-00 00:00:00'
            ), 0)
        FROM olist_orders_dataset
        WHERE order_status = 'delivered';

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'DELIVERED_ZERO_DELIVERY_DATE',
            'olist_orders_dataset',
            o.order_id,
            'HIGH',
            'Delivered order has a zero delivery date.',
            DATE_FORMAT(
                o.order_delivered_customer_date,
                '%Y-%m-%d %H:%i:%s'
            ),
            'A delivered order should have a valid customer delivery timestamp.'
        FROM olist_orders_dataset o
        WHERE o.order_status = 'delivered'
          AND DATE_FORMAT(
              o.order_delivered_customer_date,
              '%Y-%m-%d %H:%i:%s'
          ) = '0000-00-00 00:00:00';

    END IF;


    -- =====================================================
    -- RULE 10: DELIVERED ORDERS WITH ZERO CARRIER DATE
    -- =====================================================
    -- PURPOSE:
    -- Identify delivered orders whose carrier-handoff timestamp
    -- is represented by a zero date.
    --
    -- RULE RESULT:
    -- evaluated_rows counts all delivered orders.
    -- failed_rows counts delivered orders matching the zero-date
    -- comparison.
    --
    -- ISSUE DETAILS:
    -- Store the affected order and observed carrier timestamp.
    -- These issues are assigned MEDIUM severity so that missing
    -- carrier-handoff information can be investigated.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'DELIVERED_ZERO_CARRIER_DATE'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'DELIVERED_ZERO_CARRIER_DATE',
            COUNT(*),
            COALESCE(SUM(
                DATE_FORMAT(
                    order_delivered_carrier_date,
                    '%Y-%m-%d %H:%i:%s'
                ) = '0000-00-00 00:00:00'
            ), 0)
        FROM olist_orders_dataset
        WHERE order_status = 'delivered';

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'DELIVERED_ZERO_CARRIER_DATE',
            'olist_orders_dataset',
            o.order_id,
            'MEDIUM',
            'Delivered order has a zero carrier-handoff date.',
            DATE_FORMAT(
                o.order_delivered_carrier_date,
                '%Y-%m-%d %H:%i:%s'
            ),
            'Investigate missing carrier-handoff dates for delivered orders.'
        FROM olist_orders_dataset o
        WHERE o.order_status = 'delivered'
          AND DATE_FORMAT(
              o.order_delivered_carrier_date,
              '%Y-%m-%d %H:%i:%s'
          ) = '0000-00-00 00:00:00';

    END IF;


    -- =====================================================
    -- RULE 11: DELIVERY BEFORE CARRIER HANDOFF
    -- =====================================================
    -- PURPOSE:
    -- Identify records where customer delivery is timestamped
    -- before carrier handoff.
    --
    -- DATE GUARDS:
    -- Both timestamps must be greater than '1000-01-01' so that
    -- the comparison excludes dates at or below this boundary.
    --
    -- RULE RESULT:
    -- evaluated_rows counts orders with both timestamps passing
    -- the date guards.
    -- failed_rows counts qualifying records where delivery precedes
    -- carrier handoff.
    --
    -- ISSUE DETAILS:
    -- Store both timestamps to make the chronology violation
    -- easier to investigate. These issues are assigned HIGH severity.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'DELIVERY_BEFORE_CARRIER'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'DELIVERY_BEFORE_CARRIER',
            COUNT(*),
            COALESCE(SUM(
                order_delivered_customer_date
                    < order_delivered_carrier_date
                AND order_delivered_customer_date > '1000-01-01'
                AND order_delivered_carrier_date > '1000-01-01'
            ), 0)
        FROM olist_orders_dataset
        WHERE order_delivered_customer_date > '1000-01-01'
          AND order_delivered_carrier_date > '1000-01-01';

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'DELIVERY_BEFORE_CARRIER',
            'olist_orders_dataset',
            o.order_id,
            'HIGH',
            'Customer delivery precedes carrier handoff.',
            CONCAT(
                'carrier=', o.order_delivered_carrier_date,
                '; delivery=', o.order_delivered_customer_date
            ),
            'For valid timestamps, customer delivery should not precede carrier handoff.'
        FROM olist_orders_dataset o
        WHERE o.order_delivered_customer_date
                  < o.order_delivered_carrier_date
          AND o.order_delivered_customer_date > '1000-01-01'
          AND o.order_delivered_carrier_date > '1000-01-01';

    END IF;


    -- =====================================================
    -- RULE 12: ZERO APPROVAL DATE FOR EXPECTED STATUSES
    -- =====================================================
    -- PURPOSE:
    -- Identify orders in selected progressed statuses whose
    -- approval timestamp is represented by a zero date.
    --
    -- STATUSES CHECKED:
    -- delivered, shipped, invoiced, processing, and approved.
    --
    -- RULE RESULT:
    -- evaluated_rows counts orders in the selected statuses.
    -- failed_rows counts records matching the zero-date comparison.
    --
    -- ISSUE DETAILS:
    -- Record the affected order and its status for investigation.
    -- These issues are assigned MEDIUM severity.

    IF EXISTS (
        SELECT 1
        FROM dq_rule_registry
        WHERE rule_code = 'ZERO_APPROVAL_DATE'
          AND is_active = TRUE
    ) THEN

        INSERT INTO dq_rule_results (
            run_id, rule_code, evaluated_rows, failed_rows
        )
        SELECT
            v_run_id,
            'ZERO_APPROVAL_DATE',
            COUNT(*),
            COALESCE(SUM(
                DATE_FORMAT(
                    order_approved_at,
                    '%Y-%m-%d %H:%i:%s'
                ) = '0000-00-00 00:00:00'
            ), 0)
        FROM olist_orders_dataset
        WHERE order_status IN (
            'delivered', 'shipped', 'invoiced',
            'processing', 'approved'
        );

        INSERT INTO dq_issue_details (
            run_id, rule_code, entity_table, entity_key,
            severity, issue_description, observed_value,
            expected_condition
        )
        SELECT
            v_run_id,
            'ZERO_APPROVAL_DATE',
            'olist_orders_dataset',
            o.order_id,
            'MEDIUM',
            'Order has a zero approval date despite its status.',
            CONCAT('order_status=', o.order_status),
            'Investigate zero approval dates for orders expected to have progressed beyond approval.'
        FROM olist_orders_dataset o
        WHERE o.order_status IN (
            'delivered', 'shipped', 'invoiced',
            'processing', 'approved'
        )
          AND DATE_FORMAT(
              o.order_approved_at,
              '%Y-%m-%d %H:%i:%s'
          ) = '0000-00-00 00:00:00';

    END IF;


    -- =====================================================
    -- FINALIZE RUN AND CALCULATE QUALITY SCORE
    -- =====================================================
    -- PURPOSE:
    -- Summarize the rule results generated during this run,
    -- calculate an overall quality percentage, and update run history.
    --
    -- v_rules:
    -- Number of rule-result records for the current run.
    --
    -- v_issues:
    -- Sum of failed_rows across the recorded rule results.
    --
    -- v_score:
    -- Percentage calculated as:
    -- (total evaluated rows - total failed rows)
    -- / total evaluated rows * 100.
    --
    -- If the total evaluated row count is zero, the score is NULL.
    --
    -- The run is then marked COMPLETED, the transaction is committed,
    -- and the summary record for this execution is returned.

    SELECT
        COUNT(*),
        COALESCE(SUM(failed_rows), 0),
        CASE
            WHEN SUM(evaluated_rows) = 0 THEN NULL
            ELSE ROUND(
                100.0 * (
                    SUM(evaluated_rows) - SUM(failed_rows)
                ) / SUM(evaluated_rows),
                2
            )
        END
    INTO v_rules, v_issues, v_score
    FROM dq_rule_results
    WHERE run_id = v_run_id;

    -- Update the execution history with the final metrics and status.

    UPDATE dq_validation_runs
    SET completed_at = NOW(),
        run_status = 'COMPLETED',
        total_rules_evaluated = v_rules,
        total_issues = v_issues,
        quality_score = v_score
    WHERE run_id = v_run_id;

    -- Commit the successful validation run and its recorded results.

    COMMIT;

    -- Return the summary of the completed validation run.

    SELECT
        run_id,
        run_status,
        started_at,
        completed_at,
        total_rules_evaluated,
        total_issues,
        quality_score
    FROM dq_validation_runs
    WHERE run_id = v_run_id;

END$$

-- Restore the standard SQL statement delimiter.

DELIMITER ;

-- =========================================================
-- EXECUTE THE DATA-QUALITY VALIDATION FRAMEWORK
-- =========================================================
-- PURPOSE:
-- Invoke the stored procedure to execute the active rules,
-- persist the results, and return the run summary.

CALL sp_run_data_quality_checks();
