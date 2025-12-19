-- Grant usage on the database
GRANT USAGE ON DATABASE learning_db TO ROLE unit_test_role;

-- Grant full usage on the schema
GRANT USAGE ON SCHEMA learning_db.unit_test TO ROLE unit_test_role;

-- Grant ability to create objects in the schema
GRANT CREATE TABLE ON SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT CREATE VIEW ON SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT CREATE PROCEDURE ON SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT CREATE FUNCTION ON SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT CREATE SEQUENCE ON SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT CREATE STAGE ON SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT CREATE FILE FORMAT ON SCHEMA learning_db.unit_test TO ROLE unit_test_role;

-- Grant all privileges on existing objects
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT ALL PRIVILEGES ON ALL VIEWS IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;

-- Grant privileges on FUTURE objects (so new objects automatically get permissions)
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT ALL PRIVILEGES ON FUTURE VIEWS IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT USAGE ON FUTURE PROCEDURES IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;
GRANT USAGE ON FUTURE SEQUENCES IN SCHEMA learning_db.unit_test TO ROLE unit_test_role;