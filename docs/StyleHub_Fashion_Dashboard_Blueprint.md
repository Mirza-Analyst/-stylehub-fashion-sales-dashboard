# Project Blueprint
## StyleHub Fashion — Retail Sales Performance Dashboard

**Developer:** Mirza Afzal Baig | Afzalytics
**Tool Stack:** SQL Server, Power Query, Power BI (DAX)
**Domain:** Retail (Fashion/Apparel, Multi-Channel — US)

---

## 1. Business Context

StyleHub Fashion is a multi-channel apparel retailer (Online + In-Store) selling across 5 categories: Men's, Women's, Kids, Footwear, Accessories.

**Objective:** Self-service Power BI dashboard for the Sales team to monitor revenue performance against targets, identify underperforming categories, and drill into product-level detail — without analyst dependency.

Full requirement document: KPI definitions, scope, stakeholder scenario — see *StyleHub_Fashion_Sales_Dashboard_Requirement_Doc*.

---

## 2. Data Sources

| Source | Method | Contents |
|---|---|---|
| **SQL Server (`StyleHubDB.dbo.raw_sales`)** | Get Data → SQL Server | Un-normalized transactional sales data (Order, Product, Channel, State, Quantity, Price, Revenue) |
| **CSV (`raw_targets.csv`)** | Get Data → Text/CSV | Monthly category-wise revenue targets (separate source — Sales Planning team) |

**Why two sources:** Mirrors real-world setup — transactional data from a system of record (SQL), targets from a separate planning process (Excel/CSV).

---

## 3. SQL Profiling (Pre-cleaning Data Quality Check)

Performed in SQL Server before any transformation, to quantify data quality issues:

```sql
-- Duplicate records
SELECT OrderID, OrderDate, ProductID, Quantity, UnitPrice, COUNT(*) 
FROM dbo.raw_sales
GROUP BY OrderID, OrderDate, ProductID, Quantity, UnitPrice
HAVING COUNT(*) > 1;

-- Inconsistent categorical values
SELECT Channel, COUNT(*) FROM dbo.raw_sales GROUP BY Channel ORDER BY COUNT(*) DESC;
SELECT Category, COUNT(*) FROM dbo.raw_sales GROUP BY Category ORDER BY COUNT(*) DESC;

-- Business-rule violations
SELECT COUNT(*) FROM dbo.raw_sales WHERE Quantity < 0;

-- Missing data
SELECT COUNT(*) FROM dbo.raw_sales 
WHERE OrderID IS NULL AND OrderDate IS NULL AND ProductID IS NULL;

-- Formatting issues
SELECT DISTINCT State FROM dbo.raw_sales WHERE State LIKE ' %' OR State LIKE '% ';
```

**Findings:** 251 duplicate groups, 674 negative-quantity (return) rows, 15 blank rows, inconsistent Channel/Category spellings and casing, leading/trailing spaces in State.

This profiling defined the exact cleaning plan executed in Power Query.

---

## 4. Power Query — Data Preparation

**Staging query:** `raw_sales` (load disabled) — pulls once from SQL, feeds two downstream queries via **Duplicate** (not Reference, to keep them independent).

**Cleaning steps applied (on `raw_sales` before splitting):**
1. Remove exact duplicate rows (all columns)
2. Remove fully blank rows
3. `Channel`: Trim → Capitalize Each Word → Replace Values (merge In Store/In-Store/Instore → "In-Store")
4. `Category`: Trim → Capitalize Each Word → Replace Values (fix apostrophe casing, "Mens"/"Womens" → "Men's"/"Women's")
5. `State`: Trim
6. Data types set: OrderDate = Date, Quantity = Whole Number, UnitPrice = Currency, DiscountPct = Percentage
7. `ProductID`: UPPERCASE (fixes casing mismatch before dimension split)
8. Custom column `OrderType`: `if [Quantity] = null then "Unknown" else if [Quantity] < 0 then "Return" else "Sale"`
9. **Remove Duplicates again across all columns, after standardization.** The first pass runs on raw text, so copies whose Category spelling differed ("Mens" vs "Men's") survived it (11 rows). Running it again once values are standardized removes them (18,011 to 18,000 rows).

**Final query structure (post-split):**

| Query | Source | Purpose |
|---|---|---|
| `Fact_Sales` | Duplicate of `raw_sales` | Transactional grain — Product detail columns removed |
| `Dim_Product` | Duplicate of `raw_sales` | Unique products (ProductID, Name, Category, SubCategory, Size, Color, UnitCost) — deduplicated on ProductID |
| `Dim_Category` | Duplicate of `Dim_Product` | Unique Category list only (bridge table) |
| `raw_targets` | CSV | Category + Month + TargetRevenue, cleaned (Trim, Capitalize, apostrophe fix) |

---

## 5. Data Model (Star Schema)

```
               Dim_Category
              /             \
       Dim_Product        raw_targets
            |                  |
       Fact_Sales ---------  DateTable
```

**Relationships (all One-to-Many, Single direction):**
- `Dim_Category[Category]` → `Dim_Product[Category]`
- `Dim_Category[Category]` → `raw_targets[Category]`
- `Dim_Product[ProductID]` → `Fact_Sales[ProductID]`
- `DateTable[Date]` → `Fact_Sales[OrderDate]`
- `DateTable[Date]` → `raw_targets[Month]`

**DateTable** (DAX-generated, marked as official Date Table):
```dax
DateTable = 
ADDCOLUMNS(
    CALENDAR(DATE(2023,1,1), DATE(2024,12,31)),
    "Year", YEAR([Date]),
    "MonthNumber", MONTH([Date]),
    "MonthName", FORMAT([Date], "MMMM"),
    "YearMonth", FORMAT([Date], "YYYY-MM"),
    "YearMonthSort", YEAR([Date]) * 100 + MONTH([Date]),
    "Quarter", "Q" & FORMAT([Date], "Q")
)
```
`YearMonth` is sorted by `YearMonthSort` (Sort by Column) to ensure correct chronological axis ordering in charts.

**Why a `Dim_Category` bridge table:** `Dim_Product` and `raw_targets` both have a repeating (non-unique) Category column. Joining them directly would create an ambiguous Many-to-Many relationship. `Dim_Category` holds Category as a unique list, acting as the "One" side for both.

---

## 6. DAX Measures (`_Measures` table)

```dax
Total Revenue = SUM(Fact_Sales[Revenue])

Total Units Sold = SUM(Fact_Sales[Quantity])

YTD Sales = TOTALYTD(SUM(Fact_Sales[Revenue]), DateTable[Date])

Previous Month Revenue = 
CALCULATE(SUM(Fact_Sales[Revenue]), DATEADD(DateTable[Date], -1, MONTH))

MoM Growth % = 
DIVIDE(SUM(Fact_Sales[Revenue]) - [Previous Month Revenue], [Previous Month Revenue])
-- valid at month level (trend/matrix visuals); on a multi-month card it compares the whole range with itself shifted by a month

MoM Growth % (Latest Month) = 
VAR LastDate = MAX(DateTable[Date])
VAR CurrStart = DATE(YEAR(LastDate), MONTH(LastDate), 1)
VAR PrevStart = EDATE(CurrStart, -1)
VAR CurrRev = CALCULATE(SUM(Fact_Sales[Revenue]), ALL(DateTable),
    DateTable[Date] >= CurrStart, DateTable[Date] <= EOMONTH(CurrStart, 0))
VAR PrevRev = CALCULATE(SUM(Fact_Sales[Revenue]), ALL(DateTable),
    DateTable[Date] >= PrevStart, DateTable[Date] < CurrStart)
RETURN DIVIDE(CurrRev - PrevRev, PrevRev)   -- used on the KPI card

Rolling 3-Month Avg = 
VAR LastDate = MAX(DateTable[Date])
VAR Window = DATESINPERIOD(DateTable[Date], LastDate, -3, MONTH)
VAR Total3M = CALCULATE(SUM(Fact_Sales[Revenue]), ALL(DateTable), Window)
VAR Months = CALCULATE(DISTINCTCOUNT(DateTable[YearMonth]), ALL(DateTable), Window)
RETURN DIVIDE(Total3M, Months)   -- average of monthly revenue; first two months use a shorter window

Target Revenue = SUM(raw_targets[TargetRevenue])

Target Achievement % = DIVIDE([Total Revenue], [Target Revenue])

Underperformance Flag = 
IF([Target Achievement %] < 0.9, "Underperforming", "On Track")

Total Returns = 
ABS(CALCULATE(SUM(Fact_Sales[Quantity]), Fact_Sales[OrderType] = "Return"))

Return Rate % = 
DIVIDE([Total Returns], [Total Units Sold] + [Total Returns])

YoY Growth % = 
VAR PrevYearRevenue = 
    CALCULATE(SUM(Fact_Sales[Revenue]), SAMEPERIODLASTYEAR(DateTable[Date]))
RETURN
    DIVIDE(SUM(Fact_Sales[Revenue]) - PrevYearRevenue, PrevYearRevenue)
```

---

## 7. Report Pages

**Global elements (every page):** Maroon (`#6E1423`) / Gold (`#C89B3C`) theme · "A" monogram badge (top-right) · "Designed & Developed by Mirza Afzal Baig | Afzalytics" footer · synced Date/Category/Channel slicers (visible only on Page 1, filter applies across all pages).

| Page | Visuals |
|---|---|
| **1. Executive Summary** | 4 KPI cards (Total Revenue, YTD Sales, MoM Growth % (latest month), Target Achievement %) · Revenue Trend with 3-Month Rolling Average (line chart) · Category Contribution donut · Channel Split bar chart |
| **2. Category Performance** | Actual vs Target clustered column chart (by Category) · SubCategory Breakdown matrix (Category → SubCategory, Revenue, Units) · Underperformance Flag table with conditional formatting (Red <90%, Gold 90–100%, Green ≥100%) |
| **3. Channel Analysis** | Revenue Trend by Channel (stacked area) · Returns Summary by Channel (multi-row card: Total Returns, Return Rate %, Total Revenue) |
| **4. Product Detail** (Drill-through) | Product-level table (Name, SubCategory, Size, Color, Units Sold, Revenue, Return Rate %) · Drill-through field: `Dim_Category[Category]`, triggered from Page 2's bar chart |

---

## 8. Validation

SQL view `vw_clean_sales` was built over the raw SQL table, replicating the Power Query cleaning (standardize, then de-duplicate), and key measures were recomputed from it:

| Measure | SQL (cleaned view) | Power BI | Result |
|---|---|---|---|
| Rows after cleaning | 18,000 | 18,000 | Exact |
| Total Revenue | 961,864.86 | 961,864.86 | Exact |
| Total Units (net) | 21,875 | 21,875 | Exact |
| Revenue by category (5) | Accessories 150,688.18 · Footwear 250,003.95 · Kids 80,414.34 · Men's 229,241.00 · Women's 251,517.39 | identical | Exact |
| YTD (2024) | 483,670.93 | 483,670.93 | Exact |
| MoM, latest month (Dec vs Nov 2024) | 7.06% | 7.06% | Exact |
| Rolling 3-month average (Dec 2024) | 59,232.34 | 59,232.34 | Exact |
| Returns / Return Rate | 664 / 2.95% | 664 / 2.95% | Exact |
| Target Revenue | 992,406 (Excel sum of raw_targets.csv) | 992,406 | Exact |
| Target Achievement (overall) | 96.92% | 96.92% | Exact |

**What validation caught:** the first comparison was 0.04% off (962,257 vs 961,865). The difference sat entirely in Men's and Women's, which traced to 11 duplicate rows whose Category spelling differed when duplicates were first removed. De-duplicating again after standardization fixed it. Validation also showed that the MoM card, on a 24-month range, was comparing the range with itself, and that the rolling average was returning a daily average; both measures were rewritten.

---|---|---|---|
| Total Revenue | 961,864.86 (SQL, deduplicated) | 962,260 | 99.96% match |
| Target Revenue | 992,406 (Excel SUM of raw_targets.csv) | 992,406 | Exact match |

---

## 9. Key Design Decisions (for interview reference)

- **Un-normalized source → normalized in Power Query**, mirroring real job workflow, not pre-built fact/dim tables.
- **De-duplication runs twice**: once on raw rows, once after standardization, because copies that differ only in spelling are not duplicates until the text is standardized.
- **`Duplicate` used instead of `Reference`** when building independent Dim/Fact tables from the same staging query, to avoid unintended step-chaining between them.
- **Single-direction relationships**, with a bridge dimension (`Dim_Category`) to avoid Many-to-Many ambiguity — chosen over Snowflake schema since dimension size didn't justify the added complexity.
- **No redundant visuals** — each chart answers a distinct question; chart type varied across pages only where it served a different metric, not for decoration.
- **Returns (negative quantity) kept, not deleted** — flagged via an `OrderType` column, since returns are real business data worth tracking.
