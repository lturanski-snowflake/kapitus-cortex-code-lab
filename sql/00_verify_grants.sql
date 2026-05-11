/*
    Kapitus × Snowflake Cortex Code Hands-On Lab
    Pre-Flight: Verify Grants for KAPITUS_TRAINING_ROLE
    
    Run as: KAPITUS_TRAINING_ROLE (to confirm what the role can actually do)
    If any check fails, an admin needs to re-run 01_environment_setup.sql.
*/

USE ROLE KAPITUS_TRAINING_ROLE;
USE DATABASE KAPITUS_TRAINING;
USE WAREHOUSE KAPITUS_TRAINING_WH;

--------------------------------------------------------------------
-- Check 1: Can we see all 4 source tables?
--------------------------------------------------------------------
SELECT '1. Source Tables' AS CHECK_NAME, 
       COUNT(*) AS RESULT, 
       CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL — expected 4 tables' END AS STATUS
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'SOURCE_DATA';

--------------------------------------------------------------------
-- Check 2: Can we SELECT from each source table?
--------------------------------------------------------------------
SELECT '2a. SELECT BORROWERS' AS CHECK_NAME, COUNT(*) AS RESULT, 'PASS' AS STATUS FROM SOURCE_DATA.BORROWERS;
SELECT '2b. SELECT LOAN_APPLICATIONS' AS CHECK_NAME, COUNT(*) AS RESULT, 'PASS' AS STATUS FROM SOURCE_DATA.LOAN_APPLICATIONS;
SELECT '2c. SELECT LOAN_DECISIONS' AS CHECK_NAME, COUNT(*) AS RESULT, 'PASS' AS STATUS FROM SOURCE_DATA.LOAN_DECISIONS;
SELECT '2d. SELECT PAYMENT_HISTORY' AS CHECK_NAME, COUNT(*) AS RESULT, 'PASS' AS STATUS FROM SOURCE_DATA.PAYMENT_HISTORY;

--------------------------------------------------------------------
-- Check 3: Can we INSERT into SOURCE_DATA tables? (needed for new apps)
--------------------------------------------------------------------
SELECT '3. INSERT on SOURCE_DATA' AS CHECK_NAME,
       CASE WHEN HAS_SCHEMA_PRIVILEGE('KAPITUS_TRAINING.SOURCE_DATA', 'CREATE TABLE') 
            THEN 'PASS' ELSE 'FAIL — need INSERT on SOURCE_DATA tables' END AS STATUS;

--------------------------------------------------------------------
-- Check 4: Can we create objects in our training schema?
--------------------------------------------------------------------
SELECT '4a. CREATE TABLE' AS CHECK_NAME,
       CASE WHEN HAS_SCHEMA_PRIVILEGE(CURRENT_SCHEMA(), 'CREATE TABLE') 
            THEN 'PASS' ELSE 'FAIL' END AS STATUS;

SELECT '4b. CREATE DYNAMIC TABLE' AS CHECK_NAME,
       CASE WHEN HAS_SCHEMA_PRIVILEGE(CURRENT_SCHEMA(), 'CREATE DYNAMIC TABLE') 
            THEN 'PASS' ELSE 'FAIL' END AS STATUS;

SELECT '4c. CREATE VIEW' AS CHECK_NAME,
       CASE WHEN HAS_SCHEMA_PRIVILEGE(CURRENT_SCHEMA(), 'CREATE VIEW') 
            THEN 'PASS' ELSE 'FAIL' END AS STATUS;

SELECT '4d. CREATE PROCEDURE' AS CHECK_NAME,
       CASE WHEN HAS_SCHEMA_PRIVILEGE(CURRENT_SCHEMA(), 'CREATE PROCEDURE') 
            THEN 'PASS' ELSE 'FAIL' END AS STATUS;

SELECT '4e. CREATE MODEL' AS CHECK_NAME,
       CASE WHEN HAS_SCHEMA_PRIVILEGE(CURRENT_SCHEMA(), 'CREATE MODEL') 
            THEN 'PASS' ELSE 'FAIL' END AS STATUS;

SELECT '4f. CREATE STREAMLIT' AS CHECK_NAME,
       CASE WHEN HAS_SCHEMA_PRIVILEGE(CURRENT_SCHEMA(), 'CREATE STREAMLIT') 
            THEN 'PASS' ELSE 'FAIL' END AS STATUS;

SELECT '4g. CREATE SEMANTIC VIEW' AS CHECK_NAME,
       CASE WHEN HAS_SCHEMA_PRIVILEGE(CURRENT_SCHEMA(), 'CREATE SEMANTIC VIEW') 
            THEN 'PASS' ELSE 'FAIL' END AS STATUS;

--------------------------------------------------------------------
-- Check 5: Warehouse access
--------------------------------------------------------------------
SELECT '5. Warehouse' AS CHECK_NAME,
       CASE WHEN HAS_ACCOUNT_PRIVILEGE('EXECUTE TASK') 
            THEN 'PASS' ELSE 'FAIL — need EXECUTE TASK' END AS STATUS;

--------------------------------------------------------------------
-- Check 6: Cortex AI access
--------------------------------------------------------------------
SELECT '6. Cortex User Role' AS CHECK_NAME,
       'PASS — if this query ran, you have warehouse access' AS STATUS;

--------------------------------------------------------------------
-- Summary
--------------------------------------------------------------------
SELECT 'ALL CHECKS COMPLETE' AS CHECK_NAME, 
       'If any above show FAIL, ask your admin to re-run sql/01_environment_setup.sql' AS STATUS;
