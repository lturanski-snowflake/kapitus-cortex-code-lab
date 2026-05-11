# Cortex Code Hands-On Lab — Prompt Guide

**Kapitus × Snowflake** | Copy-paste these prompts into Cortex Code as you go.

---

## Module 0: Setup

### 0.1 — Set Context

Run this SQL directly (replace `<USERNAME>` with your Snowflake username):

```sql
USE ROLE KAPITUS_TRAINING_ROLE;
USE DATABASE KAPITUS_TRAINING;
USE SCHEMA TRAINING_<USERNAME>;
USE WAREHOUSE KAPITUS_TRAINING_WH;
```

### 0.2 — Load Skills

Upload the `.cortex/skills/` folder to your Cortex Code session:
- **VS Code CLI:** Skills auto-discover from `.cortex/skills/` when repo is open
- **Snowsight:** Click the attach/upload button and add the skill files

### 0.3 — Pre-Flight Check

Run this to confirm everything is working:

```sql
SELECT 'SOURCE_DATA' AS SCHEMA_NAME, COUNT(*) AS TABLE_COUNT
FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'SOURCE_DATA'
UNION ALL
SELECT CURRENT_SCHEMA(), COUNT(*)
FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = CURRENT_SCHEMA();
```

You should see SOURCE_DATA with 4 tables. Your schema may have 0 tables (that's fine — you'll build them).

---

## Module 1: Data Mart (Dynamic Table)

### 1.1 — Explore Source Data

```
Show me all tables in the SOURCE_DATA schema with row counts, and describe 
SOURCE_DATA.LOAN_APPLICATIONS so I can see the columns.
```

### 1.2 — Understand Relationships

```
Show me 5 sample rows from each source table: SOURCE_DATA.LOAN_APPLICATIONS, 
SOURCE_DATA.BORROWERS, SOURCE_DATA.LOAN_DECISIONS, SOURCE_DATA.PAYMENT_HISTORY. 
Explain the join keys between them.
```

### 1.3 — Create the Dynamic Table

```
Use skill .cortex/skills/kapitus-context/SKILL.md. Create a Dynamic Table called LOAN_ANALYTICS_MART in my current 
schema that refreshes every 1 hour using KAPITUS_TRAINING_WH.

It should READ from SOURCE_DATA schema tables:

1. Start from SOURCE_DATA.LOAN_APPLICATIONS as the base
2. LEFT JOIN SOURCE_DATA.BORROWERS on BORROWER_ID
3. LEFT JOIN SOURCE_DATA.LOAN_DECISIONS on APPLICATION_ID — but deduplicate 
   first using QUALIFY ROW_NUMBER() OVER (PARTITION BY APPLICATION_ID 
   ORDER BY DECISION_DATE DESC) = 1 to keep only the latest decision per app
4. LEFT JOIN an aggregation of SOURCE_DATA.PAYMENT_HISTORY by APPLICATION_ID:
   - Total payment count
   - Total amount paid
   - Average days late
   - Count of late payments (days_late > 0)
   - Most recent remaining balance (MAX_BY)

5. Add calculated columns:
   - LOAN_TO_REVENUE_RATIO (loan_amount / annual_revenue)
   - DEBT_TO_REVENUE_RATIO (existing_debt / annual_revenue)  
   - COLLATERAL_COVERAGE_RATIO (collateral_value / loan_amount)

Use COALESCE for payment aggregates (default 0), NULLIF to avoid division by zero.
```

### 1.4 — Validate

```
Query my LOAN_ANALYTICS_MART to show: total row count (should be ~20,000), 
average loan amount by industry, and fraud rate by risk tier.
```

---

## Module 2: ML Fraud Detection

### 2.1 — Create Feature View

```
Use skill .cortex/skills/ml-fraud-pipeline/SKILL.md. Create a view called FRAUD_TRAINING_DATA in my schema from 
my LOAN_ANALYTICS_MART with all numeric features and one-hot encoded categoricals 
as described in the skill. Filter out null LOAN_AMOUNT and CREDIT_SCORE rows.
```

### 2.2 — Create Training Stored Procedure

```
Use skill .cortex/skills/ml-fraud-pipeline/SKILL.md. Create a stored procedure called TRAIN_FRAUD_MODEL that:
- Reads FRAUD_TRAINING_DATA into pandas (excluding APPLICATION_ID from features)
- Splits 75/25 stratified train/test
- Trains XGBClassifier (n_estimators=100, max_depth=6, learning_rate=0.1)
- Evaluates F1, precision, recall on test set
- Registers to Model Registry as FRAUD_DETECTION_MODEL version V1 using 
  snowflake.ml.registry.Registry.log_model() with sample_input_data
- CRITICAL: Use target_platforms=['WAREHOUSE'] so the model can be called via SQL
- CRITICAL: Enable predict_proba method so we get probability output (not just class).
  Use options={'method_options': {'predict_proba': {'case_sensitive': False}}}
- Pass database_name and schema_name explicitly to Registry() constructor
- Returns metrics string

Use LANGUAGE PYTHON, RUNTIME_VERSION='3.10', 
PACKAGES=('snowflake-snowpark-python','snowflake-ml-python','xgboost','scikit-learn')
```

### 2.2b — (Alternative) Notebook Path

If you prefer a notebook approach instead of a sproc:

```
Use skill .cortex/skills/ml-fraud-pipeline/SKILL.md. Create a Snowflake Notebook that trains the fraud detection 
model. It should have cells for:
1. Import libraries and get active session
2. Load FRAUD_TRAINING_DATA into pandas
3. Split train/test and train XGBClassifier
4. Evaluate and print metrics
5. Register model to Model Registry as FRAUD_DETECTION_MODEL V1
```

### 2.3 — Train the Model

Run directly:
```sql
CALL TRAIN_FRAUD_MODEL();
```
> ⏱️ Takes 1-2 minutes. Verify with: `SHOW MODELS;`

### 2.4 — Insert New Applications to Score

```
Use skill .cortex/skills/kapitus-context/SKILL.md. Insert 50 new PENDING loan applications into 
SOURCE_DATA.LOAN_APPLICATIONS with realistic random data (various industries, 
loan amounts $10K-$1M, mix of risk tiers and channels). Use APPLICATION_IDs 
starting with 'NEW-'. Then refresh my LOAN_ANALYTICS_MART so they appear in 
the mart.
```

Or run `sql/04b_insert_new_applications.sql` directly.

### 2.5 — Create Output Tables

```
Use skill .cortex/skills/ml-fraud-pipeline/SKILL.md. Create AUTO_APPROVED, FLAGGED_FOR_REVIEW (with review workflow 
columns), and PREDICTION_AUDIT_LOG (with UUID audit ID) in my schema.
```

### 2.6 — Score and Route

```
Use skill .cortex/skills/ml-fraud-pipeline/SKILL.md. Score all PENDING applications (APPLICATION_ID LIKE 'NEW-%') 
using FRAUD_DETECTION_MODEL!PREDICT_PROBA(). Pass feature columns positionally. 
Store in FRAUD_SCORES table.

Then route: probability < 0.6 → AUTO_APPROVED, >= 0.6 → FLAGGED_FOR_REVIEW 
(join mart for business details). Log all to PREDICTION_AUDIT_LOG.

Parse results with bracket notation: 
PREDICTION_RESULT['output_feature_1']::FLOAT for fraud probability.

Show me final counts.
```

---

## Module 3: Streamlit Review App

### 3.1 — Create the App

```
Use skill .cortex/skills/kapitus-context/SKILL.md. Create a Streamlit in Snowflake app for reviewing flagged loans.

IMPORTANT: Use fully qualified table names because Streamlit runtime does NOT 
inherit USE SCHEMA. Dynamically build the FQ prefix using:
  session.sql("SELECT CURRENT_DATABASE()").collect()[0][0]
  session.sql("SELECT CURRENT_SCHEMA()").collect()[0][0]

The app should have two tabs:

**Tab 1: "Pending Review"**
- Query FLAGGED_FOR_REVIEW (fully qualified) where REVIEW_STATUS = 'PENDING'
- For each app show: Loan Amount, Fraud Score %, Risk Tier, Industry
- Add a "Risk Factors" section listing concerns (high fraud score, high risk tier, 
  large loan amount >$500K, unsecured collateral)
- Approve/Decline buttons (use f"approve_{APPLICATION_ID}_{idx}" for unique keys 
  since there may be duplicate APPLICATION_IDs)
- UPDATE with CURRENT_USER() and CURRENT_TIMESTAMP() on click, then st.rerun()

**Tab 2: "Review History"**
- Show completed reviews with metrics (total, approved, declined)

Use get_active_session(). Page title "Loan Review Dashboard", wide layout.
```

### 3.2 — Deploy the App

**In Snowsight Workspaces:**
1. Create a new Streamlit file in your workspace
2. **Before deploying:** Set your execution context (top-right dropdown) to:
   - Role: `KAPITUS_TRAINING_ROLE`
   - Warehouse: `KAPITUS_TRAINING_WH`
   - Database: `KAPITUS_TRAINING`
   - Schema: `TRAINING_<USERNAME>`
3. Paste the code and click Run/Deploy

**Or via SQL:**
```sql
CREATE OR REPLACE STREAMLIT KAPITUS_TRAINING.TRAINING_<USERNAME>.LOAN_REVIEW_DASHBOARD
    ROOT_LOCATION = '@KAPITUS_TRAINING.TRAINING_<USERNAME>.STREAMLIT_STAGE/loan_review'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = 'KAPITUS_TRAINING_WH';
```

### 3.3 — Test

Open the app, verify flagged applications appear, approve/decline a few.

---

## Module 4: Semantic View + Agent

### 4.1 — Create Semantic View

```
Use skill .cortex/skills/kapitus-context/SKILL.md. Create a Semantic View called LOAN_ANALYTICS_SV in my schema 
over my LOAN_ANALYTICS_MART.

Include key columns with labels/descriptions. Define metrics: TOTAL_LOAN_VOLUME 
(SUM loan_amount), AVERAGE_LOAN_AMOUNT, APPLICATION_COUNT, FRAUD_RATE 
(AVG of IS_FRAUDULENT as float), AVERAGE_CREDIT_SCORE, APPROVAL_RATE, 
AVERAGE_PROCESSING_TIME, TOTAL_APPROVED_AMOUNT.

Filters: INDUSTRY, STATE, RISK_TIER, LOAN_PURPOSE, SUBMITTED_CHANNEL.
```

### 4.2 — Create Cortex Agent

Replace `TRAINING_LUKE` below with your actual schema name:

```
Use skill .cortex/skills/kapitus-context/SKILL.md. Create a Cortex Agent called LOAN_ANALYTICS_AGENT in my schema.
Use claude-3-5-sonnet. Add an ANALYST_TOOL pointing to 
KAPITUS_TRAINING.TRAINING_LUKE.LOAN_ANALYTICS_SV (my semantic view).
System prompt: "You are a loan analytics assistant for Kapitus. Provide specific 
numbers, format currency with $ and commas, percentages to 1 decimal."
```

### 4.3 — Test the Agent

```
Query my LOAN_ANALYTICS_AGENT: What is the total loan volume by industry?
```

```
Query my LOAN_ANALYTICS_AGENT: Which state has the highest fraud rate?
```

```
Query my LOAN_ANALYTICS_AGENT: Show approval rates by submission channel.
```

---

## Teardown (Optional)

Uncomment and run what you want to clean up:

```sql
-- DROP AGENT IF EXISTS LOAN_ANALYTICS_AGENT;
-- DROP SEMANTIC VIEW IF EXISTS LOAN_ANALYTICS_SV;
-- DROP STREAMLIT IF EXISTS LOAN_REVIEW_DASHBOARD;
-- DROP TABLE IF EXISTS FRAUD_SCORES;
-- DROP TABLE IF EXISTS AUTO_APPROVED;
-- DROP TABLE IF EXISTS FLAGGED_FOR_REVIEW;
-- DROP TABLE IF EXISTS PREDICTION_AUDIT_LOG;
-- DROP MODEL IF EXISTS FRAUD_DETECTION_MODEL;
-- DROP PROCEDURE IF EXISTS TRAIN_FRAUD_MODEL();
-- DROP VIEW IF EXISTS FRAUD_TRAINING_DATA;
-- DROP DYNAMIC TABLE IF EXISTS LOAN_ANALYTICS_MART;
-- DROP STAGE IF EXISTS STREAMLIT_STAGE;
```
