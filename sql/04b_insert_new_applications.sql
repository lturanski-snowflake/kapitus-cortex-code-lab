/*
    Kapitus × Snowflake Cortex Code Hands-On Lab
    Helper: Insert New Loan Applications to Score
    
    Run this AFTER the model is trained to simulate new incoming applications.
    These will be in PENDING status and ready for the scoring pipeline.
*/

USE DATABASE KAPITUS_TRAINING;
USE SCHEMA TRAINING_LUKE;  -- Replace with your schema (TRAINING_<USERNAME>)
USE WAREHOUSE KAPITUS_TRAINING_WH;

--------------------------------------------------------------------
-- Insert 50 new PENDING loan applications into SOURCE_DATA
-- (In production this would come from KapitusPLUS application intake)
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
    ROUND(UNIFORM(10000, 1000000, RANDOM()), 2) AS LOAN_AMOUNT,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Working Capital'
        WHEN 1 THEN 'Equipment Purchase'
        WHEN 2 THEN 'Expansion'
        WHEN 3 THEN 'Inventory'
        WHEN 4 THEN 'Debt Consolidation'
        WHEN 5 THEN 'Real Estate'
    END AS LOAN_PURPOSE,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 12 WHEN 1 THEN 24 WHEN 2 THEN 36 WHEN 3 THEN 60
    END AS LOAN_TERM_MONTHS,
    ROUND(UNIFORM(4.5, 24.9, RANDOM()), 3) AS INTEREST_RATE,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Real Estate'
        WHEN 1 THEN 'Equipment'
        WHEN 2 THEN 'Accounts Receivable'
        WHEN 3 THEN 'Unsecured'
    END AS COLLATERAL_TYPE,
    ROUND(UNIFORM(0, 2000000, RANDOM()), 2) AS COLLATERAL_VALUE,
    'PENDING' AS APPLICATION_STATUS,
    CASE
        WHEN UNIFORM(0, 100, RANDOM()) < 30 THEN 'HIGH'
        WHEN UNIFORM(0, 100, RANDOM()) < 70 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS RISK_TIER,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 'Online'
        WHEN 1 THEN 'Broker'
        WHEN 2 THEN 'Direct'
    END AS SUBMITTED_CHANNEL,
    FALSE AS IS_FRAUDULENT
FROM TABLE(GENERATOR(ROWCOUNT => 50));

SELECT COUNT(*) AS NEW_PENDING_APPS
FROM SOURCE_DATA.LOAN_APPLICATIONS
WHERE APPLICATION_STATUS = 'PENDING'
  AND APPLICATION_ID LIKE 'NEW-%';
