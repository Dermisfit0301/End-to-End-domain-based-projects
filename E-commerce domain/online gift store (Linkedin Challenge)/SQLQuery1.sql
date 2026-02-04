create database projects
use projects
"Data cleaning process"
select count(*) from dbo.OnlineRetail
where Invoicetime is NULL and 
delete from onlineretail
where Country not like '%United Kingdom%'

ALTER TABLE dbo.OnlineRetail
ALTER COLUMN Country nvarchar(50);

ALTER TABLE dbo.OnlineRetail
ALTER COLUMN Description nvarchar(255);
delete from dbo.OnlineRetail
where LEFT(InvoiceNo,1)='C'

alter table dbo.OnlineRetail 
cast(

alter table dbo.OnlineRetail
drop column Country 
"replacing nulls with mode"
select * from dbo.OnlineRetail


update  dbo.OnlineRetail

set Invoicetime=(
select top 1 Invoicetime from dbo.OnlineRetail
  WHERE InvoiceTime IS NOT NULL
group by Invoicetime
order by count(*) desc)
where Invoicetime is NULL


"Top bestselling products"

select top 10 Description,sum(Quantity) as Quantity_purchased from dbo.OnlineRetail
group by Description
order by sum(Quantity) desc

SELECT TOP 10
       Description,
       ROUND(SUM(Quantity * UnitPrice), 2) AS Revenue_GBP
FROM dbo.OnlineRetail
GROUP BY Description
ORDER BY Revenue_GBP DESC;

"Sales by hour"

SELECT
    DATEPART(HOUR, InvoiceTime) AS InvoiceHour,
    Round(SUM(Quantity * UnitPrice),2) AS Revenue
FROM dbo.OnlineRetail
WHERE InvoiceTime IS NOT NULL
GROUP BY DATEPART(HOUR, InvoiceTime)
ORDER BY InvoiceHour;

"Sales by hour"

SELECT
    DATEPART(HOUR, InvoiceTime) AS InvoiceHour,
    Round(SUM(Quantity * UnitPrice),2) AS Revenue
FROM dbo.OnlineRetail
WHERE InvoiceTime IS NOT NULL
GROUP BY DATEPART(HOUR, InvoiceTime)
ORDER BY InvoiceHour;

"Sales by Day"

With rev_an As(
SELECT DATENAME(WEEKDAY,Invoicedate) as dayname,
datepart(WEEKDAY,Invoicedate) as daynumber,
Round(SUM(Quantity * UnitPrice),2) AS Revenue
FROM dbo.OnlineRetail

GROUP BY DATENAME(WEEKDAY,Invoicedate),DATEPART(WEEKDAY, Invoicedate)
)
select dayname,Revenue,
concat(round(Revenue/sum(Revenue) over (),2)*100.0,'%') as percentage_contribution

from rev_an
order by daynumber 

'running total'
select Invoicedate,SUM(revenue) over (order by Invoicedate) as running_total from (
select  Invoicedate, ROUND(SUM(Quantity * UnitPrice),2) as revenue 
from dbo.OnlineRetail
group by Invoicedate) t

'items per invoice'

select Invoicedate,SUM(revenue) over (order by Invoicedate) as running_total from (
select  Invoicedate, ROUND(SUM(Quantity * UnitPrice),2) as revenue 
from dbo.OnlineRetail
group by Invoicedate) t


select * from dbo.OnlineRetail

SELECT AVG(items_count) AS Avg_Basket_Size
FROM (
    SELECT InvoiceNo, SUM(Quantity) AS items_count
    FROM dbo.OnlineRetail
    GROUP BY InvoiceNo
) t;
'Customers by order count'

select top 3 CustomerID, sum(Quantity)/COUNT(InvoiceNo) as quantity_per_order FROM dbo.OnlineRetail group by CustomerID

'products sold in every month'

SELECT COUNT(*) as ever_green_products
FROM (
    SELECT
        Description
    FROM dbo.OnlineRetail
    GROUP BY Description
    HAVING COUNT(DISTINCT DATEPART(MONTH, InvoiceDate)) = 12
) t;
select count (Distinct Description) from dbo.OnlineRetail

'MoM growth analysis'

WITH month_info AS (
    SELECT
        DATEPART(MONTH, InvoiceDate) AS month_num,
        ROUND(SUM(Quantity * UnitPrice), 2) AS revenue
    FROM dbo.OnlineRetail
    GROUP BY DATEPART(MONTH, InvoiceDate)
)
SELECT
    month_num,
    revenue,
    LAG(revenue, 1) OVER (ORDER BY month_num) AS previous_month_revenue,
    ROUND((revenue-LAG(revenue, 1) OVER (ORDER BY month_num))*100/LAG(revenue, 1) OVER (ORDER BY month_num),2) as MoM_percent

FROM month_info
ORDER BY month_num;

'Products that contribute to 80% revenue'


with rev_part as (
select description, sum(Quantity*UnitPrice) as revenue from dbo.OnlineRetail
group by description),
pareto as (
select description,revenue,sum(revenue) over (order by revenue desc)*100.0/sum(revenue) over() as cumulative_percent from rev_part)
select count(description) 
from  pareto
where cumulative_percent<=80

'outlier invoices'

WITH inv_record AS (
    SELECT
        InvoiceNo,
        SUM(Quantity * UnitPrice) AS revenue
    FROM dbo.OnlineRetail
    GROUP BY InvoiceNo
)
SELECT
    COUNT(*) AS outlier_invoice_count
FROM (
    SELECT
        InvoiceNo,
        CASE
            WHEN revenue > AVG(revenue) OVER ()
            THEN 'Yes'
            ELSE 'No'
        END AS Outlier
    FROM inv_record
) t
WHERE Outlier = 'Yes';

 select  COUNT(distinct Invoiceno) AS invoice_count
FROM dbo.OnlineRetail
