-- ============================================================================
-- Remove AI/ML database roles from PUBLIC to prevent uncontrolled costs
-- Run as ACCOUNTADMIN
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- CRITICAL: Compute pools (Container Services - can run up serious costs)
-- =============================================================================

-- GPU compute pool - VERY expensive, should never be on PUBLIC
REVOKE USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_GPU FROM ROLE PUBLIC;

-- CPU compute pool - Still costly for container workloads
REVOKE USAGE ON COMPUTE POOL SYSTEM_COMPUTE_POOL_CPU FROM ROLE PUBLIC;

-- =============================================================================
-- CRITICAL: Warehouses (compute costs)
-- =============================================================================

-- Streamlit/Notebook warehouse - anyone could spin up compute
REVOKE USAGE ON WAREHOUSE SYSTEM$STREAMLIT_NOTEBOOK_WH FROM ROLE PUBLIC;

-- =============================================================================
-- HIGH PRIORITY: Generative AI (pay-per-token)
-- =============================================================================

-- CORTEX_USER: Cortex LLM functions (COMPLETE, SUMMARIZE, EXTRACT_ANSWER, etc.)
REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE PUBLIC;

-- COPILOT_USER: Snowflake Copilot (natural language to SQL)
REVOKE DATABASE ROLE SNOWFLAKE.COPILOT_USER FROM ROLE PUBLIC;

-- =============================================================================
-- MEDIUM PRIORITY: ML database role
-- =============================================================================

-- ML_USER: Classical ML (forecasting, anomaly detection)
REVOKE DATABASE ROLE SNOWFLAKE.ML_USER FROM ROLE PUBLIC;

-- =============================================================================
-- Learning role (may have additional warehouse access)
-- =============================================================================

REVOKE ROLE SNOWFLAKE_LEARNING_ROLE FROM ROLE PUBLIC;

-- =============================================================================
-- Account-level privileges
-- =============================================================================

REVOKE VIEW LINEAGE ON ACCOUNT FROM ROLE PUBLIC;

-- =============================================================================
-- Sample data (shared/imported database - requires special syntax)
-- =============================================================================

REVOKE IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA FROM ROLE PUBLIC;

-- =============================================================================
-- VERIFICATION: Check what's still granted to PUBLIC
-- =============================================================================

SHOW GRANTS TO ROLE PUBLIC;

-- =============================================================================
-- NOTE: The following CANNOT be revoked (system-managed grants):
--   - APPLICATION_ROLE SNOWFLAKE.PUBLIC
--   - DATABASE_ROLE SNOWFLAKE.ALERT_VIEWER
--   - DATABASE_ROLE SNOWFLAKE.CLASSIFICATION_VIEWER
--   - DATABASE_ROLE SNOWFLAKE.CORE_VIEWER
--   - DATABASE_ROLE SNOWFLAKE.DATA_METRIC_USER
--   - DATABASE_ROLE SNOWFLAKE.NOTIFICATION_VIEWER
--   - DATABASE_ROLE SNOWFLAKE.SPCS_REGISTRY_VIEWER
-- These are low-risk viewer/monitoring roles with no compute costs.
-- =============================================================================
