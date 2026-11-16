-- StyleHub Fashion: a SQL view that mirrors the Power Query cleaning,
-- used to validate the Power BI measures against the raw data.
-- Order matters: standardise first, then de-duplicate.
USE StyleHubDB;
GO

CREATE OR ALTER VIEW dbo.vw_clean_sales AS
SELECT DISTINCT
    OrderID, OrderDate,
    UPPER(LTRIM(RTRIM(ProductID))) AS ProductID,
    ProductName,
    CASE UPPER(REPLACE(LTRIM(RTRIM(Category)), '''', ''))
         WHEN 'MENS' THEN 'Men''s'
         WHEN 'WOMENS' THEN 'Women''s'
         WHEN 'KIDS' THEN 'Kids'
         WHEN 'FOOTWEAR' THEN 'Footwear'
         WHEN 'ACCESSORIES' THEN 'Accessories' END AS Category,
    SubCategory, Size, Color,
    CASE WHEN UPPER(LTRIM(RTRIM(Channel))) = 'ONLINE' THEN 'Online' ELSE 'In-Store' END AS Channel,
    LTRIM(RTRIM(State)) AS State,
    Quantity, UnitPrice, DiscountPct, UnitCost, Revenue,
    CASE WHEN Quantity IS NULL THEN 'Unknown' WHEN Quantity < 0 THEN 'Return' ELSE 'Sale' END AS OrderType
FROM dbo.raw_sales
WHERE OrderID IS NOT NULL;
GO

-- 1. Rows, revenue, units          expected: 18,000 | 961,864.86 | 21,875
SELECT COUNT(*) AS Rows_, ROUND(SUM(Revenue),2) AS Revenue, SUM(Quantity) AS Units FROM dbo.vw_clean_sales;

-- 2. Revenue by category           expected: Accessories 150,688.18 | Footwear 250,003.95 | Kids 80,414.34
--                                           Men's 229,241.00 | Women's 251,517.39
SELECT Category, ROUND(SUM(Revenue),2) AS Revenue FROM dbo.vw_clean_sales GROUP BY Category ORDER BY Category;

-- 3. Revenue by year (YTD card = 2024)   expected: 2023 478,193.93 | 2024 483,670.93
SELECT YEAR(OrderDate) AS Yr, ROUND(SUM(Revenue),2) AS Revenue FROM dbo.vw_clean_sales GROUP BY YEAR(OrderDate) ORDER BY Yr;

-- 4. Monthly revenue, MoM and rolling 3-month average (check the last rows)
--    expected Dec-2024: revenue 73,983.13 | MoM 7.06 | Rolling3M 59,232.34
WITH m AS (
  SELECT DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1) AS MonthStart, SUM(Revenue) AS Rev
  FROM dbo.vw_clean_sales GROUP BY DATEFROMPARTS(YEAR(OrderDate), MONTH(OrderDate), 1))
SELECT MonthStart, ROUND(Rev,2) AS Rev,
  ROUND((Rev - LAG(Rev) OVER (ORDER BY MonthStart)) / LAG(Rev) OVER (ORDER BY MonthStart) * 100, 2) AS MoM_Pct,
  ROUND(AVG(Rev) OVER (ORDER BY MonthStart ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS Rolling3M
FROM m ORDER BY MonthStart;

-- 5. Returns                       expected: 664 | 2.95
SELECT -SUM(CASE WHEN OrderType='Return' THEN Quantity END) AS Total_Returns,
  CAST(-SUM(CASE WHEN OrderType='Return' THEN Quantity END) * 100.0 /
  (SUM(Quantity) - SUM(CASE WHEN OrderType='Return' THEN Quantity END)) AS DECIMAL(5,2)) AS Return_Rate_Pct
FROM dbo.vw_clean_sales;
