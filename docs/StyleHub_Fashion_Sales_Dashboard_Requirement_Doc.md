# Business Requirement Document (BRD)
## Retail Sales Performance Dashboard – StyleHub Fashion

---

### 1. Project Background
StyleHub Fashion is a multi-channel apparel retail chain (In-Store + Online) operating across the United States, selling across five major categories: **Men's, Women's, Kids, Footwear, and Accessories**.

The **VP of Sales** has observed that quarterly revenue targets are consistently missed in certain categories, but the sales team currently lacks clear, self-service visibility into *where* and *why* underperformance is occurring. Reporting today is manual (spreadsheet-based), reactive, and dependent on the analytics team for every ad-hoc question.

### 2. Business Objective
Build a self-service Power BI dashboard that allows the sales team to:
- Monitor overall and category-wise sales performance against targets
- Identify underperforming categories early (monthly, not just at quarter-end)
- Drill down from category-level summary to product-level detail without analyst support
- Compare channel performance (Online vs In-Store)

### 3. Stakeholders
| Role | Interest |
|---|---|
| VP of Sales | Overall revenue health, category-level target tracking |
| Regional Sales Managers | Category & channel trends within their scope, self-service filtering |
| BI Developer (this role) | Translate business KPIs into data model, DAX logic, and dashboard design |

### 4. Scope

**In Scope:**
- Revenue trend analysis (Daily / Monthly / Quarterly / YTD)
- Category-wise and Sub-category-wise contribution to revenue
- Channel-wise split: Online vs In-Store
- Actual vs Target sales tracking with variance highlighting
- Product-level drill-through from category summary
- Self-service filters: Date range, Category, Channel

**Out of Scope (v1):**
- Store-level / location-level breakdown (flagged as a future enhancement)
- Customer segmentation / RFM analysis
- Inventory and stock-level data (handled in a separate Inventory Analytics project)
- Profit margin / cost analysis (revenue-only scope for v1)

### 5. Key Metrics / KPI Definitions
| KPI | Definition |
|---|---|
| Total Revenue | Sum of net sales value across selected period |
| Units Sold | Total quantity sold across selected period |
| YTD Sales | Cumulative sales from start of fiscal year to current date |
| MoM Growth % | (Current Month Sales − Previous Month Sales) / Previous Month Sales |
| Rolling 3-Month Avg | Average monthly sales over the trailing 3 months, to smooth seasonal spikes |
| Target Achievement % | Actual Sales / Target Sales |
| Underperformance Flag | Category flagged when Actual Sales is 10%+ below Target |

### 6. Reporting Cadence
- **Monthly review** by Regional Sales Managers
- **Quarterly rollup** presented to VP of Sales

### 7. Report Pages (Dashboard Structure)
1. **Executive Summary** – KPI cards (Total Revenue, YTD Sales, MoM Growth %, Target Achievement %), overall trend line
2. **Category Performance** – Category & sub-category contribution, Actual vs Target with conditional formatting on underperforming categories
3. **Channel Analysis** – Online vs In-Store comparison
4. **Product Detail (Drill-through)** – Product-level sales, accessed via drill-through from Category Performance page

### 8. Filters / Slicers
- Date range slicer
- Category / Sub-category filter
- Channel filter (Online / In-Store)

### 9. Data Validation Requirement
All DAX-calculated measures to be validated against the underlying SQL source data before production sign-off, to ensure accuracy of time-intelligence calculations (YTD, MoM, Rolling Average).

### 10. Assumptions
- Target values are set monthly per category by the Sales Planning team and made available as a separate Targets table
- Fiscal year aligns with calendar year (Jan–Dec)
- End users are non-technical; UI must prioritize simplicity over advanced Power BI features

---
*Prepared by: Mirza Afzal Baig | Afzalytics, BI Developer*
*Date: October 2026*
