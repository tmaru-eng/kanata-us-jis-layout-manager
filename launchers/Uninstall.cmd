@echo off
setlocal
set "ROOT=%~dp0.."
cd /d "%TEMP%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -NoExit -File "%ROOT%\Uninstall-KanataLayoutManager.ps1" %*
