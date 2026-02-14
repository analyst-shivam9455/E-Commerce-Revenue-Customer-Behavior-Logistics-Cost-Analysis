-- -------------------------------------------------- Cost leakage Analysis ------------------------------------------------------
USE olist_practice;

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