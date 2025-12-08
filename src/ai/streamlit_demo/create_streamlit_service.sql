USE ROLE ACCOUNTADMIN;
USE DATABASE learning_db;
USE SCHEMA ai;
SHOW IMAGE REPOSITORIES IN SCHEMA ai;
SHOW IMAGES IN CONTAINER_REPOSITORY;
USE WAREHOUSE container_warehouse;

-- =============================================================================
-- IMPORTANT: Push Docker image first!
-- =============================================================================
-- Before running this script, ensure your Docker image has been built and 
-- pushed to the Snowflake image repository:
--
--   1. Run: src/ai/streamlit_demo/build_and_push.bat
--   2. Verify image exists: SHOW IMAGES IN SCHEMA ai;
--
-- =============================================================================

-- Create Streamlit Service with web endpoints
-- This service exposes HTTP endpoints for the Streamlit application
CREATE OR REPLACE SERVICE streamlit_demo_service
  IN COMPUTE POOL container_compute_pool
  FROM SPECIFICATION $$
    spec:
      containers:
      - name: streamlit
        image: /learning_db/ai/container_repository/streamlit_demo_image:latest
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
SHOW SERVICES LIKE 'streamlit_demo_service' IN SCHEMA ai;

-- View service status
DESCRIBE SERVICE streamlit_demo_service;

-- Alternative: Show endpoints for the service
SHOW ENDPOINTS IN SERVICE streamlit_demo_service;

