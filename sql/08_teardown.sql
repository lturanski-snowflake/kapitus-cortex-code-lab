/*
    Kapitus × Snowflake Cortex Code Hands-On Lab
    Step 8: Teardown
    
    Run as: ACCOUNTADMIN (or KAPITUS_TRAINING_ROLE for schema-level cleanup)
    Removes all lab resources. This is irreversible.
    
    NOTE: Uncomment the sections you want to tear down.
    By default everything is commented out to prevent accidental deletion.
*/

USE ROLE KAPITUS_TRAINING_ROLE;
USE DATABASE KAPITUS_TRAINING;
USE WAREHOUSE KAPITUS_TRAINING_WH;

--------------------------------------------------------------------
-- 1. Per-Attendee Cleanup (run in YOUR schema)
--    Uncomment if you want to clean up your own schema objects
--------------------------------------------------------------------

-- USE SCHEMA TRAINING_<USERNAME>;

-- -- Skills stage
-- DROP STAGE IF EXISTS SKILLS;

-- -- Module 4: Agent + Semantic View
-- DROP AGENT IF EXISTS LOAN_ANALYTICS_AGENT;
-- DROP SEMANTIC VIEW IF EXISTS LOAN_ANALYTICS_SV;

-- -- Module 3: Streamlit
-- DROP STREAMLIT IF EXISTS LOAN_REVIEW_DASHBOARD;

-- -- Module 2: ML Pipeline
-- ALTER TASK IF EXISTS SCORE_PENDING_APPLICATIONS SUSPEND;
-- DROP TASK IF EXISTS SCORE_PENDING_APPLICATIONS;
-- DROP TABLE IF EXISTS FRAUD_SCORES;
-- DROP TABLE IF EXISTS AUTO_APPROVED;
-- DROP TABLE IF EXISTS FLAGGED_FOR_REVIEW;
-- DROP TABLE IF EXISTS PREDICTION_AUDIT_LOG;
-- DROP SNOWFLAKE.ML.CLASSIFICATION IF EXISTS FRAUD_DETECTION_MODEL;
-- DROP VIEW IF EXISTS FRAUD_TRAINING_DATA;

-- -- Module 1: Dynamic Table
-- DROP DYNAMIC TABLE IF EXISTS LOAN_ANALYTICS_MART;

-- -- Source tables (cloned)
-- DROP TABLE IF EXISTS LOAN_APPLICATIONS;
-- DROP TABLE IF EXISTS BORROWERS;
-- DROP TABLE IF EXISTS LOAN_DECISIONS;
-- DROP TABLE IF EXISTS PAYMENT_HISTORY;

--------------------------------------------------------------------
-- 2. Full Environment Teardown (ACCOUNTADMIN only)
--    Uncomment ONLY if you want to destroy the entire lab environment
--------------------------------------------------------------------

-- USE ROLE ACCOUNTADMIN;

-- -- Suspend any running tasks
-- ALTER TASK IF EXISTS KAPITUS_TRAINING.SOURCE_DATA.SCORE_PENDING_APPLICATIONS SUSPEND;

-- -- Drop everything
-- DROP DATABASE IF EXISTS KAPITUS_TRAINING;
-- DROP WAREHOUSE IF EXISTS KAPITUS_TRAINING_WH;
-- DROP ROLE IF EXISTS KAPITUS_TRAINING_ROLE;
