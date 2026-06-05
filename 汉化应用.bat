@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Requesting administrator privileges...
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$args = @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','%~dp0scripts\repair_localization.ps1'); $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -Wait -PassThru; exit $p.ExitCode"
    exit /b %errorlevel%
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\repair_localization.ps1"
if errorlevel 1 goto failed

echo.
echo Done. Claude Desktop visible UI localization has been repaired and verified.
pause
exit /b 0

:failed
echo.
echo Failed. Run 汉化回滚.bat as administrator to restore the latest backup.
pause
exit /b 1
