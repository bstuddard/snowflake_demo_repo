USE ROLE ACCOUNTADMIN;
USE DATABASE learning_db;
USE SCHEMA ai;
USE WAREHOUSE container_warehouse;

-- =============================================================================
-- IMPORTANT: Push Docker image first!
-- =============================================================================
-- Before running this script, ensure your Docker image has been built and 
-- pushed to the Snowflake image repository:
--
--   1. Run: src/ai/echo_demo/build_and_push.bat
--   2. Verify image exists: SHOW IMAGES IN SCHEMA ai;
--
-- =============================================================================

-- Create Echo Service with web endpoints
-- This service exposes HTTP endpoints and includes health checks
CREATE OR REPLACE SERVICE echo_service
  IN COMPUTE POOL container_compute_pool
  FROM SPECIFICATION $$
    spec:
      containers:
      - name: echo
        image: /learning_db/ai/container_repository/my_job_image:latest
        env:
          SERVER_PORT: 8000
          CHARACTER_NAME: Bob
        readinessProbe:
          port: 8000
          path: /healthcheck
      endpoints:
      - name: echoendpoint
        port: 8000
        public: true
      $$
  MIN_INSTANCES=1
  MAX_INSTANCES=1;

-- Verify service was created
SHOW SERVICES LIKE 'echo_service' IN SCHEMA ai;

-- View service status
DESCRIBE SERVICE echo_service;

