/*
    Kapitus × Snowflake Cortex Code Hands-On Lab
    Step 6: Semantic View — Loan Analytics
    
    Created in YOUR schema, over your LOAN_ANALYTICS_MART.
    Uses FACTS/DIMENSIONS/METRICS syntax (NOT COLUMNS/LABEL).
*/

USE DATABASE KAPITUS_TRAINING;
USE SCHEMA TRAINING_LUKE;  -- Replace with your schema (TRAINING_<USERNAME>)
USE WAREHOUSE KAPITUS_TRAINING_WH;

CREATE OR REPLACE SEMANTIC VIEW LOAN_ANALYTICS_SV
TABLES (
    loan_mart AS LOAN_ANALYTICS_MART
        PRIMARY KEY (APPLICATION_ID)
        COMMENT = 'Denormalized loan analytics mart'
)
DIMENSIONS (
    loan_mart.LOAN_AMOUNT AS LOAN_AMOUNT COMMENT = 'Requested loan amount in USD',
    loan_mart.LOAN_PURPOSE AS LOAN_PURPOSE COMMENT = 'Purpose of the loan',
    loan_mart.RISK_TIER AS RISK_TIER COMMENT = 'Risk classification HIGH/MEDIUM/LOW',
    loan_mart.INDUSTRY AS INDUSTRY COMMENT = 'Business industry',
    loan_mart.STATE AS STATE COMMENT = 'Business US state',
    loan_mart.SUBMITTED_CHANNEL AS SUBMITTED_CHANNEL COMMENT = 'Submission channel',
    loan_mart.CREDIT_SCORE AS CREDIT_SCORE COMMENT = 'Credit score 500-850',
    loan_mart.DECISION AS DECISION COMMENT = 'Underwriting decision',
    loan_mart.APPLICATION_DATE AS APPLICATION_DATE COMMENT = 'Date application submitted',
    loan_mart.IS_FRAUDULENT AS IS_FRAUDULENT COMMENT = 'Fraud flag'
)
METRICS (
    loan_mart.TOTAL_LOAN_VOLUME AS SUM(loan_mart.LOAN_AMOUNT) COMMENT = 'Total loan volume in USD',
    loan_mart.APPLICATION_COUNT AS COUNT(loan_mart.APPLICATION_ID) COMMENT = 'Number of applications',
    loan_mart.AVG_LOAN_AMOUNT AS AVG(loan_mart.LOAN_AMOUNT) COMMENT = 'Average loan amount',
    loan_mart.AVG_CREDIT_SCORE AS AVG(loan_mart.CREDIT_SCORE) COMMENT = 'Average credit score',
    loan_mart.FRAUD_RATE AS AVG(CASE WHEN loan_mart.IS_FRAUDULENT THEN 1.0 ELSE 0.0 END) COMMENT = 'Fraud rate as decimal'
);
