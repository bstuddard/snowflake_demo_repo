USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- Create Qlik User and Role for Snowflake Connection
-- ============================================================================
-- This script creates a dedicated user and role for Qlik to connect to Snowflake
-- 
-- Prerequisites:
--   - Run as ACCOUNTADMIN role
--   - Decide on password (will be set below or via ALTER USER after creation)
--   - Determine which databases/schemas Qlik needs access to
--
-- Post-creation steps:
--   1. Set password: ALTER USER qlik_user SET PASSWORD = 'your_secure_password';
--   2. This user is marked as a service account (TYPE = 'legacy_service') which automatically
--      excludes it from MFA policies (Snowflake 8.27+ feature)
--   3. Test connection from Qlik using the new user credentials
--
-- Service Account Type:
--   This user is marked as TYPE = 'legacy_service' because Qlik uses username/password authentication.
--   Service accounts are automatically excluded from mandatory MFA policies, so no override policy
--   is needed. This is the recommended approach (Snowflake 8.27+).
--
--   If using key-pair authentication instead, use TYPE = 'service':
--   ALTER USER qlik_user SET TYPE = 'service';
-- ============================================================================

-- Create dedicated role for Qlik
CREATE ROLE IF NOT EXISTS qlik_role;

-- Create user for Qlik connection
-- Note: Password should be set separately for security (see ALTER USER below)
CREATE USER IF NOT EXISTS qlik_user
  PASSWORD = ''  -- TODO: Set password via ALTER USER after creation
  DEFAULT_ROLE = qlik_role
  DEFAULT_WAREHOUSE = COMPUTE_WH  -- TODO: Adjust warehouse name if different
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT = 'User account for Qlik Sense/QlikView connection to Snowflake';

-- Grant role to user
GRANT ROLE qlik_role TO USER qlik_user;

-- Set default role for user
ALTER USER qlik_user SET DEFAULT_ROLE = qlik_role;

-- Mark user as service account to automatically exclude from MFA policies
-- TYPE = 'legacy_service' for username/password authentication (Qlik uses USR+PWD)
-- TYPE = 'service' for key-pair or other non-password authentication methods
-- This is the recommended approach (Snowflake 8.27+) - no need for MFA override policies
ALTER USER qlik_user SET TYPE = 'legacy_service';

-- Grant usage on warehouse (adjust warehouse name as needed)
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE qlik_role;  -- TODO: Adjust warehouse name

-- Grant usage on database(s) that Qlik needs to access
-- TODO: Adjust database names based on your requirements
GRANT USAGE ON DATABASE learning_db TO ROLE qlik_role;

-- Grant usage on schema(s) within the database
-- TODO: Adjust schema names based on your requirements
GRANT USAGE ON SCHEMA learning_db.dw TO ROLE qlik_role;

-- Grant SELECT on all existing tables in schemas (read-only access)
-- TODO: Adjust based on which schemas/tables Qlik needs to read
GRANT SELECT ON ALL TABLES IN SCHEMA learning_db.dw TO ROLE qlik_role;

-- Grant SELECT on all existing views in schemas
GRANT SELECT ON ALL VIEWS IN SCHEMA learning_db.dw TO ROLE qlik_role;

-- Grant future privileges (for tables/views created after this script runs)
-- This ensures Qlik maintains access to new objects
GRANT SELECT ON FUTURE TABLES IN SCHEMA learning_db.dw TO ROLE qlik_role;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA learning_db.dw TO ROLE qlik_role;

-- ============================================================================
-- Verification Queries
-- ============================================================================

-- Verify user was created
SHOW USERS LIKE 'qlik_user';

-- Verify role was created
SHOW ROLES LIKE 'qlik_role';

-- Show grants to qlik_role
SHOW GRANTS TO ROLE qlik_role;

-- Show grants to user
SHOW GRANTS TO USER qlik_user;

-- Verify user type is set to service account
SELECT 
    name AS username,
    type AS user_type,
    has_password,
    has_rsa_public_key,
    mfa_policy,
    mfa_methods
FROM TABLE(INFORMATION_SCHEMA.USERS())
WHERE name = 'qlik_user';

-- ============================================================================
-- Post-Creation Steps
-- ============================================================================
-- 
-- 1. Set the password for the user:
--    ALTER USER qlik_user SET PASSWORD = 'your_secure_password_here';
--
-- 2. Test the connection from Qlik using:
--    - Account: <your_account_identifier>
--    - User: qlik_user
--    - Password: <the_password_you_set>
--    - Warehouse: COMPUTE_WH (or your specified warehouse)
--    - Database: learning_db (or your specified database)
--    - Schema: public (or your specified schema)
--
-- 3. If you need to grant access to additional databases/schemas:
--    GRANT USAGE ON DATABASE <database_name> TO ROLE qlik_role;
--    GRANT USAGE ON SCHEMA <database_name>.<schema_name> TO ROLE qlik_role;
--    GRANT SELECT ON ALL TABLES IN SCHEMA <database_name>.<schema_name> TO ROLE qlik_role;
--    GRANT SELECT ON FUTURE TABLES IN SCHEMA <database_name>.<schema_name> TO ROLE qlik_role;
--
-- 4. If you need to revoke access later:
--    REVOKE SELECT ON ALL TABLES IN SCHEMA <database_name>.<schema_name> FROM ROLE qlik_role;
--    REVOKE USAGE ON SCHEMA <database_name>.<schema_name> FROM ROLE qlik_role;
--    REVOKE USAGE ON DATABASE <database_name> FROM ROLE qlik_role;
--
-- ============================================================================
-- Service Account Type Reference
-- ============================================================================
-- 
-- Service accounts (TYPE = 'service' or 'legacy_service') are automatically excluded
-- from mandatory MFA policies. This eliminates the need for override policies.
--
-- TYPE values:
--   - 'legacy_service': For service accounts using username/password authentication
--   - 'service': For service accounts using key-pair or other non-password auth
--
-- If you have an account-level MFA policy enabled:
--   CREATE AUTHENTICATION POLICY mfa_enforcement_policy
--     MFA_ENROLLMENT = 'REQUIRED'
--     MFA_AUTHENTICATION_METHODS = ('PASSWORD');
--   ALTER ACCOUNT SET AUTHENTICATION POLICY mfa_enforcement_policy;
--
-- Service accounts will automatically be excluded from this policy - no override needed!
--
-- Documentation:
--   - Authentication Policies: https://docs.snowflake.com/en/user-guide/authentication-policies
--   - User TYPE property: https://docs.snowflake.com/en/sql-reference/sql/create-user#label-user-type-property
--
-- ============================================================================

