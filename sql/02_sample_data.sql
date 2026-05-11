/*
    Kapitus × Snowflake Cortex Code Hands-On Lab
    Admin Pre-Lab: Synthetic Sample Data
    
    Run as: ACCOUNTADMIN (or role with CREATE TABLE on SOURCE_DATA)
    This is run by the admin BEFORE the lab. Attendees do NOT run this.
    Kept as a reference asset in the repo.
*/

USE DATABASE KAPITUS_TRAINING;
USE SCHEMA SOURCE_DATA;
USE WAREHOUSE KAPITUS_TRAINING_WH;

--------------------------------------------------------------------
-- Table 1: BORROWERS
--------------------------------------------------------------------
CREATE OR REPLACE TABLE BORROWERS (
    BORROWER_ID         VARCHAR(20)     NOT NULL,
    BUSINESS_NAME       VARCHAR(200),
    INDUSTRY            VARCHAR(100),
    STATE               VARCHAR(2),
    YEARS_IN_BUSINESS   NUMBER(4,1),
    ANNUAL_REVENUE      NUMBER(15,2),
    EMPLOYEE_COUNT      NUMBER(6),
    CREDIT_SCORE        NUMBER(3),
    EXISTING_DEBT       NUMBER(15,2),
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO BORROWERS
SELECT
    'BRW-' || LPAD(SEQ4()::VARCHAR, 6, '0')                           AS BORROWER_ID,
    'Business_' || SEQ4()::VARCHAR                                     AS BUSINESS_NAME,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Retail'
        WHEN 1 THEN 'Restaurant'
        WHEN 2 THEN 'Construction'
        WHEN 3 THEN 'Healthcare'
        WHEN 4 THEN 'Transportation'
        WHEN 5 THEN 'Technology'
        WHEN 6 THEN 'Manufacturing'
        WHEN 7 THEN 'Professional Services'
    END                                                                 AS INDUSTRY,
    CASE MOD(SEQ4(), 10)
        WHEN 0 THEN 'NY' WHEN 1 THEN 'CA' WHEN 2 THEN 'TX'
        WHEN 3 THEN 'FL' WHEN 4 THEN 'IL' WHEN 5 THEN 'PA'
        WHEN 6 THEN 'OH' WHEN 7 THEN 'GA' WHEN 8 THEN 'NJ'
        WHEN 9 THEN 'MA'
    END                                                                 AS STATE,
    ROUND(UNIFORM(0.5, 30.0, RANDOM()), 1)                             AS YEARS_IN_BUSINESS,
    ROUND(UNIFORM(50000, 5000000, RANDOM()), 2)                        AS ANNUAL_REVENUE,
    UNIFORM(1, 500, RANDOM())                                          AS EMPLOYEE_COUNT,
    UNIFORM(500, 850, RANDOM())                                        AS CREDIT_SCORE,
    ROUND(UNIFORM(0, 2000000, RANDOM()), 2)                            AS EXISTING_DEBT,
    DATEADD('day', -UNIFORM(30, 730, RANDOM()), CURRENT_TIMESTAMP())   AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 5000));

--------------------------------------------------------------------
-- Table 2: LOAN_APPLICATIONS
--------------------------------------------------------------------
CREATE OR REPLACE TABLE LOAN_APPLICATIONS (
    APPLICATION_ID      VARCHAR(20)     NOT NULL,
    BORROWER_ID         VARCHAR(20)     NOT NULL,
    APPLICATION_DATE    DATE,
    LOAN_AMOUNT         NUMBER(15,2),
    LOAN_PURPOSE        VARCHAR(50),
    LOAN_TERM_MONTHS    NUMBER(3),
    INTEREST_RATE       NUMBER(5,3),
    COLLATERAL_TYPE     VARCHAR(50),
    COLLATERAL_VALUE    NUMBER(15,2),
    APPLICATION_STATUS  VARCHAR(20),
    RISK_TIER           VARCHAR(10),
    SUBMITTED_CHANNEL   VARCHAR(20),
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO LOAN_APPLICATIONS
SELECT
    'APP-' || LPAD(SEQ4()::VARCHAR, 7, '0')                            AS APPLICATION_ID,
    'BRW-' || LPAD(UNIFORM(0, 4999, RANDOM())::VARCHAR, 6, '0')       AS BORROWER_ID,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_DATE())         AS APPLICATION_DATE,
    ROUND(UNIFORM(10000, 1000000, RANDOM()), 2)                        AS LOAN_AMOUNT,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'Working Capital'
        WHEN 1 THEN 'Equipment Purchase'
        WHEN 2 THEN 'Expansion'
        WHEN 3 THEN 'Inventory'
        WHEN 4 THEN 'Debt Consolidation'
        WHEN 5 THEN 'Real Estate'
    END                                                                 AS LOAN_PURPOSE,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 6 WHEN 1 THEN 12 WHEN 2 THEN 24
        WHEN 3 THEN 36 WHEN 4 THEN 60
    END                                                                 AS LOAN_TERM_MONTHS,
    ROUND(UNIFORM(4.5, 24.9, RANDOM()), 3)                             AS INTEREST_RATE,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'Real Estate'
        WHEN 1 THEN 'Equipment'
        WHEN 2 THEN 'Accounts Receivable'
        WHEN 3 THEN 'Unsecured'
    END                                                                 AS COLLATERAL_TYPE,
    ROUND(UNIFORM(0, 2000000, RANDOM()), 2)                            AS COLLATERAL_VALUE,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'PENDING'
        WHEN 1 THEN 'APPROVED'
        WHEN 2 THEN 'DECLINED'
        WHEN 3 THEN 'UNDER_REVIEW'
        WHEN 4 THEN 'PENDING'
    END                                                                 AS APPLICATION_STATUS,
    CASE
        WHEN UNIFORM(0, 100, RANDOM()) < 20 THEN 'HIGH'
        WHEN UNIFORM(0, 100, RANDOM()) < 60 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                                 AS RISK_TIER,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 'Online'
        WHEN 1 THEN 'Broker'
        WHEN 2 THEN 'Direct'
    END                                                                 AS SUBMITTED_CHANNEL,
    DATEADD('day', -UNIFORM(0, 365, RANDOM()), CURRENT_TIMESTAMP())    AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 20000));

--------------------------------------------------------------------
-- Table 3: LOAN_DECISIONS
--------------------------------------------------------------------
CREATE OR REPLACE TABLE LOAN_DECISIONS (
    DECISION_ID         VARCHAR(20)     NOT NULL,
    APPLICATION_ID      VARCHAR(20)     NOT NULL,
    DECISION_DATE       DATE,
    DECISION            VARCHAR(20),
    UNDERWRITER_ID      VARCHAR(20),
    DECISION_REASON     VARCHAR(200),
    APPROVED_AMOUNT     NUMBER(15,2),
    CONDITIONS          VARCHAR(500),
    PROCESSING_TIME_HRS NUMBER(6,1),
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO LOAN_DECISIONS
SELECT
    'DEC-' || LPAD(SEQ4()::VARCHAR, 7, '0')                            AS DECISION_ID,
    'APP-' || LPAD(UNIFORM(0, 19999, RANDOM())::VARCHAR, 7, '0')       AS APPLICATION_ID,
    DATEADD('day', -UNIFORM(0, 350, RANDOM()), CURRENT_DATE())         AS DECISION_DATE,
    CASE MOD(SEQ4(), 4)
        WHEN 0 THEN 'APPROVED'
        WHEN 1 THEN 'DECLINED'
        WHEN 2 THEN 'APPROVED'
        WHEN 3 THEN 'CONDITIONAL'
    END                                                                 AS DECISION,
    'UW-' || LPAD(UNIFORM(1, 20, RANDOM())::VARCHAR, 3, '0')          AS UNDERWRITER_ID,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'Strong financials and credit history'
        WHEN 1 THEN 'Insufficient cash flow for requested amount'
        WHEN 2 THEN 'Good collateral coverage'
        WHEN 3 THEN 'High debt-to-income ratio'
        WHEN 4 THEN 'Approved with reduced amount'
    END                                                                 AS DECISION_REASON,
    ROUND(UNIFORM(5000, 900000, RANDOM()), 2)                          AS APPROVED_AMOUNT,
    CASE MOD(SEQ4(), 3)
        WHEN 0 THEN 'None'
        WHEN 1 THEN 'Additional documentation required'
        WHEN 2 THEN 'Personal guarantee required'
    END                                                                 AS CONDITIONS,
    ROUND(UNIFORM(1, 120, RANDOM()), 1)                                AS PROCESSING_TIME_HRS,
    DATEADD('day', -UNIFORM(0, 350, RANDOM()), CURRENT_TIMESTAMP())    AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 15000));

--------------------------------------------------------------------
-- Table 4: PAYMENT_HISTORY
--------------------------------------------------------------------
CREATE OR REPLACE TABLE PAYMENT_HISTORY (
    PAYMENT_ID          VARCHAR(20)     NOT NULL,
    APPLICATION_ID      VARCHAR(20)     NOT NULL,
    PAYMENT_DATE        DATE,
    PAYMENT_AMOUNT      NUMBER(12,2),
    PRINCIPAL_AMOUNT    NUMBER(12,2),
    INTEREST_AMOUNT     NUMBER(12,2),
    REMAINING_BALANCE   NUMBER(15,2),
    DAYS_LATE           NUMBER(4),
    PAYMENT_STATUS      VARCHAR(20),
    CREATED_AT          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO PAYMENT_HISTORY
SELECT
    'PMT-' || LPAD(SEQ4()::VARCHAR, 8, '0')                            AS PAYMENT_ID,
    'APP-' || LPAD(UNIFORM(0, 14999, RANDOM())::VARCHAR, 7, '0')       AS APPLICATION_ID,
    DATEADD('day', -UNIFORM(0, 300, RANDOM()), CURRENT_DATE())         AS PAYMENT_DATE,
    ROUND(UNIFORM(500, 50000, RANDOM()), 2)                            AS PAYMENT_AMOUNT,
    ROUND(UNIFORM(300, 40000, RANDOM()), 2)                            AS PRINCIPAL_AMOUNT,
    ROUND(UNIFORM(50, 10000, RANDOM()), 2)                             AS INTEREST_AMOUNT,
    ROUND(UNIFORM(0, 900000, RANDOM()), 2)                             AS REMAINING_BALANCE,
    CASE
        WHEN UNIFORM(0, 100, RANDOM()) < 75 THEN 0
        WHEN UNIFORM(0, 100, RANDOM()) < 90 THEN UNIFORM(1, 15, RANDOM())
        ELSE UNIFORM(16, 90, RANDOM())
    END                                                                 AS DAYS_LATE,
    CASE
        WHEN UNIFORM(0, 100, RANDOM()) < 80 THEN 'ON_TIME'
        WHEN UNIFORM(0, 100, RANDOM()) < 92 THEN 'LATE'
        ELSE 'MISSED'
    END                                                                 AS PAYMENT_STATUS,
    DATEADD('day', -UNIFORM(0, 300, RANDOM()), CURRENT_TIMESTAMP())    AS CREATED_AT
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

--------------------------------------------------------------------
-- Add a fraud indicator to LOAN_APPLICATIONS for ML use case
-- (Synthetic: ~8% fraud rate based on feature combinations)
--------------------------------------------------------------------
ALTER TABLE LOAN_APPLICATIONS ADD COLUMN IF NOT EXISTS IS_FRAUDULENT BOOLEAN DEFAULT FALSE;

UPDATE LOAN_APPLICATIONS
SET IS_FRAUDULENT = TRUE
WHERE (
    LOAN_AMOUNT > 500000
    AND RISK_TIER = 'HIGH'
    AND UNIFORM(0, 100, RANDOM()) < 40
) OR (
    SUBMITTED_CHANNEL = 'Online'
    AND LOAN_TERM_MONTHS <= 12
    AND LOAN_AMOUNT > 300000
    AND UNIFORM(0, 100, RANDOM()) < 25
) OR (
    COLLATERAL_TYPE = 'Unsecured'
    AND LOAN_AMOUNT > 400000
    AND UNIFORM(0, 100, RANDOM()) < 30
);

--------------------------------------------------------------------
-- Verify counts
--------------------------------------------------------------------
SELECT 'BORROWERS' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM BORROWERS
UNION ALL
SELECT 'LOAN_APPLICATIONS', COUNT(*) FROM LOAN_APPLICATIONS
UNION ALL
SELECT 'LOAN_DECISIONS', COUNT(*) FROM LOAN_DECISIONS
UNION ALL
SELECT 'PAYMENT_HISTORY', COUNT(*) FROM PAYMENT_HISTORY;

SELECT 'Fraud Rate' AS METRIC, 
       ROUND(SUM(CASE WHEN IS_FRAUDULENT THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 2) || '%' AS VALUE
FROM LOAN_APPLICATIONS;

--------------------------------------------------------------------
-- Grant DML on SOURCE_DATA tables to training role
-- (Must run AFTER tables are created — FUTURE grants don't apply
--  to tables owned by ACCOUNTADMIN in an existing schema)
--------------------------------------------------------------------
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA KAPITUS_TRAINING.SOURCE_DATA TO ROLE KAPITUS_TRAINING_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA KAPITUS_TRAINING.SOURCE_DATA TO ROLE KAPITUS_TRAINING_ROLE;
