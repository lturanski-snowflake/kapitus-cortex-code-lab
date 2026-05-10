/*
    Kapitus × Snowflake Cortex Code Hands-On Lab
    Step 4: ML Fraud Detection Pipeline (Snowpark ML + Model Registry)
    
    IMPORTANT: All objects are created in YOUR attendee schema.
    Reads from LOAN_ANALYTICS_MART (already in your schema from Module 1).
    
    Approach:
    1. Create a training view with features
    2. Create a stored procedure that trains XGBoost via Snowpark ML
       and registers the model in the Snowflake Model Registry
    3. Call the sproc to train + register
    4. Score applications using MODEL!PREDICT() in SQL
    5. Route and audit predictions
*/

USE DATABASE KAPITUS_TRAINING;
USE SCHEMA TRAINING_LUKE;  -- Replace with your schema (TRAINING_<USERNAME>)
USE WAREHOUSE KAPITUS_TRAINING_WH;

--------------------------------------------------------------------
-- 1. Create Training View (features from the mart)
--------------------------------------------------------------------
CREATE OR REPLACE VIEW FRAUD_TRAINING_DATA AS
SELECT
    APPLICATION_ID,
    LOAN_AMOUNT,
    LOAN_TERM_MONTHS,
    INTEREST_RATE,
    CREDIT_SCORE,
    YEARS_IN_BUSINESS,
    ANNUAL_REVENUE,
    EMPLOYEE_COUNT,
    EXISTING_DEBT,
    COLLATERAL_VALUE,
    LOAN_TO_REVENUE_RATIO,
    DEBT_TO_REVENUE_RATIO,
    COLLATERAL_COVERAGE_RATIO,
    CASE WHEN INDUSTRY = 'Retail' THEN 1 ELSE 0 END AS IS_RETAIL,
    CASE WHEN INDUSTRY = 'Restaurant' THEN 1 ELSE 0 END AS IS_RESTAURANT,
    CASE WHEN INDUSTRY = 'Construction' THEN 1 ELSE 0 END AS IS_CONSTRUCTION,
    CASE WHEN INDUSTRY = 'Healthcare' THEN 1 ELSE 0 END AS IS_HEALTHCARE,
    CASE WHEN INDUSTRY = 'Technology' THEN 1 ELSE 0 END AS IS_TECHNOLOGY,
    CASE WHEN SUBMITTED_CHANNEL = 'Online' THEN 1 ELSE 0 END AS IS_ONLINE_CHANNEL,
    CASE WHEN SUBMITTED_CHANNEL = 'Broker' THEN 1 ELSE 0 END AS IS_BROKER_CHANNEL,
    CASE WHEN COLLATERAL_TYPE = 'Unsecured' THEN 1 ELSE 0 END AS IS_UNSECURED,
    CASE WHEN RISK_TIER = 'HIGH' THEN 1 ELSE 0 END AS IS_HIGH_RISK,
    IS_FRAUDULENT::INTEGER AS IS_FRAUDULENT
FROM LOAN_ANALYTICS_MART
WHERE LOAN_AMOUNT IS NOT NULL
  AND CREDIT_SCORE IS NOT NULL;

--------------------------------------------------------------------
-- 2. Create training stored procedure (Snowpark ML + Model Registry)
--------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE TRAIN_FRAUD_MODEL()
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python', 'snowflake-ml-python', 'xgboost', 'scikit-learn')
HANDLER = 'main'
AS
$$
def main(session):
    from snowflake.ml.registry import Registry
    from xgboost import XGBClassifier
    from sklearn.metrics import f1_score, precision_score, recall_score
    from sklearn.model_selection import train_test_split
    import pandas as pd

    df = session.table('FRAUD_TRAINING_DATA').to_pandas()

    feature_cols = [c for c in df.columns if c not in ('APPLICATION_ID', 'IS_FRAUDULENT')]
    X = df[feature_cols]
    y = df['IS_FRAUDULENT']

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.25, random_state=42, stratify=y
    )

    model = XGBClassifier(
        n_estimators=100,
        max_depth=6,
        learning_rate=0.1,
        random_state=42,
        use_label_encoder=False,
        eval_metric='logloss'
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    f1 = round(f1_score(y_test, y_pred), 4)
    precision = round(precision_score(y_test, y_pred), 4)
    recall = round(recall_score(y_test, y_pred), 4)

    reg = Registry(session=session)

    sample_input = X_train.head(10)

    mv = reg.log_model(
        model_name='FRAUD_DETECTION_MODEL',
        version_name='V1',
        model=model,
        sample_input_data=sample_input,
        comment=f'XGBoost fraud detection. F1={f1}, Precision={precision}, Recall={recall}'
    )

    mv.set_metric(metric_name='test_f1', value=f1)
    mv.set_metric(metric_name='test_precision', value=precision)
    mv.set_metric(metric_name='test_recall', value=recall)

    return f'Model registered: FRAUD_DETECTION_MODEL V1 | F1={f1} | Precision={precision} | Recall={recall}'
$$;

--------------------------------------------------------------------
-- 3. Train the model (call the sproc)
--------------------------------------------------------------------
CALL TRAIN_FRAUD_MODEL();

--------------------------------------------------------------------
-- 4. Verify model is registered
--------------------------------------------------------------------
SHOW MODELS;

--------------------------------------------------------------------
-- 5. Create output tables for prediction routing
--------------------------------------------------------------------
CREATE OR REPLACE TABLE AUTO_APPROVED (
    APPLICATION_ID      VARCHAR(20),
    FRAUD_PROBABILITY   FLOAT,
    PREDICTION          INTEGER,
    SCORED_AT           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE FLAGGED_FOR_REVIEW (
    APPLICATION_ID      VARCHAR(20),
    FRAUD_PROBABILITY   FLOAT,
    PREDICTION          INTEGER,
    RISK_TIER           VARCHAR(10),
    LOAN_AMOUNT         NUMBER(15,2),
    BUSINESS_NAME       VARCHAR(200),
    INDUSTRY            VARCHAR(100),
    SCORED_AT           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    REVIEW_STATUS       VARCHAR(20) DEFAULT 'PENDING',
    REVIEWED_BY         VARCHAR(100),
    REVIEW_DATE         TIMESTAMP_NTZ,
    REVIEW_DECISION     VARCHAR(20)
);

CREATE OR REPLACE TABLE PREDICTION_AUDIT_LOG (
    AUDIT_ID            VARCHAR(40) DEFAULT UUID_STRING(),
    APPLICATION_ID      VARCHAR(20),
    MODEL_NAME          VARCHAR(100) DEFAULT 'FRAUD_DETECTION_MODEL',
    MODEL_VERSION       VARCHAR(20) DEFAULT 'V1',
    PREDICTION          INTEGER,
    FRAUD_PROBABILITY   FLOAT,
    ROUTING_DECISION    VARCHAR(30),
    SCORED_AT           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

--------------------------------------------------------------------
-- 6. Score pending applications using the registered model
--------------------------------------------------------------------
CREATE OR REPLACE TABLE FRAUD_SCORES AS
WITH pending_features AS (
    SELECT *
    FROM FRAUD_TRAINING_DATA
    WHERE APPLICATION_ID IN (
        SELECT APPLICATION_ID
        FROM SOURCE_DATA.LOAN_APPLICATIONS
        WHERE APPLICATION_STATUS = 'PENDING'
    )
)
SELECT
    APPLICATION_ID,
    FRAUD_DETECTION_MODEL!PREDICT(
        LOAN_AMOUNT, LOAN_TERM_MONTHS, INTEREST_RATE, CREDIT_SCORE,
        YEARS_IN_BUSINESS, ANNUAL_REVENUE, EMPLOYEE_COUNT, EXISTING_DEBT,
        COLLATERAL_VALUE, LOAN_TO_REVENUE_RATIO, DEBT_TO_REVENUE_RATIO,
        COLLATERAL_COVERAGE_RATIO, IS_RETAIL, IS_RESTAURANT, IS_CONSTRUCTION,
        IS_HEALTHCARE, IS_TECHNOLOGY, IS_ONLINE_CHANNEL, IS_BROKER_CHANNEL,
        IS_UNSECURED, IS_HIGH_RISK
    ) AS PREDICTION_RESULT
FROM pending_features;

--------------------------------------------------------------------
-- 7. Route predictions (threshold = 0.6)
--------------------------------------------------------------------

-- Auto-approve low risk
INSERT INTO AUTO_APPROVED (APPLICATION_ID, FRAUD_PROBABILITY, PREDICTION, SCORED_AT)
SELECT
    APPLICATION_ID,
    PREDICTION_RESULT['predict_proba_1']::FLOAT AS FRAUD_PROBABILITY,
    PREDICTION_RESULT['output_feature_0']::INTEGER AS PREDICTION,
    CURRENT_TIMESTAMP()
FROM FRAUD_SCORES
WHERE PREDICTION_RESULT['predict_proba_1']::FLOAT < 0.6;

-- Flag high risk for review
INSERT INTO FLAGGED_FOR_REVIEW (APPLICATION_ID, FRAUD_PROBABILITY, PREDICTION, RISK_TIER, LOAN_AMOUNT, BUSINESS_NAME, INDUSTRY, SCORED_AT)
SELECT
    fs.APPLICATION_ID,
    fs.PREDICTION_RESULT['predict_proba_1']::FLOAT AS FRAUD_PROBABILITY,
    fs.PREDICTION_RESULT['output_feature_0']::INTEGER AS PREDICTION,
    m.RISK_TIER,
    m.LOAN_AMOUNT,
    m.BUSINESS_NAME,
    m.INDUSTRY,
    CURRENT_TIMESTAMP()
FROM FRAUD_SCORES fs
JOIN LOAN_ANALYTICS_MART m ON fs.APPLICATION_ID = m.APPLICATION_ID
WHERE fs.PREDICTION_RESULT['predict_proba_1']::FLOAT >= 0.6;

-- Audit log (all predictions)
INSERT INTO PREDICTION_AUDIT_LOG (APPLICATION_ID, PREDICTION, FRAUD_PROBABILITY, ROUTING_DECISION, SCORED_AT)
SELECT
    APPLICATION_ID,
    PREDICTION_RESULT['output_feature_0']::INTEGER,
    PREDICTION_RESULT['predict_proba_1']::FLOAT,
    CASE
        WHEN PREDICTION_RESULT['predict_proba_1']::FLOAT >= 0.6 THEN 'FLAGGED_FOR_REVIEW'
        ELSE 'AUTO_APPROVED'
    END,
    CURRENT_TIMESTAMP()
FROM FRAUD_SCORES;

--------------------------------------------------------------------
-- 8. Verify results
--------------------------------------------------------------------
SELECT 'AUTO_APPROVED' AS TABLE_NAME, COUNT(*) AS CNT FROM AUTO_APPROVED
UNION ALL
SELECT 'FLAGGED_FOR_REVIEW', COUNT(*) FROM FLAGGED_FOR_REVIEW
UNION ALL
SELECT 'PREDICTION_AUDIT_LOG', COUNT(*) FROM PREDICTION_AUDIT_LOG;
