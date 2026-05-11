---
name: kapitus-context
title: Kapitus Lab Context
summary: Sets company context, environment, and table schemas for the Kapitus Cortex Code lab.
description: >-
  Use for ALL prompts during the Kapitus hands-on lab. Provides company context,
  Snowflake environment details, table schemas, and coding conventions.
  Triggers: kapitus, loan, application, borrower, training, lab, hands-on.
  Do NOT use for general Snowflake questions unrelated to this lab.
tools:
  - snowflake_sql_execute
  - snowflake_object_search
prompt: "$kapitus-context Explore the loan applications table and describe the schema"
language: en
status: Published
author: Luke Turanski
type: snowflake
---

# Kapitus Lab Context

## When to Use
- Any prompt during the Kapitus Cortex Code hands-on lab
- Working with KAPITUS_TRAINING database objects
- Building on loan application, borrower, decision, or payment data

## What This Skill Provides
Company context, environment configuration, table schemas, and coding conventions for the Kapitus × Snowflake hands-on lab.

# Instructions

## Company Context

Kapitus is a financial services company providing working capital and financing solutions for small businesses. Products include Business Loans, Lines of Credit, Equipment Financing, Revenue-Based Financing, Purchase Order Financing, SBA Loans, Invoice Factoring, and Helix® Healthcare Financing.

Their KapitusPLUS application process allows business owners to fill out one application and receive up to six competing offers from an extensive financing network.

## Environment

**Always use these settings:**
- **Role:** KAPITUS_TRAINING_ROLE
- **Database:** KAPITUS_TRAINING
- **Schema:** Your personal schema (e.g., TRAINING_LUKE)
- **Warehouse:** KAPITUS_TRAINING_WH

**CRITICAL: Always execute `USE ROLE KAPITUS_TRAINING_ROLE` before creating ANY objects.
Never create objects as ACCOUNTADMIN. All Dynamic Tables, views, models, agents, 
Streamlit apps, stages, and procedures MUST be owned by KAPITUS_TRAINING_ROLE.
If the session is using a different role, switch first.**

## IMPORTANT: Schema Layout

**Source data** lives in a shared read-only schema:
- `KAPITUS_TRAINING.SOURCE_DATA` — contains the 4 source tables

**Your working schema** is where ALL objects you create go:
- `KAPITUS_TRAINING.TRAINING_<USERNAME>` — your personal schema (Dynamic Tables, models, views, Streamlit apps, stages, etc.)

**When reading source tables**, always reference them with the schema prefix:
- `SOURCE_DATA.LOAN_APPLICATIONS`
- `SOURCE_DATA.BORROWERS`
- `SOURCE_DATA.LOAN_DECISIONS`
- `SOURCE_DATA.PAYMENT_HISTORY`

**When creating objects**, create them in your current schema (no prefix needed since USE SCHEMA is set to your attendee schema).

## Source Tables (in SOURCE_DATA schema)

| Table | Full Reference | ~Rows |
|-------|---------------|-------|
| LOAN_APPLICATIONS | `SOURCE_DATA.LOAN_APPLICATIONS` | 20,000 |
| BORROWERS | `SOURCE_DATA.BORROWERS` | 5,000 |
| LOAN_DECISIONS | `SOURCE_DATA.LOAN_DECISIONS` | 15,000 |
| PAYMENT_HISTORY | `SOURCE_DATA.PAYMENT_HISTORY` | 50,000 |

### Key Columns — LOAN_APPLICATIONS
APPLICATION_ID (PK), BORROWER_ID (FK), APPLICATION_DATE, LOAN_AMOUNT, LOAN_PURPOSE (Working Capital | Equipment Purchase | Expansion | Inventory | Debt Consolidation | Real Estate), LOAN_TERM_MONTHS, INTEREST_RATE, COLLATERAL_TYPE (Real Estate | Equipment | Accounts Receivable | Unsecured), COLLATERAL_VALUE, APPLICATION_STATUS (PENDING | APPROVED | DECLINED | UNDER_REVIEW), RISK_TIER (HIGH | MEDIUM | LOW), SUBMITTED_CHANNEL (Online | Broker | Direct), IS_FRAUDULENT (BOOLEAN)

### Key Columns — BORROWERS
BORROWER_ID (PK), BUSINESS_NAME, INDUSTRY (Retail | Restaurant | Construction | Healthcare | Transportation | Technology | Manufacturing | Professional Services), STATE (2-letter), YEARS_IN_BUSINESS, ANNUAL_REVENUE, EMPLOYEE_COUNT, CREDIT_SCORE (500-850), EXISTING_DEBT

### Key Columns — LOAN_DECISIONS
DECISION_ID (PK), APPLICATION_ID (FK), DECISION_DATE, DECISION (APPROVED | DECLINED | CONDITIONAL), UNDERWRITER_ID, DECISION_REASON, APPROVED_AMOUNT, PROCESSING_TIME_HRS

### Key Columns — PAYMENT_HISTORY
PAYMENT_ID (PK), APPLICATION_ID (FK), PAYMENT_DATE, PAYMENT_AMOUNT, PRINCIPAL_AMOUNT, INTEREST_AMOUNT, REMAINING_BALANCE, DAYS_LATE, PAYMENT_STATUS (ON_TIME | LATE | MISSED)

### Relationships
- LOAN_APPLICATIONS.BORROWER_ID → BORROWERS.BORROWER_ID
- LOAN_DECISIONS.APPLICATION_ID → LOAN_APPLICATIONS.APPLICATION_ID
- PAYMENT_HISTORY.APPLICATION_ID → LOAN_APPLICATIONS.APPLICATION_ID

## Conventions

1. Your USE SCHEMA is your attendee schema (e.g., TRAINING_LUKE)
2. **READ** from source tables using `SOURCE_DATA.<table>` prefix
3. **CREATE** all objects in your current schema (no prefix — just the object name)
4. Use KAPITUS_TRAINING_WH for all compute
5. Use SQL-native approaches (Dynamic Tables, ML Classification, Semantic Views)
6. Keep code clean — this is for a hands-on lab
7. Include comments explaining each major step

**Example pattern:**
```sql
-- Your context is TRAINING_LUKE
-- Read from SOURCE_DATA, create in your schema
CREATE OR REPLACE DYNAMIC TABLE LOAN_ANALYTICS_MART ...
AS
SELECT ... FROM SOURCE_DATA.LOAN_APPLICATIONS la
LEFT JOIN SOURCE_DATA.BORROWERS b ON ...
```

## Best Practices
- Use COALESCE for nullable aggregation results
- Use NULLIF to prevent division-by-zero in ratios
- Use CREATE OR REPLACE for iterative development during the lab
- Use LEFT JOIN when joining to optional tables (decisions, payments)
- **IMPORTANT:** In Streamlit apps and stored procedures, always use fully qualified table names (e.g., `KAPITUS_TRAINING.TRAINING_LUKE.FLAGGED_FOR_REVIEW`) because these runtimes do NOT inherit USE SCHEMA context
- When deduplicating 1:many joins (e.g., LOAN_DECISIONS), use QUALIFY ROW_NUMBER() to keep only the latest record

# Examples

## Example 1: Set context
User: $kapitus-context Set up my session for the lab
Assistant: Executes USE ROLE/DATABASE/SCHEMA/WAREHOUSE statements

## Example 2: Explore data
User: $kapitus-context Show me the loan applications table structure and a sample
Assistant: Runs DESCRIBE TABLE and SELECT with LIMIT
