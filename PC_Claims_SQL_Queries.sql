-- ============================================================
-- P&C INSURANCE CLAIMS ANALYSIS — SQL QUERIES
-- Author: Rakesh Kambar
-- Dataset: 800 simulated P&C claims (Jan 2023 – Jun 2024)
-- Tools: MySQL / PostgreSQL / SQLite
-- ============================================================

CREATE DATABASE claims_db;
GO
USE claims_db;
GO

-- ============================================================
-- STEP 1: CREATE TABLE
-- ============================================================

CREATE TABLE pc_claims (
    Claim_ID VARCHAR(20) PRIMARY KEY,
    Claim_Type VARCHAR(50),
    Region VARCHAR(50),
    Adjuster VARCHAR(20),
    Date_Filed DATE,
    Date_Closed DATE,
    TAT_Days INT,
    Status VARCHAR(10),
    Estimated_Loss_USD DECIMAL(12,2),
    Paid_Amount_USD DECIMAL(12,2),
    Denial_Reason VARCHAR(50),
    Leakage_USD DECIMAL(12,2)
);

-- After creating table, import PC_Claims_Dataset.csv


USE claims_db;
GO

BULK INSERT pc_claims
FROM 'C:\Users\Rakesh\Downloads\PC_Claims_Dataset.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);
GO

-- ============================================================
-- verifying the table
-- ============================================================
SELECT COUNT(*) FROM pc_claims;

SELECT * FROM pc_claims;
-- ============================================================
-- QUERY 1: OVERALL CLAIMS SUMMARY
-- Purpose: High-level snapshot of portfolio health
-- ============================================================

SELECT
    COUNT(*) AS Total_Claims,
    SUM(CASE WHEN Status = 'Closed' THEN 1 ELSE 0 END) AS Closed_Claims,
    SUM(CASE WHEN Status = 'Open' THEN 1 ELSE 0 END) AS Open_Claims,
    ROUND(SUM(CASE WHEN Status = 'Closed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Closure_Rate_Pct,
    ROUND(SUM(Estimated_Loss_USD), 2) AS Total_Estimated_Loss,
    ROUND(SUM(Paid_Amount_USD), 2) AS Total_Paid_Amount
FROM pc_claims;


-- ============================================================
-- QUERY 2: TAT COMPLIANCE ANALYSIS
-- Purpose: Measure SLA adherence (14-day TAT standard)
-- Business context: At Sutherland, 14-day TAT was the KPI
-- ============================================================

SELECT
    COUNT(*) AS Total_Closed_Claims,
    SUM(CASE WHEN TAT_Days <= 14 THEN 1 ELSE 0 END) AS Within_TAT,
    SUM(CASE WHEN TAT_Days > 14 THEN 1 ELSE 0 END) AS TAT_Breached,
    ROUND(SUM(CASE WHEN TAT_Days <= 14 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS TAT_Compliance_Pct,
    ROUND(AVG(TAT_Days), 1) AS Avg_TAT_Days,
    MAX(TAT_Days) AS Max_TAT_Days
FROM pc_claims
WHERE Status = 'Closed';


-- ============================================================
-- QUERY 3: TAT BREACH BY CLAIM TYPE
-- Purpose: Identify which claim types are slowest to resolve
-- ============================================================

SELECT
    Claim_Type,
    COUNT(*) AS Total_Claims,
    SUM(CASE WHEN TAT_Days > 14 THEN 1 ELSE 0 END) AS TAT_Breaches,
    ROUND(SUM(CASE WHEN TAT_Days > 14 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Breach_Rate_Pct,
    ROUND(AVG(TAT_Days), 1) AS Avg_TAT_Days
FROM pc_claims
WHERE Status = 'Closed'
GROUP BY Claim_Type
ORDER BY Breach_Rate_Pct DESC;


-- ============================================================
-- QUERY 4: DENIAL REASON ANALYSIS
-- Purpose: Identify top reasons for claim denials
-- ============================================================

SELECT
    Denial_Reason,
    COUNT(*) AS Denial_Count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM pc_claims WHERE Denial_Reason != 'None'), 2) AS Pct_of_Total_Denials
FROM pc_claims
WHERE Denial_Reason != 'None'
GROUP BY Denial_Reason
ORDER BY Denial_Count DESC;


-- ============================================================
-- QUERY 5: FINANCIAL LEAKAGE ANALYSIS
-- Purpose: Detect under-payment and over-payment patterns
-- Leakage > 0 = Overpaid | Leakage < 0 = Underpaid
-- ============================================================

SELECT
    SUM(CASE WHEN Leakage_USD < 0 THEN 1 ELSE 0 END) AS Underpaid_Claims,
    SUM(CASE WHEN Leakage_USD > 0 THEN 1 ELSE 0 END) AS Overpaid_Claims,
    SUM(CASE WHEN Leakage_USD = 0 THEN 1 ELSE 0 END) AS Accurate_Claims,
    ROUND(SUM(CASE WHEN Leakage_USD < 0 THEN ABS(Leakage_USD) ELSE 0 END), 2) AS Total_Underpayment_USD,
    ROUND(SUM(CASE WHEN Leakage_USD > 0 THEN Leakage_USD ELSE 0 END), 2) AS Total_Overpayment_USD,
    ROUND(SUM(ABS(Leakage_USD)), 2) AS Total_Financial_Leakage_USD
FROM pc_claims
WHERE Status = 'Closed' AND Denial_Reason = 'None';


-- ============================================================
-- QUERY 6: LEAKAGE BY CLAIM TYPE
SELECT
    Claim_Type,
    COUNT(*) AS Claims_Count,
    ROUND(SUM(Estimated_Loss_USD), 2) AS Total_Estimated,
    ROUND(SUM(Paid_Amount_USD), 2) AS Total_Paid,
    ROUND(SUM(ABS(Leakage_USD)), 2) AS Total_Leakage,
    ROUND(SUM(ABS(Leakage_USD)) * 100.0 / SUM(Estimated_Loss_USD), 2) AS Leakage_Pct
FROM pc_claims
WHERE Status = 'Closed' AND Denial_Reason = 'None'
GROUP BY Claim_Type
ORDER BY Total_Leakage DESC;

-- QUERY 7: MONTHLY CLAIMS VOLUME TREND
SELECT
    FORMAT(Date_Filed, 'yyyy-MM') AS Month,
    COUNT(*) AS Claims_Filed,
    SUM(CASE WHEN Status = 'Closed' THEN 1 ELSE 0 END) AS Claims_Closed,
    ROUND(SUM(Estimated_Loss_USD), 2) AS Estimated_Loss_USD
FROM pc_claims
GROUP BY FORMAT(Date_Filed, 'yyyy-MM')
ORDER BY Month;

-- QUERY 8: ADJUSTER PERFORMANCE SCORECARD
SELECT
    Adjuster,
    COUNT(*) AS Total_Claims,
    ROUND(AVG(CAST(TAT_Days AS FLOAT)), 1) AS Avg_TAT_Days,
    SUM(CASE WHEN TAT_Days > 14 THEN 1 ELSE 0 END) AS TAT_Breaches,
    ROUND(SUM(ABS(Leakage_USD)), 2) AS Total_Leakage_USD,
    SUM(CASE WHEN Denial_Reason != 'None' THEN 1 ELSE 0 END) AS Denials
FROM pc_claims
WHERE Status = 'Closed'
GROUP BY Adjuster
ORDER BY Avg_TAT_Days ASC;

-- QUERY 9: REGIONAL PERFORMANCE
SELECT
    Region,
    COUNT(*) AS Total_Claims,
    SUM(CASE WHEN TAT_Days > 14 THEN 1 ELSE 0 END) AS TAT_Breaches,
    ROUND(AVG(CAST(TAT_Days AS FLOAT)), 1) AS Avg_TAT,
    ROUND(SUM(ABS(Leakage_USD)), 2) AS Total_Leakage_USD,
    SUM(CASE WHEN Denial_Reason != 'None' THEN 1 ELSE 0 END) AS Denied_Claims
FROM pc_claims
WHERE Status = 'Closed'
GROUP BY Region
ORDER BY Total_Leakage_USD DESC;

-- QUERY 10: HIGH VALUE OPEN CLAIMS
SELECT
    Claim_ID,
    Claim_Type,
    Region,
    Adjuster,
    Date_Filed,
    Estimated_Loss_USD,
    DATEDIFF(DAY, Date_Filed, GETDATE()) AS Days_Open
FROM pc_claims
WHERE Status = 'Open'
  AND Estimated_Loss_USD > 50000
ORDER BY Estimated_Loss_USD DESC;

-- QUERY 11: WRONGFUL DENIAL RISK
SELECT
    Claim_ID,
    Claim_Type,
    Region,
    Denial_Reason,
    Estimated_Loss_USD,
    Date_Filed
FROM pc_claims
WHERE Denial_Reason != 'None'
  AND Estimated_Loss_USD > 30000
ORDER BY Estimated_Loss_USD DESC;

-- QUERY 12: SLA COMPLIANCE BY MONTH
SELECT
    FORMAT(Date_Filed, 'yyyy-MM') AS Month,
    COUNT(*) AS Total_Closed,
    SUM(CASE WHEN TAT_Days <= 14 THEN 1 ELSE 0 END) AS Within_SLA,
    ROUND(SUM(CASE WHEN TAT_Days <= 14 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS SLA_Compliance_Pct
FROM pc_claims
WHERE Status = 'Closed'
GROUP BY FORMAT(Date_Filed, 'yyyy-MM')
ORDER BY Month;