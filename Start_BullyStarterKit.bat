@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "BSK_PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%BSK_PS%" (
  echo Windows PowerShell 5.1 is required but was not found.
  pause
  exit /b 1
)

if /I "%~1"=="--launcher-test" (
  echo Bully Starter Kit launcher OK.
  endlocal
  exit /b 0
)

"%BSK_PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0src\BullyStarterKit.ps1"
set "BSK_EXIT=%ERRORLEVEL%"

if not "%BSK_EXIT%"=="0" (
  echo.
  echo Bully Starter Kit closed with an error. Exit code: %BSK_EXIT%
  pause
)

endlocal & exit /b %BSK_EXIT%
