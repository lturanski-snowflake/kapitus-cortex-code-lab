/*
    Kapitus × Snowflake Cortex Code Hands-On Lab
    Helper: Insert New Loan Applications to Score
    
    Run this AFTER the model is trained to simulate new incoming applications.
    These will be in PENDING status and ready for the scoring pipeline.
    
    Mix: ~35 normal applications + ~15 suspicious ones that should trigger
    the fraud model (high amount, unsecured, online, high risk, short term).
*/

USE DATABASE KAPITUS_TRAINING;
USE SCHEMA TRAINING_LUKE;  -- Replace with your schema (TRAINING_<USERNAME>)
USE WAREHOUSE KAPITUS_TRAINING_WH;

--------------------------------------------------------------------
-- Insert 35 normal PENDING applications
--------------------------------------------------------------------
INSERT INTO SOURCE_DATA.LOAN_APPLICATIONS (
    APPLICATION_ID, BORROWER_ID, APPLICATION_DATE, LOAN_AMOUNT, LOAN_PURPOSE,
    LOAN_TERM_MONTHS, INTEREST_RATE, COLLATERAL_TYPE, COLLATERAL_VALUE,
    APPLICATION_STATUS, RISK_TIER, SUBMITTED_CHANNEL, IS_FRAUDULENT
)
SELECT
    'NEW-' || LPAD(SEQ4()::VARCHAR, 5, '0') AS APPLICATION_ID,
    'BRW-' || LPAD(UNIFORM(0, 4999, RANDOM())::VARCHAR, 6, '0') AS BORROWER_ID,
    CURRENT_DATE() AS APPLICATION_DATE,
    ROUND(UNIFORM(10000, 300000, RANDOM()), 2) AS LOAN_AMOUNT,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Working Capital'
        WHEN 1 THEN 'Equipment Purchase'
        WHEN 2 THEN 'Expansion'
        WHEN 3 THEN 'Inventory'
        WHEN 4 THEN 'Debt Consolidation'
        WHEN 5 THEN 'Real Estate'
    END AS LOAN_PURPOSE,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 24 WHEN 1 THEN 36 WHEN 2 THEN 48 WHEN 3 THEN 60
    END AS LOAN_TERM_MONTHS,
    ROUND(UNIFORM(4.5, 15.0, RANDOM()), 3) AS INTEREST_RATE,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 'Real Estate'
        WHEN 1 THEN 'Equipment'
        WHEN 2 THEN 'Accounts Receivable'
    END AS COLLATERAL_TYPE,
    ROUND(UNIFORM(100000, 2000000, RANDOM()), 2) AS COLLATERAL_VALUE,
    'PENDING' AS APPLICATION_STATUS,
    CASE
        WHEN UNIFORM(0, 100, RANDOM()) < 15 THEN 'HIGH'
        WHEN UNIFORM(0, 100, RANDOM()) < 60 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS RISK_TIER,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 'Direct'
        WHEN 1 THEN 'Broker'
        WHEN 2 THEN 'Direct'
    END AS SUBMITTED_CHANNEL,
    FALSE AS IS_FRAUDULENT
FROM TABLE(GENERATOR(ROWCOUNT => 35));

--------------------------------------------------------------------
-- Insert 15 suspicious applications (match fraud training patterns:
-- high loan amount, unsecured, online channel, high risk, short term)
--------------------------------------------------------------------
INSERT INTO SOURCE_DATA.LOAN_APPLICATIONS (
    APPLICATION_ID, BORROWER_ID, APPLICATION_DATE, LOAN_AMOUNT, LOAN_PURPOSE,
    LOAN_TERM_MONTHS, INTEREST_RATE, COLLATERAL_TYPE, COLLATERAL_VALUE,
    APPLICATION_STATUS, RISK_TIER, SUBMITTED_CHANNEL, IS_FRAUDULENT
)
SELECT
    'NEW-' || LPAD((35 + SEQ4())::VARCHAR, 5, '0') AS APPLICATION_ID,
    'BRW-' || LPAD(UNIFORM(0, 4999, RANDOM())::VARCHAR, 6, '0') AS BORROWER_ID,
    CURRENT_DATE() AS APPLICATION_DATE,
    ROUND(UNIFORM(500000, 1000000, RANDOM()), 2) AS LOAN_AMOUNT,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 'Working Capital'
        WHEN 1 THEN 'Debt Consolidation'
        WHEN 2 THEN 'Expansion'
    END AS LOAN_PURPOSE,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 6 WHEN 1 THEN 12 WHEN 2 THEN 6
    END AS LOAN_TERM_MONTHS,
    ROUND(UNIFORM(18.0, 24.9, RANDOM()), 3) AS INTEREST_RATE,
    'Unsecured' AS COLLATERAL_TYPE,
    ROUND(UNIFORM(0, 50000, RANDOM()), 2) AS COLLATERAL_VALUE,
    'PENDING' AS APPLICATION_STATUS,
    'HIGH' AS RISK_TIER,
    'Online' AS SUBMITTED_CHANNEL,
    FALSE AS IS_FRAUDULENT
FROM TABLE(GENERATOR(ROWCOUNT => 15));

--------------------------------------------------------------------
-- Verify
--------------------------------------------------------------------
SELECT COUNT(*) AS NEW_PENDING_APPS,
       SUM(CASE WHEN RISK_TIER = 'HIGH' AND COLLATERAL_TYPE = 'Unsecured' THEN 1 ELSE 0 END) AS SUSPICIOUS_APPS
FROM SOURCE_DATA.LOAN_APPLICATIONS
WHERE APPLICATION_STATUS = 'PENDING'
  AND APPLICATION_ID LIKE 'NEW-%';
