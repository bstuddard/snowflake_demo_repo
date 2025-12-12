USE ROLE ACCOUNTADMIN;
USE DATABASE learning_db;
USE SCHEMA ai;
SHOW IMAGE REPOSITORIES IN SCHEMA ai;
SHOW IMAGES IN IMAGE REPOSITORY container_repository;
USE WAREHOUSE container_warehouse;

-- =============================================================================
-- IMPORTANT: Push Docker image first!
-- =============================================================================
-- Before running this script, ensure your Docker image has been built and
-- pushed to the Snowflake image repository:
--
--   1. Run: src/ai/chat_snowflake_test/docker_build/build_and_push.bat
--   2. Verify image exists: SHOW IMAGES IN IMAGE REPOSITORY container_repository;
--
-- =============================================================================

-- =============================================================================
-- Environment Variables Configuration
-- =============================================================================
-- Snowflake Container Services automatically injects context variables:
-- {{ SNOWFLAKE_ACCOUNT }} - Your Snowflake account identifier
-- {{ SNOWFLAKE_HOST }} - Account host URL
-- {{ SNOWFLAKE_DATABASE }} - Current database name
-- {{ SNOWFLAKE_SCHEMA }} - Current schema name
-- {{ SNOWFLAKE_WAREHOUSE }} - Current warehouse name
-- {{ SNOWFLAKE_USER }} - Current user name
-- {{ SNOWFLAKE_ROLE }} - Current role name
--
-- Authentication: OAuth tokens are automatically provided via /snowflake/session/token
-- No key-based authentication needed in Snowflake services!
--
-- Alternative: Use Snowflake Secrets for sensitive custom data
-- CREATE OR REPLACE SECRET my_secret TYPE = GENERIC_STRING SECRET_STRING = 'value';
-- Reference in env: MY_VAR: SECRET[my_secret]
-- =============================================================================

-- Create Streamlit Service with dynamic environment variables
-- This service exposes HTTP endpoints for the Streamlit application
-- Authentication: Uses Snowflake OAuth tokens (auto-injected, no key files needed)
CREATE SERVICE chat_snowflake_demo_service
  IN COMPUTE POOL container_compute_pool
  FROM SPECIFICATION $$
    spec:
      containers:
      - name: streamlit
        image: /learning_db/ai/container_repository/chat_snowflake_demo:latest
        env:
          TEST_VAR: test
        readinessProbe:
          port: 8501
          path: /_stcore/health
      endpoints:
      - name: streamlitendpoint
        port: 8501
        public: true
      $$
  MIN_INSTANCES=1
  MAX_INSTANCES=1;

-- Verify service was created
SHOW SERVICES LIKE 'chat_snowflake_demo_service' IN SCHEMA ai;

-- View service status
DESCRIBE SERVICE chat_snowflake_demo_service;

-- Alternative: Show endpoints for the service
SHOW ENDPOINTS IN SERVICE chat_snowflake_demo_service;

