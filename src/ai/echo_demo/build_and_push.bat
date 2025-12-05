@echo off

if "%SNOWFLAKE_ACCOUNT%"=="" set SNOWFLAKE_ACCOUNT=your_account_here
if "%PRIVATE_KEY_PASSPHRASE%"=="" set PRIVATE_KEY_PASSPHRASE=your_passphrase_here
set DATABASE=learning_db
set SCHEMA=ai
set REPOSITORY=container_repository
set IMAGE_NAME=my_job_image
set TAG=latest

set REGISTRY_URL=%SNOWFLAKE_ACCOUNT%.registry.snowflakecomputing.com
set IMAGE_URL=%REGISTRY_URL%/%DATABASE%/%SCHEMA%/%REPOSITORY%/%IMAGE_NAME%:%TAG%

echo Building: %IMAGE_URL%
docker build --rm --platform linux/amd64 -t "%IMAGE_URL%" .
if errorlevel 1 exit /b 1

echo Logging into Snowflake registry...
snow spcs image-registry login
if errorlevel 1 exit /b 1

echo Pushing image...
docker push "%IMAGE_URL%"
if errorlevel 1 exit /b 1

echo [OK] Success! Image available at: %IMAGE_URL%

