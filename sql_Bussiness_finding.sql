USE olist_practice;

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

-- --------------------------------------------------- Section A (Revenue Diagnosis) --------------------------------------------------------
-- Monthly total revenue and MoM growth %
SELECT
	order_month,
	monthly_spent,
	((( monthly_spent - 
    LAG(monthly_spent) OVER(ORDER BY order_month))
    / NULLIF(LAG(monthly_spent) OVER(ORDER BY order_month), 0))*100) 
    AS MOM_growth_percentage
FROM monthly_revenue
ORDER BY order_month;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Average order value per month
SELECT 
	DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS order_month,
    AVG(order_value) as AOV
FROM olist_practice.order_revenue
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01')
ORDER BY order_month;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Revenue split between first time and repeate customer(mothly).
WITH customer_first_order AS (
	SELECT 
		customer_id,
		DATE_FORMAT(
			MIN(order_purchase_timestamp), 
			'%Y-%m-01'
		) AS first_order_month
	FROM order_revenue
	GROUP BY customer_id
	),
curr_order_month AS (
	SELECT 
		o.customer_id, 
		o.order_value,
		curr. first_order_month,
		DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m-01') AS order_month
	FROM customer_first_order curr
	JOIN olist_practice.order_revenue o 
	ON curr.customer_id = o.customer_id
)
SELECT 
	order_month,
	SUM(
		CASE 
			WHEN order_month = first_order_month 
				THEN order_value 
            ELSE 0 
		END
	) as first_time_revenue,
    SUM(
		CASE 
			WHEN order_month > first_order_month 
            THEN order_value 
            ELSE 0 
		END
	) as repeate_revenue
FROM curr_order_month 
GROUP BY order_month
ORDER BY order_month;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Top 10 customers contributing highest revenue
WITH customer_revenue AS(
	SELECT 
		customer_id,
		SUM(order_value) AS customer_spend
	FROM order_revenue
	GROUP BY customer_id
),

ranked_customer AS (
	SELECT 
		customer_id,
		customer_spend,
		DENSE_RANK() OVER(ORDER BY customer_spend DESC) as rn
	FROM customer_revenue
)

SELECT 
	customer_id,
    customer_spend
FROM ranked_customer
WHERE rn <= 10;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Percentage of revenue from top 20% customers
WITH customer_revenue AS (
	SELECT 
		customer_unique_id,
		SUM(order_value) as customer_spent
	FROM order_revenue
	GROUP BY customer_unique_id
),
top_customer AS(
	SELECT 
		customer_unique_id,
		customer_spent,
		NTILE(5) OVER(ORDER BY customer_spent DESC) AS revenue_bucket
	FROM customer_revenue
),
top_customer_revenue AS(
	SELECT 
		SUM(customer_spent) AS top_20_percentile_revenue
	FROM top_customer
	WHERE revenue_bucket = 1
)

SELECT 
ROUND(
	(top_20_percentile_revenue
    /(SELECT SUM(order_value) 
	  FROM order_revenue) * 100), 
    2
) AS revenue_percentage 
FROM top_customer_revenue ;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Revenue by state and city
SELECT 
	c.customer_state,
    c.customer_city,
    SUM(o.order_value) AS total_revenue
FROM order_revenue o
JOIN olist_customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_state, c.customer_city
ORDER BY c.customer_state, total_revenue DESC;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Categories contributing 80% of revenue (Pareto logic)
WITH category_revenue AS(
	SELECT 
		p.product_category_name,
		SUM(o.price + o.freight_value) AS total_spent
	FROM olist_practice.olist_order_items o
	JOIN olist_practice.olist_products p
	ON o.product_id = p.product_id
	GROUP BY p.product_category_name
),
ranked_categories AS (
	SELECT 
		 product_category_name,
		 total_spent,
		 SUM(total_spent) OVER() AS total_revenue,
		 SUM(total_spent) OVER(ORDER BY total_spent DESC) as running_total
	FROM category_revenue
)

SELECT 
	product_category_name	
FROM ranked_categories
WHERE running_total <= 0.80 * total_revenue;
-- (----------------------------------------------------------------------------------------------------------------------------------------)





-- --------------------------------------------------Section B (Customer Behaviour)------------------------------------------------------------

-- 8.	Number of orders per customer
SELECT 
	customer_id,
    COUNT(order_id) AS order_count
FROM order_revenue
GROUP BY customer_id
ORDER BY order_count DESC;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- 9.	Customers with only one order
SELECT 
	customer_id,
    COUNT(order_id) AS order_count
FROM order_revenue
GROUP BY customer_id
HAVING order_count = 1;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- 10.	Customers whose order value is consistently decreasing
WITH lag_customers AS (
	SELECT 
		customer_unique_id,
		order_id,
		order_purchase_timestamp,
		order_value,
		LAG(order_value, 1) OVER(PARTITION BY customer_unique_id
								 ORDER BY order_purchase_timestamp) AS previous_value
	FROM order_revenue
)

SELECT 
	customer_unique_id
FROM lag_customers
WHERE previous_value IS NOT NULL
GROUP BY customer_unique_id
HAVING 
	COUNT(*) >= 2 AND 
    COUNT(*) = SUM(
					CASE 
						WHEN order_value < previous_value 
                        THEN 1 
                        ELSE 0 
					END
                    );
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Time gap between consecutive orders per customer
WITH order_gap AS (
	SELECT 
		customer_unique_id,
		order_id,
		order_purchase_timestamp,
		LAG(order_purchase_timestamp) OVER(PARTITION BY customer_unique_id
										   ORDER BY order_purchase_timestamp) as previous_order_date
	FROM order_revenue
)
SELECT 
	customer_unique_id,
    DATEDIFF(order_purchase_timestamp, previous_order_date) as days_gap
FROM order_gap
WHERE previous_order_date IS NOT NULL
ORDER BY customer_unique_id;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Average days between orders (repeat customers only)
WITH ordered_order AS (
	SELECT 
		customer_unique_id,
		order_id,
		order_purchase_timestamp,
		LAG(order_purchase_timestamp) 
		OVER(PARTITION BY customer_unique_id 
			 ORDER BY order_purchase_timestamp) AS previous_order_time
	FROM order_revenue
)
SELECT 
	customer_unique_id, 
    AVG(DATEDIFF(order_purchase_timestamp, previous_order_time)) as avg_days_gap
FROM ordered_order
WHERE previous_order_time IS NOT NULL
GROUP BY customer_unique_id
ORDER BY customer_unique_id, avg_days_gap;
-- (----------------------------------------------------------------------------------------------------------------------------------------)




-- ---------------------------------------------------------Section C (Churn Analysis)----------------------------------------------------------

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





-- -------------------------------------------------- Section D (Cost leakage Analysis) ------------------------------------------------------
-- Orders where freight cost > product price
SELECT 
    oi.order_id,
    SUM(oi.freight_value) AS total_freight_cost,
    SUM(oi.price) AS total_price
FROM olist_order_items oi
JOIN olist_orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.order_id
HAVING SUM(oi.freight_value) > SUM(oi.price);
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Average freight % of order value by category
SELECT 
	p.product_category_name,
    ROUND((SUM(oi.freight_value) / SUM(oi.price + oi.freight_value)) * 100,
		  2) 
          AS avg_freight_percentage
FROM olist_practice.olist_orders o
JOIN olist_practice.olist_order_items oi
	ON o.order_id = oi.order_id
JOIN olist_practice.olist_products p
	ON oi.product_id = p.product_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Cities where average freight % is highest
SELECT 
	c.customer_city,
    ROUND((SUM(oi.freight_value) / SUM(oi.price + oi.freight_value)) * 100,
		  2) 
          AS avg_freight_percentage
FROM olist_practice.olist_customers c
JOIN olist_practice.olist_orders o
	ON c.customer_id = o.customer_id
JOIN olist_practice.olist_order_items oi
	ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY 
	c.customer_state, 
    c.customer_city
ORDER BY avg_freight_percentage DESC;
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Categories with low revenue but high shipping cost
WITH category_revenue AS (
	SELECT 
		p.product_category_name,
		SUM(oi.price) AS total_revenue,
		SUM(oi.freight_value) AS total_freight
	FROM olist_practice.olist_orders o 
	JOIN olist_practice.olist_order_items oi 
		ON o.order_id = oi.order_id
	JOIN olist_practice.olist_products p 
		ON oi.product_id = p.product_id
	GROUP BY p.product_category_name
),
benchmarks AS
(
	SELECT 
		AVG(total_revenue) AS avg_revenue,
		AVG(total_freight) AS avg_freight
	FROM category_revenue
)  

SELECT 
	c.product_category_name,
    c.total_revenue,
    c.total_freight
FROM category_revenue c
CROSS JOIN benchmarks b
WHERE c.total_revenue < b.avg_revenue
AND c.total_freight > b.avg_freight
ORDER BY c.total_freight DESC; 
-- (----------------------------------------------------------------------------------------------------------------------------------------)



-- Orders contributing negative value (logic-based)
SELECT 
    order_id,
    SUM(price) AS revenue,
    SUM(freight_value) AS freight_cost,
    SUM(price) - SUM(freight_value) AS net_value
FROM olist_order_items oi
JOIN olist_orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_id
HAVING SUM(price) - SUM(freight_value) < 0;