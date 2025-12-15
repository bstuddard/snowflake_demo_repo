USE ROLE ACCOUNTADMIN;
USE DATABASE learning_db;
USE SCHEMA ai;
USE WAREHOUSE container_warehouse;

-- =============================================================================
-- Cleanup Script - Stop Billing for Chat Snowflake Demo Service
-- =============================================================================
-- This script suspends/drops resources to stop charges.
-- 
-- COST DRIVERS:
--   1. Compute Pool (MAIN COST) - Billed continuously while running
--   2. Service - Runs on compute pool
--   3. Warehouse - Auto-suspends, but ensure it's suspended
--
-- NOTE: If other services (e.g., echo_service, streamlit_demo_service) are using the same compute pool
--       and warehouse, suspending them will affect those services too.
-- =============================================================================

-- Step 1: Drop the service (stops service billing)
-- =============================================================================
ALTER SERVICE chat_snowflake_demo_service SUSPEND;
DROP SERVICE IF EXISTS chat_snowflake_demo_service;

-- Step 2: Suspend the compute pool (STOPS MAIN BILLING)
-- =============================================================================
-- This is the most important step - compute pool with MIN_NODES=1 runs continuously
-- WARNING: Only suspend if no other services are using this compute pool
ALTER COMPUTE POOL CONTAINER_COMPUTE_POOL STOP ALL;
ALTER COMPUTE POOL container_compute_pool SUSPEND;

-- Step 3: Suspend the warehouse (if not already suspended)
-- =============================================================================
ALTER WAREHOUSE container_warehouse SUSPEND;

-- =============================================================================
-- OPTIONAL: Full cleanup (uncomment to drop everything)
-- =============================================================================
-- WARNING: This will delete all objects. Only use if you want complete cleanup.
-- NOTE: These resources may be shared with other services (e.g., echo_service),
--       so only use if you're cleaning up ALL container services.

-- DROP COMPUTE POOL IF EXISTS container_compute_pool;
-- DROP WAREHOUSE IF EXISTS container_warehouse;
-- DROP IMAGE REPOSITORY IF EXISTS container_repository;
-- DROP STAGE IF EXISTS container_stage;
-- DROP SCHEMA IF EXISTS ai;

-- =============================================================================
-- Verify cleanup
-- =============================================================================
SHOW SERVICES IN SCHEMA ai;
DESCRIBE COMPUTE POOL container_compute_pool;
SHOW WAREHOUSES LIKE 'container_warehouse';

