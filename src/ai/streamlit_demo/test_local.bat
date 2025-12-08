@echo off

set IMAGE_NAME=streamlit_demo_local
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

docker run --rm -p %PORT%:8501 "%IMAGE_NAME%:%TAG%"
if errorlevel 1 (
    echo [ERROR] Docker run failed!
    exit /b 1
)

