@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================================
echo  CC-Haha theme-only branch: update + verify + build
echo ============================================================
echo.
echo Close the running theme build first if it lives in the
echo staging output directory. The stock install is never touched.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update-theme.ps1" -Build
set "CODE=%ERRORLEVEL%"

echo.
if not "%CODE%"=="0" (
    echo [theme-update] Failed with exit code %CODE%.
    echo Check the messages above; conflicts must be resolved manually.
) else (
    echo [theme-update] Done. Staging output: desktop\build-artifacts\theme-next\win-unpacked
)
echo.
pause
exit /b %CODE%
