-- -------------------------------------------------- Customer Behaviour ------------------------------------------------------------
USE olist_practice;

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