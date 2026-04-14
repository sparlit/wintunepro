@echo off
title WinTune Pro

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo  ============================================================
echo            WinTune Pro - System Optimizer
echo  ============================================================
echo.

set "SCRIPT_DIR=%~dp0"
set "ENTRYPOINT=%SCRIPT_DIR%WinTune.ps1"

if not exist "%ENTRYPOINT%" (
    echo Canonical entrypoint not found: "%ENTRYPOINT%"
    pause
    exit /b 1
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%ENTRYPOINT%" %* 2>&1

echo.
echo Application closed.
pause
