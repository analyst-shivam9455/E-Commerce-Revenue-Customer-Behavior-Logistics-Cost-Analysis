USE olist_practice;
-- --------------------------------------------------- (Revenue Diagnosis) --------------------------------------------------------
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