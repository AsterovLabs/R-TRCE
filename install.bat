@echo off
:: =============================================================================
:: install.bat -- Double-Click Windows Installer for R-TRCE
:: Works seamlessly on Windows 10 & Windows 11
:: =============================================================================

title R-TRCE Auto-Installer
cd /d "%~dp0"

echo ==================================================================
echo   R-TRCE Windows Auto-Installer
echo ==================================================================
echo.
echo Launching PowerShell installer with execution bypass...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [!] An error occurred during installation.
    pause
    exit /b %errorlevel%
)

echo.
echo Press any key to exit installer...
pause >nul
