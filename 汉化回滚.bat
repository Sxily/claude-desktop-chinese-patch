@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Requesting administrator privileges...
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','%~dp0scripts\rollback_localization.ps1'); $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
    exit /b %errorlevel%
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\rollback_localization.ps1"
set "exitcode=%errorlevel%"
pause
exit /b %exitcode%
