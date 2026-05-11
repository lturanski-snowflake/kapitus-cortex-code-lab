---
name: ml-fraud-pipeline
title: ML Fraud Pipeline
summary: Guides Snowpark ML fraud detection with XGBoost, Model Registry, and SQL inference.
description: >-
  Use for ALL ML and fraud detection tasks in the Kapitus lab. Provides correct
  patterns for training XGBoost via a stored procedure, registering to Model Registry,
  calling inference via MODEL!PREDICT(), prediction parsing, and routing logic.
  Triggers: fraud, model, classification, predict, train, score, ML, machine learning,
  feature, inference, threshold, route, auto-approve, flag, audit, xgboost, registry.
  Do NOT use for Streamlit, Semantic Views, or Dynamic Tables.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
prompt: "$ml-fraud-pipeline Train a fraud detection model on my loan data"
language: en
status: Published
author: Luke Turanski
type: snowflake
---

# ML Fraud Pipeline

## When to Use
- Training an XGBoost model for fraud detection
- Creating feature engineering views
- Creating a stored procedure for model training
- Registering models to the Snowflake Model Registry
- Scoring loan applications with MODEL!PREDICT()
- Parsing prediction results
- Routing scored applications based on threshold
- Creating audit logs for model predictions

## What This Skill Provides
Patterns for: Snowpark Python stored procedure (XGBoost training + Model Registry), SQL inference via `MODEL!PREDICT()`, prediction parsing, and routing logic.

# Instructions

## Step 1: Create Training Feature View

**Actions:**
1. **Create** a VIEW called `FRAUD_TRAINING_DATA` from `LOAN_ANALYTICS_MART` (in your schema)
2. **Include** numeric features: LOAN_AMOUNT, LOAN_TERM_MONTHS, INTEREST_RATE, CREDIT_SCORE, YEARS_IN_BUSINESS, ANNUAL_REVENUE, EMPLOYEE_COUNT, EXISTING_DEBT, COLLATERAL_VALUE, LOAN_TO_REVENUE_RATIO, DEBT_TO_REVENUE_RATIO, COLLATERAL_COVERAGE_RATIO
3. **One-hot encode** categoricals as INTEGER flags: INDUSTRY (Retail, Restaurant, Construction, Healthcare, Technology), SUBMITTED_CHANNEL (Online, Broker), COLLATERAL_TYPE=Unsecured, RISK_TIER=HIGH
4. **Include** APPLICATION_ID as identifier
5. **Cast** IS_FRAUDULENT to INTEGER as target
6. **Filter** WHERE LOAN_AMOUNT IS NOT NULL AND CREDIT_SCORE IS NOT NULL

**Output:** View with ~20 feature columns + APPLICATION_ID + IS_FRAUDULENT

## Step 2: Create Training Stored Procedure

**Actions:**
1. **Create** a stored procedure `TRAIN_FRAUD_MODEL` that:
   - Reads FRAUD_TRAINING_DATA into a pandas DataFrame
   - Splits into train/test (75/25, stratified)
   - Trains XGBClassifier (n_estimators=100, max_depth=6, learning_rate=0.1)
   - Evaluates (F1, precision, recall)
   - Registers model to Snowflake Model Registry via `Registry.log_model()`
   - Sets metrics on the model version

```sql
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

    reg = Registry(session=session,
                    database_name='KAPITUS_TRAINING',
                    schema_name=session.get_current_schema())
    sample_input = X_train.head(10)

    mv = reg.log_model(
        model_name='FRAUD_DETECTION_MODEL',
        version_name='V1',
        model=model,
        sample_input_data=sample_input,
        target_platforms=['WAREHOUSE'],
        options={'method_options': {'predict_proba': {'case_sensitive': False}}},
        comment=f'XGBoost fraud detection. F1={f1}, Precision={precision}, Recall={recall}'
    )

    mv.set_metric(metric_name='test_f1', value=f1)
    mv.set_metric(metric_name='test_precision', value=precision)
    mv.set_metric(metric_name='test_recall', value=recall)

    return f'Model registered: FRAUD_DETECTION_MODEL V1 | F1={f1} | Precision={precision} | Recall={recall}'
$$;
```

**⚠️ STOPPING POINT:** Call the sproc: `CALL TRAIN_FRAUD_MODEL();` — takes 1-2 minutes.

## Step 3: Score Applications with MODEL!PREDICT_PROBA()

After the model is registered, score using SQL. Use `PREDICT_PROBA` to get probability output (not just class):

```sql
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
    FRAUD_DETECTION_MODEL!PREDICT_PROBA(
        LOAN_AMOUNT, LOAN_TERM_MONTHS, INTEREST_RATE, CREDIT_SCORE,
        YEARS_IN_BUSINESS, ANNUAL_REVENUE, EMPLOYEE_COUNT, EXISTING_DEBT,
        COLLATERAL_VALUE, LOAN_TO_REVENUE_RATIO, DEBT_TO_REVENUE_RATIO,
        COLLATERAL_COVERAGE_RATIO, IS_RETAIL, IS_RESTAURANT, IS_CONSTRUCTION,
        IS_HEALTHCARE, IS_TECHNOLOGY, IS_ONLINE_CHANNEL, IS_BROKER_CHANNEL,
        IS_UNSECURED, IS_HIGH_RISK
    ) AS PREDICTION_RESULT
FROM pending_features;
```

**Note:** `FRAUD_TRAINING_DATA` is in your schema. The pending filter references `SOURCE_DATA.LOAN_APPLICATIONS` for the original application status.

## Step 4: Parse and Route Predictions

**Parsing syntax (Model Registry XGBoost PREDICT_PROBA output):**
```sql
PREDICTION_RESULT['output_feature_0']::FLOAT    -- probability of not fraud (class 0)
PREDICTION_RESULT['output_feature_1']::FLOAT    -- probability of fraud (class 1)
```

**Routing threshold: 0.3**
- Fraud probability < 0.3 → INSERT into `AUTO_APPROVED`
- Fraud probability ≥ 0.3 → INSERT into `FLAGGED_FOR_REVIEW`
- ALL predictions → INSERT into `PREDICTION_AUDIT_LOG`

## Output Tables

### AUTO_APPROVED
```sql
CREATE OR REPLACE TABLE AUTO_APPROVED (
    APPLICATION_ID VARCHAR(20),
    FRAUD_PROBABILITY FLOAT,
    PREDICTION INTEGER,
    SCORED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

### FLAGGED_FOR_REVIEW
```sql
CREATE OR REPLACE TABLE FLAGGED_FOR_REVIEW (
    APPLICATION_ID VARCHAR(20),
    FRAUD_PROBABILITY FLOAT,
    PREDICTION INTEGER,
    RISK_TIER VARCHAR(10),
    LOAN_AMOUNT NUMBER(15,2),
    BUSINESS_NAME VARCHAR(200),
    INDUSTRY VARCHAR(100),
    SCORED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    REVIEW_STATUS VARCHAR(20) DEFAULT 'PENDING',
    REVIEWED_BY VARCHAR(100),
    REVIEW_DATE TIMESTAMP_NTZ,
    REVIEW_DECISION VARCHAR(20)
);
```

### PREDICTION_AUDIT_LOG
```sql
CREATE OR REPLACE TABLE PREDICTION_AUDIT_LOG (
    AUDIT_ID VARCHAR(40) DEFAULT UUID_STRING(),
    APPLICATION_ID VARCHAR(20),
    MODEL_NAME VARCHAR(100) DEFAULT 'FRAUD_DETECTION_MODEL',
    MODEL_VERSION VARCHAR(20) DEFAULT 'V1',
    PREDICTION INTEGER,
    FRAUD_PROBABILITY FLOAT,
    ROUTING_DECISION VARCHAR(30),
    SCORED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
```

## Best Practices
- Create a training VIEW (not table) so features stay fresh with the Dynamic Table
- Filter nulls from training data to avoid model issues
- One-hot encode categoricals explicitly for clarity
- Use a stored procedure for training — keeps everything callable from SQL
- Pass feature columns positionally to MODEL!PREDICT() (must match training order)
- Always log to audit table before routing
- Threshold 0.6 balances precision vs recall for fraud detection

## Common Errors & Fixes
| Error | Fix |
|-------|-----|
| "Model not found" | Wait for CALL to complete; verify with SHOW MODELS |
| "Column mismatch" on PREDICT | Columns passed to PREDICT must match feature order from training |
| "Permission denied" | Ensure CREATE MODEL grant on schema |
| Sproc timeout | Increase warehouse size or reduce data volume |

# Examples

## Example 1: Train model
User: $ml-fraud-pipeline Train a fraud detection model on my loan data
Assistant: Creates FRAUD_TRAINING_DATA view, creates TRAIN_FRAUD_MODEL sproc, calls it

## Example 2: Score and route
User: $ml-fraud-pipeline Score pending applications and route based on fraud risk
Assistant: Creates FRAUD_SCORES via MODEL!PREDICT, routes to AUTO_APPROVED/FLAGGED_FOR_REVIEW/PREDICTION_AUDIT_LOG
