-- EDA

SELECT * FROM category;
SELECT * FROM customers;
SELECT * FROM inventory;
SELECT * FROM order_items;
SELECT * FROM orders;
SELECT * FROM payments;
SELECT * FROM products;
SELECT * FROM sellers;
SELECT * FROM shippings;
-------------------------------------------------

-- Business Problems

------------------------------------
-- 1. Top Selling Products
SELECT
p.product_id,
product_name,
ROUND(SUM(oi.price_per_unit * oi.quantity)::numeric, 2) as sales_value,
SUM(o.order_id) AS tota_quantity_sold
FROM order_items oi
LEFT Join products p on oi.product_id=p.product_id
LEFT Join orders o on oi.order_id = o.order_id
WHERE order_status = 'Completed'
GROUP BY p.product_id, product_name
ORDER BY SUM(oi.price_per_unit * oi.quantity) DESC
LIMIT 10;

-- 2. Revenue by Category

SELECT
category_name,
ROUND(SUM(oi.price_per_unit * oi.quantity)::numeric, 2) as total_revenue_by_cat,
SUM(SUM(oi.quantity * oi.price_per_unit)) OVER () AS total_revenue,
100.0*
SUM(oi.quantity * oi.price_per_unit)::numeric
/
SUM(SUM(oi.quantity * oi.price_per_unit)) OVER ()
AS revenue_share
FROM order_items oi
Join products p on oi.product_id=p.product_id
Join category c on p.category_id=c.category_id
Join orders o on oi.order_id = o.order_id
WHERE order_status = 'Completed'
GROUP BY category_name;

-- 3 Average Order Value

SELECT
customer_id,
AVG(oi.price_per_unit * oi.quantity) as avg_order_value,
COUNT(customer_id) AS total_orders
FROM order_items oi
Join orders o on oi.order_id = o.order_id
GROUP BY customer_id
HAVING COUNT(customer_id) > 5

-- 4 Monthly Sales Trend
SELECT
EXTRACT(MONTH FROM order_date),
SUM(oi.price_per_unit * oi.quantity)
FROM order_items oi
Join orders o on oi.order_id = o.order_id
WHERE EXTRACT(YEAR FROM order_date) = 2024
GROUP BY EXTRACT(MONTH FROM order_date);

-- 5. Customers with no purchases
SELECT *
FROM customers c
LEFT JOIN orders o on c.customer_id=o.customer_id
WHERE order_id IS NULL

-- Problem 6 Least-Selling Categories by State
-- Identify the least-selling product category for each state.
-- Challenge: Include the total sales for that category within each state.

WITH ranking_table AS (
  SELECT 
    c.state,
    cat.category_name,
    SUM(oi.total_sales) AS total_sales,
    RANK() OVER (PARTITION BY c.state ORDER BY SUM(oi.total_sales) ASC) AS rank
  FROM orders AS o
  JOIN customers AS c ON o.customer_id = c.customer_id
  JOIN order_items AS oi ON o.order_id = oi.order_id
  JOIN products AS p ON oi.product_id = p.product_id
  JOIN category AS cat ON cat.category_id = p.category_id
  GROUP BY c.state, cat.category_name
)
SELECT *
FROM ranking_table
WHERE rank = 1;

-- Problem 7 Customer Lifetime Value (CLTV)
-- Calculate the total value of orders placed by each customer over their lifetime.
-- Challenge: Rank customers based on their CLTV

WITH customer_lifetime_value AS (
  SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    SUM(oi.total_sales) AS lifetime_value
  FROM customers AS c
  JOIN orders AS o ON c.customer_id = o.customer_id
  JOIN order_items AS oi ON o.order_id = oi.order_id
  GROUP BY c.customer_id, c.first_name, c.last_name
)
SELECT 
  customer_id,
  customer_name,
  lifetime_value,
  RANK() OVER (ORDER BY lifetime_value DESC) AS rank
FROM customer_lifetime_value;

-- Problem 8 Inventory Stock Alerts
-- Query products with stock levels below a certain threshold (e.g., less than 10 units).
-- Challenge: Include last restock date and warehouse information.

SELECT 
	i.inventory_id,
	p.product_name,
	i.stock as current_stock_left,
	i.last_stock_date,
	i.warehouse_id
FROM inventory as i
join 
products as p
ON p.product_id = i.product_id
WHERE stock < 10 ;

-- Problem 9 Payment Success Rate 
-- Calculate the percentage of successful payments across all orders.
-- Challenge: Include breakdowns by payment status (e.g., failed, pending).


SELECT 
	p.payment_status,
	COUNT(*) as total_cnt,
	COUNT(*)::numeric/(SELECT COUNT(*) FROM payments)::numeric * 100 as Percentage
FROM orders as o
JOIN
payments as p
ON o.order_id = p.order_id
GROUP BY 1

-- Problem 10 Most Returned Products
-- Query the top 10 products by the number of returns.

SELECT 
	p.product_id,
	p.product_name,
	COUNT(*) as total_unit_sold,
	SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END) as total_returned,
	SUM(CASE WHEN o.order_status = 'Returned' THEN 1 ELSE 0 END)::numeric/COUNT(*)::numeric * 100 as return_percentage
FROM order_items as oi
JOIN 
products as p
ON oi.product_id = p.product_id
JOIN orders as o
ON o.order_id = oi.order_id
GROUP BY 1, 2
ORDER BY 5 DESC ;

-- 11. Shipping Delays
SELECT *,
shipping_date-order_date AS Days_Diff
FROM orders o
JOIN shippings s ON o.order_id=s.order_id
JOIN customers c ON c.customer_id=o.customer_id
WHERE shipping_date-order_date > 3

-- 12. The Performing Sellers
SELECT
seller_name,
SUM(quantity*price_per_unit) AS total_sales
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN sellers s ON s.seller_id=o.seller_id
GROUP BY 1
ORDER BY 2 DESC
LIMIT 5

-- 13. Most Returned Products
-- Query the top 10 products by the number of returns
-- Display the return rate as percentage of total units sold for each product
SELECT
product_name,
SUM(quantity) AS total_units_sold,
SUM(CASE WHEN order_status='Returned' THEN quantity ELSE 0 END) AS returned,
100.0*SUM(CASE WHEN order_status='Returned' THEN quantity ELSE 0 END)/SUM(quantity) as perc_returned
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id=p.product_id
GROUP BY 1
ORDER BY 3 DESC
LIMIT 10

-- 15. Inactive Sellers
-- Identify sellers who haven't made any sales in the last 6 months
-- Show the last sale date and total sales from those sellers
WITH seller_sales AS (SELECT 
seller_name,
SUM(quantity*price_per_unit) AS total_sales,
MAX(order_date) AS last_sales_date
FROM sellers s
LEFT JOIN orders o ON s.seller_id=o.seller_id
LEFT JOIN order_items oi ON oi.order_id = o.order_id
GROUP BY seller_name)

SELECT *
FROM seller_sales
WHERE last_sales_date IS NULL
     OR last_sales_date < (
        SELECT MAX(order_date)
        FROM orders
     ) - INTERVAL '6 months';

-- 16. Identify the customers into returning or new
-- if the customer has done more than 5 returns categorize them as returning otherwise new
-- List customers id, total orders, total returns
WITH customer_returns AS (SELECT
customer_id,
COUNT(oi.order_id) as total_orders,
SUM(CASE WHEN order_status='Returned' THEN 1 ELSE 0 END) AS returned_orders
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
GROUP BY customer_id)

SELECT *,
CASE WHEN returned_orders>5 THEN 'Returning' ELSE 'New' END AS returning_vs_new
FROM customer_returns

-- 17. Top 5 customers by orders in each state
WITH ranking_table AS (SELECT
c.customer_id,
COUNT(o.order_id) AS total_orders,
c.state,
SUM(quantity*price_per_unit) AS total_sales,
RANK() OVER(PARTITION BY c.state ORDER BY COUNT(o.order_id) DESC) AS ranking
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY 1, 3)

SELECT *
FROM ranking_table
WHERE ranking < 5

-- 18. Revenue by Shipping Provider
SELECT
shipping_providers,
COUNT(o.order_id) AS total_orders,
SUM(quantity*price_per_unit) AS total_sales,
AVG(shipping_date-order_date) AS avg_handling_time
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN shippings s ON oi.order_id = s.order_id
GROUP BY 1

-- 19. Top 10 products with the highest decreasing revenue ratio compared to
-- last year(2022) and current_year(2023).
-- Return product_id, product_name, category_name, 2022 and 2023 revenue
-- decrease ratio at the end round the result 
WITH new_table AS (SELECT 
product_name,
SUM(CASE 
        WHEN EXTRACT(YEAR FROM order_date) = 2022 
        THEN quantity * price_per_unit 
        ELSE 0 
    END) AS revenue_2022,

SUM(CASE 
        WHEN EXTRACT(YEAR FROM order_date) = 2023 
        THEN quantity * price_per_unit 
        ELSE 0 
    END) AS revenue_2023,
p.product_id,
category_name
FROM products p
LEFT JOIN order_items oi ON p.product_id=oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id
LEFT JOIN category c ON c.category_id=p.category_id
GROUP BY 1, 4, 5)

SELECT *,
ROUND(
    (100.0 * (revenue_2022 - revenue_2023) 
    / NULLIF(revenue_2022, 0))::numeric,
    2
)  AS revenue_ratio
FROM new_table
WHERE revenue_2023 < revenue_2022
ORDER BY revenue_ratio DESC
LIMIT 10