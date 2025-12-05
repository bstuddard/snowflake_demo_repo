USE DATABASE LEARNING_DB;
USE SCHEMA ETL;

CREATE OR REPLACE GIT REPOSITORY git_clone_repo
  API_INTEGRATION = git_clone_api_integration
  GIT_CREDENTIALS = git_clone_token_secret
  ORIGIN = 'https://github.com/my-account/snowflake_demo_repo.git';