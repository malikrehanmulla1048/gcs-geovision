@echo off
title GeoVision Backend
echo ============================================
echo  GeoVision FR Backend — Starting...
echo ============================================

:: Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH.
    echo Please install Python 3.10+ from https://python.org
    pause
    exit /b 1
)

cd /d "%~dp0backend"

:: Create venv if not exists
if not exist ".venv" (
    echo Creating Python virtual environment...
    python -m venv .venv
)

:: Activate venv
call .venv\Scripts\activate.bat

:: Install / upgrade dependencies
echo Installing dependencies (first run may take a few minutes)...
pip install -q -r requirements.txt

:: Download InsightFace models if not cached
python -c "from fr_service import get_app; get_app()" 2>&1 | findstr /i "error" && (
    echo InsightFace model download complete.
)

echo.
echo ============================================
echo  Backend running at http://localhost:8000
echo  API docs at   http://localhost:8000/docs
echo  Press Ctrl+C to stop
echo ============================================
echo.

python main.py

pause
