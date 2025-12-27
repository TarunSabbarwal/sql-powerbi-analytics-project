/*
Project: Company Sales Analytics (2020–2022)
Author: Tarun Sabbarwal

Background:
Sales data from 2020, 2021 and 2022 was merged into a single fact table
during Power BI modeling. SQL was used alongside Power BI to validate
trends, check distributions, and understand business drivers before
finalizing dashboards.

Note:
Raw data is not shared publicly. These queries reflect the same
data model used in the Power BI report.
*/

-------------------------------------------------
-- BASE SALES DATA WITH DATE CONTEXT
-- ------------------------------------------------
-- This CTE was created first to simplify joins
-- and avoid repeating calendar logic in every query
-------------------------------------------------

WITH base_sales AS (
    SELECT
        s.[OrderNumber],
        s.[OrderDate],
        s.[CustomerKey],
        s.[ProductKey],
        s.[TerritoryKey],
        s.[OrderQuantity],
        s.[Total Revenue],
        cal.[Year],
        cal.[Start of Month]
    FROM [Sales Data 2020-2022] s
    JOIN [Calendar Lookup] cal
        ON s.[OrderDate] = cal.[Date]
),

-------------------------------------------------
-- YEARLY AND MONTHLY SALES TREND
-- ------------------------------------------------
-- Used to validate revenue trends shown
-- in the Power BI time-series visuals
-------------------------------------------------

sales_trend AS (
    SELECT
        [Year],
        [Start of Month],
        SUM([Total Revenue]) AS monthly_revenue,
        SUM([OrderQuantity]) AS units_sold
    FROM base_sales
    GROUP BY
        [Year],
        [Start of Month]
),

-------------------------------------------------
-- PRODUCT PERFORMANCE ANALYSIS
-- ------------------------------------------------
-- Initial analysis was done only at product level,
-- later extended to include category for better insights
-------------------------------------------------

product_performance AS (
    SELECT
        p.[ProductName],
        pc.[CategoryName],
        SUM(b.[OrderQuantity]) AS total_units_sold,
        SUM(b.[Total Revenue]) AS total_revenue
    FROM base_sales b
    JOIN [Product Lookup] p
        ON b.[ProductKey] = p.[ProductKey]
    JOIN [Product Categories Lookup] pc
        ON p.[ProductCategoryKey] = pc.[ProductCategoryKey]
    GROUP BY
        p.[ProductName],
        pc.[CategoryName]
),

-------------------------------------------------
-- CUSTOMER SEGMENTATION BY INCOME LEVEL
-- ------------------------------------------------
-- This helped understand which income groups
-- contribute most to overall revenue
-------------------------------------------------

customer_segmentation AS (
    SELECT
        c.[Income Level],
        COUNT(DISTINCT b.[CustomerKey]) AS customer_count,
        SUM(b.[Total Revenue]) AS revenue
    FROM base_sales b
    JOIN [Customer Lookup] c
        ON b.[CustomerKey] = c.[CustomerKey]
    GROUP BY c.[Income Level]
),

-------------------------------------------------
-- RETURNS VS SALES ANALYSIS
-- ------------------------------------------------
-- Added later after noticing high return volume
-- for some products in the Power BI report
-------------------------------------------------

returns_summary AS (
    SELECT
        r.[ProductKey],
        SUM(r.[ReturnQuantity]) AS total_returns
    FROM [Returns Data] r
    GROUP BY r.[ProductKey]
),

returns_vs_sales AS (
    SELECT
        p.[ProductName],
        SUM(b.[OrderQuantity]) AS total_sold,
        COALESCE(r.total_returns, 0) AS total_returned,
        ROUND(
            COALESCE(r.total_returns, 0) * 100.0 /
            NULLIF(SUM(b.[OrderQuantity]), 0),
            2
        ) AS return_percentage
    FROM base_sales b
    JOIN [Product Lookup] p
        ON b.[ProductKey] = p.[ProductKey]
    LEFT JOIN returns_summary r
        ON b.[ProductKey] = r.[ProductKey]
    GROUP BY
        p.[ProductName],
        r.total_returns
),

-------------------------------------------------
-- REGIONAL PERFORMANCE AND RANKING
-- ------------------------------------------------
-- Used to compare regional contribution
-- and support geographic insights in dashboards
-------------------------------------------------

regional_performance AS (
    SELECT
        t.[Region],
        t.[Country],
        SUM(b.[Total Revenue]) AS regional_revenue
    FROM base_sales b
    JOIN [Territory Lookup] t
        ON b.[TerritoryKey] = t.[TerritoryKey]
    GROUP BY
        t.[Region],
        t.[Country]
)

-------------------------------------------------
-- FINAL OUTPUTS (FOR ANALYSIS & DISCUSSION)
-------------------------------------------------

-- Year-wise and Month-wise Revenue Trend
SELECT *
FROM sales_trend
ORDER BY [Year], [Start of Month];

-- Top 10 Products by Revenue
SELECT
    ProductName,
    CategoryName,
    total_units_sold,
    total_revenue
FROM product_performance
ORDER BY total_revenue DESC
OFFSET 0 ROWS FETCH NEXT 10 ROWS ONLY;

-- Revenue Contribution by Customer Income Level
SELECT
    [Income Level],
    customer_count,
    revenue,
    ROUND(
        revenue * 100.0 / SUM(revenue) OVER (),
        2
    ) AS revenue_percentage
FROM customer_segmentation
ORDER BY revenue DESC;

-- Products with Highest Return Percentage
SELECT *
FROM returns_vs_sales
ORDER BY return_percentage DESC;

-- Regional Revenue Ranking
SELECT
    Region,
    Country,
    regional_revenue,
    RANK() OVER (ORDER BY regional_revenue DESC) AS region_rank
FROM regional_performance;
