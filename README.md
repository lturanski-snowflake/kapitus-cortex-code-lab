# Cortex Code Hands-On Lab: AI-Powered Loan Fraud Detection

**Kapitus × Snowflake** | Duration: ~45 minutes

---

## What You'll Build

Using **Cortex Code** as your AI pair programmer, you'll build a complete fraud detection workflow:

1. **Data Mart** — Dynamic Table joining source data (auto-refreshes hourly)
2. **ML Pipeline** — XGBoost model trained via stored procedure, registered to Model Registry
3. **Scoring Engine** — SQL inference that auto-approves or flags applications
4. **Review App** — Streamlit dashboard for manual fraud review
5. **AI Agent** — Natural language querying over your loan data

---

## Prerequisites

- [x] Snowflake account access with `KAPITUS_TRAINING_ROLE` granted
- [x] Your schema already created (e.g., `TRAINING_LUKE`)
- [x] Source data loaded in `SOURCE_DATA` schema
- [x] Cortex Code available (Snowsight or VS Code CLI)

---

## Getting Started

### 1. Get the Lab Files

Choose one of these options to get the repo into your workspace:

**Option A — Connect Git repo (recommended for VS Code CLI):**
```bash
git clone https://github.com/lturanski-snowflake/kapitus-cortex-code-lab.git
cd kapitus-cortex-code-lab
cortex
```

**Option B — Connect Git repo in Snowsight:**
1. In Snowsight, go to **Projects → Git Repositories**
2. Click **+ Git Repository**
3. Paste the repo URL: `https://github.com/lturanski-snowflake/kapitus-cortex-code-lab.git`
4. Select your database/schema and create
5. Open Cortex Code from the left nav — the repo files are now accessible

**Option C — Upload folder directly in Snowsight:**
1. Download/clone this repo to your local machine
2. In Snowsight, open **Cortex Code** from the left nav
3. Click the **+** (attach) button in the chat input area
4. Select **Upload Folder** and choose the cloned `kapitus-cortex-code-lab` folder
5. All files (prompts, skills, SQL) will be available in your workspace

### 2. Open Cortex Code

- **Snowsight:** Click the Cortex Code chat icon in the left nav
- **VS Code CLI:** Run `cortex` in terminal

### 3. Set Your Context

> **IMPORTANT:** You MUST switch to `KAPITUS_TRAINING_ROLE` before starting. 
> Most attendees will NOT have `ACCOUNTADMIN`. All lab operations should run 
> entirely under the training role.

```sql
USE ROLE KAPITUS_TRAINING_ROLE;
USE DATABASE KAPITUS_TRAINING;
USE SCHEMA TRAINING_<USERNAME>;
USE WAREHOUSE KAPITUS_TRAINING_WH;
```

### 4. Load Skills

Skills teach Cortex Code your project's specifics. Reference them by local file path in your prompts:

| Skill | When to Use | File Path |
|-------|-------------|-----------|
| `kapitus-context` | Dynamic Tables, Streamlit, Agents | `.cortex/skills/kapitus-context/SKILL.md` |
| `ml-fraud-pipeline` | Model training, scoring, routing | `.cortex/skills/ml-fraud-pipeline/SKILL.md` |

**To load:**
- **VS Code CLI:** Auto-discovered from `.cortex/skills/` when repo is open
- **Snowsight:** Attach the skill `.md` file to your chat message when the prompt calls for it

### 5. Pre-Flight Check

Run the verification script to confirm all grants are in place:

```sql
-- Run sql/00_verify_grants.sql or use this quick check:
SELECT 'SOURCE_DATA' AS CHECK, COUNT(*) AS TABLES
FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'SOURCE_DATA';
```

Should return 4 tables. If any checks fail, ask your admin to re-run `sql/01_environment_setup.sql`.

---

## Lab Guide

All prompts are in **[`prompts/lab_guide.md`](prompts/lab_guide.md)** — open it and follow along.

| Module | Time | What You'll Do |
|--------|------|----------------|
| 0: Setup | 5 min | Context, skills, pre-flight |
| 1: Data Mart | 10 min | Explore data → Create Dynamic Table |
| 2: ML Pipeline | 15 min | Features → Train XGBoost → Score → Route |
| 3: Streamlit | 10 min | Build review app → Deploy → Test |
| 4: Agent | 10 min | Semantic View → Cortex Agent → Ask questions |

---

## Key Concepts

### Schema Layout
- **`SOURCE_DATA`** — Shared read-only source tables (don't modify)
- **`TRAINING_<USERNAME>`** — Your working schema (all objects created here)

### Skills
- Not every prompt needs a skill — use them when you need domain-specific code generation
- `$kapitus-context` helps with schema awareness and Snowflake patterns
- `$ml-fraud-pipeline` has exact syntax for Model Registry, PREDICT, and routing

### Fraud Routing
```
Fraud Probability < 0.6  →  AUTO_APPROVED
Fraud Probability ≥ 0.6  →  FLAGGED_FOR_REVIEW → Streamlit App → Human Decision
ALL predictions          →  PREDICTION_AUDIT_LOG
```

---

## Teardown

See the teardown section at the end of `prompts/lab_guide.md`. Everything is commented out — uncomment what you want to clean up.

---

## File Reference

```
HoL/
├── README.md                                    ← You are here
├── prompts/
│   ├── lab_guide.md                             ← All prompts (Modules 0-4)
│   └── module_prompts/                          ← Individual prompt files
│       ├── 0_setup/
│       ├── 1_data_mart/
│       ├── 2_ML_Fraud_Detection/
│       ├── 3_Streamlit_Review_App/
│       ├── 4_SemanticView_Agent/
│       └── 5_Teardown/
├── .cortex/skills/
│   ├── kapitus-context/SKILL.md                 ← $kapitus-context
│   └── ml-fraud-pipeline/SKILL.md               ← $ml-fraud-pipeline
├── sql/
│   ├── 00_verify_grants.sql                     ← Pre-flight grant checker
│   ├── 01_environment_setup.sql                 ← Admin asset (pre-lab)
│   ├── 02_sample_data.sql                       ← Admin asset (pre-lab)
│   ├── 03_dynamic_table_mart.sql                ← Reference: Module 1
│   ├── 04_ml_pipeline.sql                       ← Reference: Module 2
│   ├── 04b_insert_new_applications.sql          ← Helper: new apps to score
│   ├── 05_streamlit_app.py                      ← Reference: Module 3
│   ├── 06_semantic_view.sql                     ← Reference: Module 4
│   ├── 07_cortex_agent.sql                      ← Reference: Module 4
│   └── 08_teardown.sql                          ← Cleanup
```

---

## Resources

| Resource | Link |
|----------|------|
| Cortex Code | https://docs.snowflake.com/en/user-guide/cortex-code |
| Cortex Code Skills | https://github.com/Snowflake-Labs/cortex-code-skills |
| Dynamic Tables | https://docs.snowflake.com/en/user-guide/dynamic-tables-about |
| Model Registry | https://docs.snowflake.com/en/developer-guide/snowflake-ml/model-registry/overview |
| Streamlit in Snowflake | https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit |
| Semantic Views | https://docs.snowflake.com/en/user-guide/views-semantic |
| Cortex Agents | https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agent |

---

## Questions?

- **Luke Turanski** — luke.turanski@snowflake.com (Snowflake)
- **Andy Bouts** — abouts@phdata.io (PhData)
