USE ROLE ACCOUNTADMIN;

-- Create warehouse for Container Services SQL operations
-- (needed for CREATE SERVICE, ALTER SERVICE, etc.)
CREATE OR REPLACE WAREHOUSE container_warehouse
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- Create compute pool for running containers
CREATE COMPUTE POOL IF NOT EXISTS container_compute_pool
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_XS;

-- Create schema for Container Services / AI objects
-- WITH MANAGED ACCESS: Centralizes access control (recommended for production)
USE DATABASE learning_db;
USE WAREHOUSE container_warehouse;
CREATE SCHEMA IF NOT EXISTS ai
  WITH MANAGED ACCESS;
USE SCHEMA ai;

-- Create image repository for storing Docker images
-- (schema-scoped: must be created within a schema)
CREATE IMAGE REPOSITORY IF NOT EXISTS container_repository;

-- Create stage for service specs, YAML files, and other artifacts
-- (schema-scoped: must be created within a schema)
-- DIRECTORY = (ENABLE = true) allows directory listing via LIST command
CREATE STAGE IF NOT EXISTS container_stage
  DIRECTORY = (ENABLE = true);

-- Verify warehouse exists
SHOW WAREHOUSES LIKE 'container_warehouse';

-- Verify compute pool exists
DESCRIBE COMPUTE POOL container_compute_pool;

-- Verify schema and objects
SHOW IMAGE REPOSITORIES IN SCHEMA ai;
SHOW STAGES IN SCHEMA ai;
