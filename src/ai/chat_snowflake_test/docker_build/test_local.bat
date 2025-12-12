@echo off

set IMAGE_NAME=chat_snowflake_demo_local
set TAG=latest
set PORT=8501

echo Building local Docker image: %IMAGE_NAME%:%TAG%
docker build --rm --platform linux/amd64 -t "%IMAGE_NAME%:%TAG%" .
if errorlevel 1 (
    echo [ERROR] Docker build failed!
    exit /b 1
)

echo.
echo Starting container...
echo Streamlit app will be available at: http://localhost:%PORT%
echo Press Ctrl+C to stop the container
echo.

REM Check if .env file exists and use it
if exist ".env" (
    echo Using .env file for environment variables
    set "ENV_ARGS=--env-file .env"

    REM Mount the docker_build folder (where this script is located)
    set "VOLUME_ARGS=-v "%CD%\docker_build:/docker_build""
) else (
    echo [ERROR] No .env file found! Please create a .env file with your Snowflake credentials.
    exit /b 1
)

docker run --rm -p %PORT%:8501 %VOLUME_ARGS% %ENV_ARGS% "%IMAGE_NAME%:%TAG%"
if errorlevel 1 (
    echo [ERROR] Docker run failed!
    exit /b 1
)

