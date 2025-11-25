USE DATABASE LEARNING_DB;
USE SCHEMA ETL;

CREATE OR REPLACE API INTEGRATION git_clone_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/my-account')
  ALLOWED_AUTHENTICATION_SECRETS = (git_clone_token_secret)
  ENABLED = TRUE;