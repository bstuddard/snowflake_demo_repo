@echo off

REM Prompt for Snowflake account if not already set
if "%SNOWFLAKE_ACCOUNT%"=="" (
    set /p SNOWFLAKE_ACCOUNT="Enter Snowflake Account: "
    if "%SNOWFLAKE_ACCOUNT%"=="" (
        echo [ERROR] Snowflake Account is required!
        exit /b 1
    )
)

REM Prompt for private key passphrase if not already set
if "%PRIVATE_KEY_PASSPHRASE%"=="" (
    set /p PRIVATE_KEY_PASSPHRASE="Enter Private Key Passphrase: "
    if "%PRIVATE_KEY_PASSPHRASE%"=="" (
        echo [WARNING] Private Key Passphrase is empty. Continuing anyway...
    )
)

set DATABASE=learning_db
set SCHEMA=ai
set REPOSITORY=container_repository
set IMAGE_NAME=chat_snowflake_demo
set TAG=latest

set REGISTRY_URL=%SNOWFLAKE_ACCOUNT%.registry.snowflakecomputing.com
set IMAGE_URL=%REGISTRY_URL%/%DATABASE%/%SCHEMA%/%REPOSITORY%/%IMAGE_NAME%:%TAG%

echo Building fresh image for Snowflake deployment: %IMAGE_URL%
docker build --rm --platform linux/amd64 -t "%IMAGE_URL%" .
if errorlevel 1 exit /b 1

echo Logging into Snowflake registry...
snow spcs image-registry login
if errorlevel 1 exit /b 1

echo Pushing image to Snowflake...
docker push "%IMAGE_URL%"
if errorlevel 1 exit /b 1

echo [OK] Success! Image available at: %IMAGE_URL%

