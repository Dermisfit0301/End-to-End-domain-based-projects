'checking the data initially'

SELECT *
  FROM [dbo].[fact_sales]
  where year(order_date)=2013


  SELECT * from   [dbo].[fact_sales]
  where quantity>1


  'changes over time analysis'

  select order_date, count(order_number) as order_count, sum(sales_amount) as revenue
  from [dbo].[fact_sales]
  group by order_date
  order by order_date asc

'Month year analysis'

  select Month(order_date) as Month,
  Year(order_date) as year,
  count(order_number) as order_count, sum(sales_amount) as revenue
  from [dbo].[fact_sales]
  group by  Month(order_date), Year(order_date)
  order by Month(order_date), Year(order_date) asc


  'Cumulative analysis'


WITH revenue_table AS (
    SELECT  
        MONTH(order_date) AS Month,
        YEAR(order_date) AS Year,
        SUM(sales_amount) AS revenue,
        avg(prices)
        as average_price
    FROM dbo.fact_sales
    GROUP BY 
        YEAR(order_date),
        MONTH(order_date)
)
SELECT 
    Month,
    Year,
    revenue,

    SUM(revenue) OVER (
    Partition by Year
        ORDER BY Year, Month
    ) AS rolling_total,
       avg(average_price)
        OVER (
    Partition by Year
        ORDER BY Year, Month
    ) AS moving_avg

FROM revenue_table
ORDER BY Year, Month;

'Product wise revenue comparison with its average all-time revenue'

WITH product_rev_agg AS (
    SELECT 
        YEAR(fs.order_date) AS Year,
        dp.product_name AS product,
        SUM(fs.sales_amount) AS revenue
    FROM master_ecommerce.dbo.fact_sales AS fs
    JOIN master_ecommerce.dbo.dim_products AS dp
        ON fs.product_key = dp.product_key
    GROUP BY 
        YEAR(fs.order_date),
        dp.product_name
)
SELECT 
    
    product,
    revenue,
    AVG(revenue) OVER (PARTITION BY product) AS avg_revenue,
    revenue - AVG(revenue) OVER (PARTITION BY product) AS diff,
    CASE 
        WHEN revenue > AVG(revenue) OVER (PARTITION BY product) THEN 'Above Benchmark'
        WHEN revenue < AVG(revenue) OVER (PARTITION BY product) THEN 'Below Benchmark'
        ELSE 'At Benchmark'
    END AS Benchmark_matched,
        revenue - LAG(revenue) OVER (PARTITION BY product order by Year) as diff_py,
  CASE 
      WHEN revenue - LAG(revenue) OVER (PARTITION BY product order by Year)>0 THEN 'increased'
      WHEN revenue - LAG(revenue) OVER (PARTITION BY product order by Year)<0 THEN 'Decreased'
      ELSE 'No change'
  END AS Change_detected
FROM product_rev_agg
;


'Part to whole analysis'

SELECT 
    category,
    revenue,
    CONCAT(
        ROUND(CAST(revenue AS FLOAT) * 100.0 / SUM(revenue) OVER(), 2),
        '%'
    ) AS revenue_share
FROM (
    SELECT 
        category, 
        SUM(sales_amount) AS revenue
    FROM dbo.fact_sales fs
    JOIN dbo.dim_products dp 
        ON dp.product_key = fs.product_key
    GROUP BY category
) AS x1
ORDER BY revenue DESC;

'segmenting the products according to cost'

select * from dim_products

with product_ctlg as (
select product_id, 
case when cost <100 then 'cheap' 
when  cost between 100 and 500 then 'affordable'
when  cost between 500 and 1000 then 'high-end'
else 'premium' end as price_range
from dim_products)
select price_range, count(product_id) as products 
from product_ctlg
group by price_range

'Segmenting the customers based on spending habits'
select * from dim_customers

With cust_lftm as (
select s.customer_key, sum(sales_amount) as spending, min(order_date) as first_order, max(order_date) as last_order,
datediff(Month, min(order_date),max(order_date)) as lifespan 
from fact_sales s

join dim_customers c on s.customer_key=c.customer_key
group by s.customer_key)

select segment,
count(customer_key) as customers
from (
select customer_key, spending,case when lifespan>=12 and spending> 5000 then 'VIP' 
when lifespan>=12 and spending<=5000 then 'Regular'
when lifespan<12 then 'new'
else 'unknown' end as segment
from cust_lftm) as x
group by segment

'which product/customer segment contributes to revenue'


WITH prod_catlg AS (
    SELECT 
        CASE 
            WHEN p.cost < 100 THEN 'cheap'
            WHEN p.cost BETWEEN 100 AND 500 THEN 'affordable'
            WHEN p.cost BETWEEN 500 AND 1000 THEN 'high-end'
            ELSE 'premium'
        END AS price_range,
        SUM(s.sales_amount) AS revenue
    FROM dim_products p
    JOIN fact_sales s 
        ON s.product_key = p.product_key
    GROUP BY 
        CASE 
            WHEN p.cost < 100 THEN 'cheap'
            WHEN p.cost BETWEEN 100 AND 500 THEN 'affordable'
            WHEN p.cost BETWEEN 500 AND 1000 THEN 'high-end'
            ELSE 'premium'
        END
)

SELECT 
    price_range,
    revenue,
    CONCAT(
        ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2),
        '%'
    ) AS revenue_share
FROM prod_catlg
ORDER BY revenue DESC;


With cust_lftm as (
select s.customer_key, sum(sales_amount) as spending, min(order_date) as first_order, max(order_date) as last_order,
datediff(Month, min(order_date),max(order_date)) as lifespan 
from fact_sales s

join dim_customers c on s.customer_key=c.customer_key
group by s.customer_key)

select segment, sum(spending) as revenue,     CONCAT(ROUND(SUM(spending) * 100.0 / SUM(SUM(spending)) OVER (), 2),'%') AS grandtotal_share
from (
select customer_key, spending,case when lifespan>=12 and spending> 5000 then 'VIP' 
when lifespan>=12 and spending<=5000 then 'Regular'
when lifespan<12 then 'new'
else 'unknown' end as segment
from cust_lftm) as x
group by segment

use master_ecommerce

'creating a customer report'

create view Customer_report as (
SELECT 
    fs.customer_key,
    CONCAT(dc.first_name, ' ', dc.last_name) AS customer_name,
    DATEDIFF(YEAR, dc.birthdate, GETDATE()) AS customer_age,


    MAX(fs.order_date) AS last_order,
    DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date)) AS lifespan,
    DATEDIFF(MONTH,MIN(fs.order_date),GETDATE()) as recency,
    CASE 
        WHEN DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date)) >= 12 
             AND SUM(fs.sales_amount) > 5000 THEN 'VIP'
        WHEN DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date)) >= 12 
             AND SUM(fs.sales_amount) <= 5000 THEN 'Regular'
        WHEN DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date)) < 12 THEN 'New'
        ELSE 'Unknown'
    END AS segment,

    CASE 
        WHEN DATEDIFF(YEAR, dc.birthdate, GETDATE()) < 50 THEN 'Young'
        WHEN DATEDIFF(YEAR, dc.birthdate, GETDATE()) BETWEEN 50 AND 70 THEN 'Senior'
        ELSE 'Old'
    END AS age_group,


    COUNT( distinct fs.order_number) AS orders,
    SUM(fs.sales_amount) AS total_spend,
    SUM(fs.quantity) AS total_quantity,
    case when DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date))=0 then 0
else SUM(fs.sales_amount)/DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date)) end as avg_monthly_spend,
case when SUM(fs.sales_amount)=0 then 0
else SUM(fs.sales_amount)/   COUNT( distinct fs.order_number)  end as Avg_order_value

FROM fact_sales fs
JOIN dim_customers dc 
    ON dc.customer_key = fs.customer_key

GROUP BY 
    fs.customer_key,
    dc.first_name,
    dc.last_name,
    dc.birthdate)


'creating a Product report'

create view  Product_report as (
SELECT 
    fs.product_key,
    dp.product_id, 
    dp.product_number,
    dp.product_name,

    MAX(fs.order_date) AS recent_order,
    DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date)) AS lifespan,
    DATEDIFF(MONTH, MIN(fs.order_date), GETDATE()) AS recency,

    COUNT(DISTINCT fs.customer_key) AS customers,
    COUNT(DISTINCT fs.order_number) AS orders,
    SUM(fs.sales_amount) AS total_revenue, 

    CASE 
        WHEN DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date)) = 0 
            THEN 0
        ELSE SUM(fs.sales_amount) / DATEDIFF(MONTH, MIN(fs.order_date), MAX(fs.order_date))
    END AS avg_monthly_revenue,

    CASE 
        WHEN SUM(fs.quantity) = 0 THEN 0
        ELSE ROUND(SUM(fs.sales_amount) * 1.0 / SUM(fs.quantity),2)
    END AS avg_order_value,

    CASE 
        WHEN SUM(fs.sales_amount) < 10000 THEN 'Low_performer'
        WHEN SUM(fs.sales_amount) >= 10000 
             AND SUM(fs.sales_amount) < 50000 THEN 'Average_performer'
        WHEN SUM(fs.sales_amount) >= 50000 
             AND SUM(fs.sales_amount) < 100000 THEN 'Good_performer'
        ELSE 'Bestseller'
    END AS performance_segment

FROM fact_sales fs
JOIN dim_products dp 
    ON dp.product_key = fs.product_key

GROUP BY 
    fs.product_key, 
    dp.product_id, 
    dp.product_number,
    dp.product_name)


use master_ecommerce
select * from Customer_report
select * from Product_report