@echo off
chcp 65001 >nul
title maimai DX 一键关闭（含屏幕还原）
cd /d "%~dp0"

echo ============================================
echo   1) 停止游戏
echo ============================================
taskkill /f /im Sinmai.exe >nul 2>&1 && echo   Sinmai 已关闭
taskkill /f /im amdaemon.exe >nul 2>&1 && echo   amdaemon 已关闭

echo.
echo ============================================
echo   2) 停止桥接 / HUD
echo ============================================
for /f "tokens=2 delims=," %%p in ('tasklist /fi "imagename eq python.exe" /fo csv /nh') do (
    taskkill /f /pid %%p >nul 2>&1
)
echo   python 进程已清理

echo.
echo ============================================
echo   3) 屏幕转回横屏
echo ============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0rotate-display.ps1" -Orientation landscape

echo.
echo ============================================
echo   4) 结果
echo ============================================
tasklist /fi "imagename eq Sinmai.exe" | find /i "Sinmai" >nul && (echo   [!] Sinmai 还在) || echo   游戏: 已停止
tasklist /fi "imagename eq python.exe" | find /i "python" >nul && (echo   [!] python 还在) || echo   桥接/HUD: 已停止
echo   Sunshine 服务保留运行（下次不用重装）
echo.
echo [OK] 收工。Surface 上记得跑 ~/mm-stop.sh 关闭串流并释放触屏
timeout /t 3 >nul
