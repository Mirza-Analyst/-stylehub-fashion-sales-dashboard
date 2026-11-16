-- StyleHub Fashion: data profiling on the raw sales table (run before any cleaning)
-- Table: dbo.raw_sales (flat, un-normalised export loaded as-is)
USE StyleHubDB;
GO

-- 1. Duplicate records
SELECT OrderID, OrderDate, ProductID, Quantity, UnitPrice, COUNT(*) AS DupCount
FROM dbo.raw_sales
GROUP BY OrderID, OrderDate, ProductID, Quantity, UnitPrice
HAVING COUNT(*) > 1;

-- 2. Inconsistent channel values
SELECT Channel, COUNT(*) AS Cnt FROM dbo.raw_sales GROUP BY Channel ORDER BY Cnt DESC;

-- 3. Inconsistent category values
SELECT Category, COUNT(*) AS Cnt FROM dbo.raw_sales GROUP BY Category ORDER BY Cnt DESC;

-- 4. Negative quantities (returns)
SELECT COUNT(*) AS NegativeQty FROM dbo.raw_sales WHERE Quantity < 0;

-- 5. Fully blank rows
SELECT COUNT(*) AS BlankRows
FROM dbo.raw_sales
WHERE OrderID IS NULL AND OrderDate IS NULL AND ProductID IS NULL;

-- 6. Leading or trailing spaces in State
SELECT DISTINCT State FROM dbo.raw_sales WHERE State LIKE ' %' OR State LIKE '% ';

-- Note: SQL Server's default collation is case-insensitive, so GROUP BY treats
-- Online and online as one value, while Power Query treats them as different.
