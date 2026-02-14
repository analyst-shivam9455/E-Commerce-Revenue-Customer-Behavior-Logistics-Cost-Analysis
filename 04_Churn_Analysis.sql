-- ---------------------------------------------------------Section C (Churn Analysis)----------------------------------------------------------
USE olist_practice;

-- Define churned customers (no order in last 90 days)
WITH dataset_last_order_date AS(
	SELECT 
		MAX(order_purchase_timestamp) as last_order_date
	FROM order_revenue 
)

SELECT 
	o.customer_unique_id,
    MAX(o.order_purchase_timestamp) AS last_order_date,
    CASE 
		WHEN MAX(o.order_purchase_timestamp) < DATE_SUB(MAX(d.last_order_date), INTERVAL 90 DAY)
        THEN 'Churned Customer'
        ELSE 'Active Customer'
	END as customer_type
FROM order_revenue o
CROSS JOIN dataset_last_order_date d
GROUP BY o.customer_unique_id;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Monthly churn count
WITH dataset_last_date AS(
	SELECT 
		MAX(order_purchase_timestamp) AS as_of_date
	FROM order_revenue
),
customer_last_date AS (
	SELECT 
		customer_unique_id,
		MAX(order_purchase_timestamp) as last_order_date
	FROM order_revenue
	GROUP BY customer_unique_id
),
churn_base AS (
	SELECT 
		c.customer_unique_id,
		c.last_order_date,
		DATE_ADD(c.last_order_date, INTERVAL 90 DAY) as churn_date
	FROM customer_last_date c
	CROSS JOIN dataset_last_date d 
	WHERE DATE_ADD(c.last_order_date, INTERVAL 90 DAY) <= d.as_of_date
)

SELECT 
	DATE_FORMAT(churn_date, '%Y-%m-01') AS churn_month,
	COUNT(DISTINCT customer_unique_id) AS churn_count
FROM churn_base
GROUP BY DATE_FORMAT(churn_date, '%Y-%m-01')
ORDER BY churn_month;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Monthly churn rate
WITH dataset_date AS (
		SELECT MAX(order_purchase_timestamp) AS as_of_date
		FROM order_revenue
),
customer_last_date AS (
    SELECT 
        customer_unique_id,
        MAX(order_purchase_timestamp) AS last_order_date
    FROM order_revenue
    GROUP BY customer_unique_id
),

churn_base AS (
    SELECT 
        c.customer_unique_id,
        DATE_ADD(c.last_order_date, INTERVAL 90 DAY) AS churn_date,
        d.as_of_date
    FROM customer_last_date c
    CROSS JOIN dataset_date d
    WHERE DATE_ADD(c.last_order_date, INTERVAL 90 DAY) <= d.as_of_date
),
monthly_churn AS (
    SELECT 
        DATE_FORMAT(churn_date, '%Y-%m-01') AS month,
        COUNT(DISTINCT customer_unique_id) AS churned_customers
    FROM churn_base
    GROUP BY month
),
monthly_active_base AS (
    SELECT DISTINCT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS month,
        c.customer_unique_id
    FROM order_revenue o
    JOIN customer_last_date c
        ON o.customer_unique_id = c.customer_unique_id
),
monthly_active AS (
    SELECT
        m.month,
        COUNT(DISTINCT m.customer_unique_id) AS active_customers
    FROM monthly_active_base m
    LEFT JOIN churn_base cb
        ON m.customer_unique_id = cb.customer_unique_id
       AND cb.churn_date < m.month
    WHERE cb.customer_unique_id IS NULL
    GROUP BY m.month
)
SELECT
    mc.month,
    mc.churned_customers,
    ma.active_customers,
    ROUND(mc.churned_customers / ma.active_customers, 4) AS monthly_churn_rate
FROM monthly_churn mc
JOIN monthly_active ma
    ON mc.month = ma.month
ORDER BY mc.month;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Revenue lost from churned customers
WITH dataset_last_order_date AS ( 
    SELECT MAX(order_purchase_timestamp) AS as_of_date 
    FROM order_revenue 
), 

churned_customer AS (
    SELECT   
        o.customer_unique_id,     
        MAX(o.order_purchase_timestamp) AS customer_last_order_date,     
        CASE    
            WHEN MAX(o.order_purchase_timestamp) < DATE_SUB(d.as_of_date, INTERVAL 90 DAY)
			THEN 'Churned Customer'         
            ELSE 'Active Customer'  
        END AS customer_type 
    FROM order_revenue o 
    CROSS JOIN dataset_last_order_date d 
    GROUP BY o.customer_unique_id 
),

monthly_revenue_per_customer AS (
    SELECT
        o.customer_unique_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS order_month,
        SUM(o.order_value) AS monthly_revenue
    FROM order_revenue o
    JOIN churned_customer c
        ON o.customer_unique_id = c.customer_unique_id
    GROUP BY 
        o.customer_unique_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01')
),

average_monthly_revenue AS (
    SELECT
        AVG(monthly_revenue) AS avg_monthly_revenue
    FROM monthly_revenue_per_customer
)

SELECT  
    MAX(a.avg_monthly_revenue) AS avg_monthly_revenue,
    COUNT(DISTINCT c.customer_unique_id) AS churned_customer_count,
    3 AS horizon_month,
    ROUND(
        MAX(a.avg_monthly_revenue) 
        * COUNT(DISTINCT c.customer_unique_id) 
        * 3,
        2
    ) AS revenue_lost
FROM churned_customer c
CROSS JOIN average_monthly_revenue a
WHERE c.customer_type = 'Churned Customer';
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- High-value customers who churned
WITH dataset_date AS (
    SELECT MAX(order_purchase_timestamp) AS as_of_date
    FROM order_revenue
),
customer_lifetime_revenue AS (
    SELECT
        customer_unique_id,
        SUM(order_value) AS lifetime_revenue
    FROM order_revenue
    GROUP BY customer_unique_id
),
high_value_customers AS (
    SELECT
        customer_unique_id,
        lifetime_revenue,
        NTILE(5) OVER (ORDER BY lifetime_revenue DESC) AS revenue_bucket
    FROM customer_lifetime_revenue
),
churned_customers AS (
    SELECT
        o.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_order_date
    FROM order_revenue o
    CROSS JOIN dataset_date d
    GROUP BY o.customer_unique_id
    HAVING MAX(o.order_purchase_timestamp)
           < DATE_SUB(MAX(d.as_of_date), INTERVAL 90 DAY)
)
SELECT
    h.customer_unique_id,
    h.lifetime_revenue,
    c.last_order_date
FROM high_value_customers h
JOIN churned_customers c
    ON h.customer_unique_id = c.customer_unique_id
WHERE h.revenue_bucket = 1
ORDER BY h.lifetime_revenue DESC;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Retention rate month-over-month
WITH monthly_customers AS (
    SELECT DISTINCT
        customer_unique_id,
        DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS month
    FROM order_revenue
),
retention AS (
    SELECT
        curr.month,
        COUNT(DISTINCT curr.customer_unique_id) AS retained_customers,
        COUNT(DISTINCT prev.customer_unique_id) AS previous_month_customers
    FROM monthly_customers curr
    LEFT JOIN monthly_customers prev
        ON curr.customer_unique_id = prev.customer_unique_id
       AND prev.month = DATE_SUB(curr.month, INTERVAL 1 MONTH)
    GROUP BY curr.month
)
SELECT
    month,
    ROUND(retained_customers / previous_month_customers * 100, 2)
        AS retention_rate_pct
FROM retention
WHERE previous_month_customers IS NOT NULL
ORDER BY month;
-- (----------------------------------------------------------------------------------------------------------------------------------------)