/*
    Kapitus × Snowflake Cortex Code Hands-On Lab
    Step 7: Cortex Agent
    
    Created in YOUR schema. Uses YAML specification syntax.
    NOTE: Uses claude-sonnet-4-5 (check available models on your account).
    Agent requires warehouse — set execution_warehouse in tool_resources
    or ensure the calling user has a default warehouse.
*/

USE DATABASE KAPITUS_TRAINING;
USE SCHEMA TRAINING_LUKE;  -- Replace with your schema (TRAINING_<USERNAME>)
USE WAREHOUSE KAPITUS_TRAINING_WH;

CREATE OR REPLACE AGENT LOAN_ANALYTICS_AGENT
COMMENT = 'Loan analytics agent for Kapitus lab'
FROM SPECIFICATION
$$
models:
  orchestration: claude-sonnet-4-5

instructions:
  system: "You are a loan analytics assistant for Kapitus, a commercial lending company. You help underwriters, analysts, and managers understand loan application data. Always provide specific numbers, format currency with $ and commas, express percentages to 1 decimal place, and be concise."

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "LoanAnalyst"
      description: "Analyzes loan application data including volumes, fraud rates, approval rates, and borrower details"

tool_resources:
  LoanAnalyst:
    semantic_view: "KAPITUS_TRAINING.TRAINING_LUKE.LOAN_ANALYTICS_SV"
    warehouse: "KAPITUS_TRAINING_WH"
$$;

-- Query the agent:
-- SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
--     'KAPITUS_TRAINING.TRAINING_LUKE.LOAN_ANALYTICS_AGENT',
--     '{"messages":[{"role":"user","content":[{"type":"text","text":"What is the total loan volume by industry?"}]}]}'
-- );
--
-- NOTE: If you get a warehouse error, test the agent in Snowsight's Agent UI instead.
-- Navigate to: AI & ML > Cortex Agents > LOAN_ANALYTICS_AGENT > Try it
