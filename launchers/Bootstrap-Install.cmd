@echo off
setlocal
set "ROOT=%~dp0.."
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\Bootstrap-KanataWintercept.ps1" %*
if errorlevel 1 (
  echo.
  echo Failed. Press any key to close this window.
  pause >nul
  exit /b 1
)
echo.
echo Finished. If the Interception driver was installed, restart Windows.
echo Press any key to close this window.
pause >nul
