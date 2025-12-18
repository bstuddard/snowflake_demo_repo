-- ============================================================================
-- Review Permissions Script
-- Change the role name below and execute the entire script
-- ============================================================================

-- Set the role to review (change this value and re-run)
SET review_role = 'APP_ROLE';

-- ============================================================================
-- SECTION 1: High-level role overview
-- ============================================================================

-- List all roles in the account
SHOW ROLES;

-- Details about the target role
SHOW ROLES LIKE $review_role;

-- ============================================================================
-- SECTION 2: Role relationships
-- ============================================================================

-- Who has this role (users and parent roles that inherit it)
SHOW GRANTS OF ROLE IDENTIFIER($review_role);

-- All privileges granted TO this role (inherited roles + direct privileges)
-- Look at "granted_on" column to see object types (WAREHOUSE, DATABASE, SCHEMA, TABLE, ROLE, etc.)
SHOW GRANTS TO ROLE IDENTIFIER($review_role);

-- ============================================================================
-- SECTION 3: Future grants (auto-applied to new objects)
-- ============================================================================

SHOW FUTURE GRANTS TO ROLE IDENTIFIER($review_role);
