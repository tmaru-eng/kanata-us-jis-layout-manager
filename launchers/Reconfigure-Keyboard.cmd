@echo off
setlocal
set "INSTALL_ROOT=%LOCALAPPDATA%\KanataLayoutManager"
if not exist "%INSTALL_ROOT%\Reconfigure-KanataKeyboard.ps1" (
  echo KanataLayoutManager is not installed in "%INSTALL_ROOT%".
  echo Run Bootstrap-Install.cmd first.
  echo.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%INSTALL_ROOT%\Reconfigure-KanataKeyboard.ps1"
