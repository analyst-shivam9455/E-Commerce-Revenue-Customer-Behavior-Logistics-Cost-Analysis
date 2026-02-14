USE olist_practice;
/* =========================================================
   DATA UNDERSTANDING SCRIPT
   Project: E-Commerce Sales Analysis
   Purpose: Understand structure, quality, and key metrics
   ========================================================= */


/* =========================================================
   View all tables
   ========================================================= */

SHOW TABLES;


/* =========================================================
   Understanding table structure
   ========================================================= */

DESCRIBE olist_customers;
DESCRIBE olist_orders;
DESCRIBE olist_order_items;
DESCRIBE olist_products;
DESCRIBE olist_order_payments;


/* =========================================================
   Checking number of records in each table
   ========================================================= */

SELECT COUNT(*) AS total_customers FROM olist_customers;

SELECT COUNT(*) AS total_orders FROM olist_orders;

SELECT COUNT(*) AS total_order_items FROM olist_order_items;

SELECT COUNT(*) AS total_products FROM olist_products;

SELECT COUNT(*) AS total_payments FROM olist_order_payments;


/* =========================================================
   Checking date range of order.
   ========================================================= */

SELECT 
    MIN(order_purchase_timestamp) AS first_order_date,
    MAX(order_purchase_timestamp) AS last_order_date
FROM olist_orders;


/* =========================================================
   Checking order status of orders.
   ========================================================= */

SELECT 
    order_status,
    COUNT(*) AS total_orders
FROM olist_orders
GROUP BY order_status
ORDER BY total_orders DESC;


/* =========================================================
   Checking unique customers
   ========================================================= */

SELECT 
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM olist_customers;


/* =========================================================
   Check total revenue
   ========================================================= */

SELECT 
    ROUND(SUM(price + freight_value), 2) AS total_revenue
FROM olist_order_items;


/* =========================================================
  Average order value
   ========================================================= */

SELECT 
    ROUND(AVG(order_total), 2) AS avg_order_value
FROM (
    SELECT 
        order_id,
        SUM(price + freight_value) AS order_total
    FROM olist_order_items
    GROUP BY order_id
) AS order_values;


/* =========================================================
   Checking Missing values
   ========================================================= */

SELECT 
    COUNT(*) AS missing_product_category
FROM olist_products
WHERE product_category_name IS NULL;


SELECT 
    COUNT(*) AS missing_customer_city
FROM olist_customers
WHERE customer_city IS NULL;





/* =========================================================
	Creating views for further analysis
   ========================================================= */


CREATE VIEW order_revenue AS
	SELECT 
		c.customer_unique_id,
		o.order_id,
		o.order_purchase_timestamp,
        SUM(oi.freight_value) AS total_freight,
        SUM(oi.price) AS total_price,
        SUM(oi.price - oi.freight_value)  as net_value
	FROM olist_customers c
	JOIN olist_orders o ON c.customer_id = o.customer_id
	JOIN olist_order_items oi ON o.order_id = oi.order_id
	WHERE o.order_status = 'delivered'
	GROUP BY 
		c.customer_unique_id,
		o.order_id,
		o.order_purchase_timestamp;
-- I’m summing freight at item-level because the dataset provides freight per item.
-- In real commerce platforms, freight is order-level, so I would handle it differently.



-- (----------------------------------------------------------------------------------------------------------------------------------------)
CREATE VIEW customer_behaviour AS
SELECT 
	customer_unique_id,
    COUNT(order_id) AS total_orders,
    MIN(order_purchase_timestamp) AS first_order,
    MAX(order_purchase_timestamp) AS last_order
FROM order_revenue
GROUP BY customer_unique_id;

-- (----------------------------------------------------------------------------------------------------------------------------------------)



CREATE VIEW monthly_revenue AS
	SELECT 
		DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS order_month,
		SUM(order_value) AS monthly_spent
	FROM order_revenue
	GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01');
-- (----------------------------------------------------------------------------------------------------------------------------------------)