USE DATABASE LEARNING_DB;
USE SCHEMA ETL;

CREATE OR REPLACE SECRET git_clone_token_secret
  TYPE = password
  USERNAME = 'github_username'
  PASSWORD = 'github_token';


SHOW SECRETS;
DESCRIBE SECRET git_clone_token_secret;