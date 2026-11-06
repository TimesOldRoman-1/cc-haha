@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================================
echo  CC-Haha personal: update upstream + verify + build
echo ============================================================
echo.
echo Close the running personal build first if it lives in the
echo staging output directory. The stock install is never touched.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-personal.ps1" -Build
set "CODE=%ERRORLEVEL%"

echo.
if not "%CODE%"=="0" (
    echo [update-personal] Failed with exit code %CODE%.
    echo Check the messages above; conflicts must be resolved manually.
) else (
    echo [update-personal] Done. Staging output: desktop\build-artifacts\personal-next\win-unpacked
)
echo.
pause
exit /b %CODE%
