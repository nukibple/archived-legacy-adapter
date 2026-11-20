@echo off
chcp 65001 >nul
title maimai DX 触屏手台 - 一键启动
cd /d "%~dp0"

set "ROOT=%~dp0"
set "TOOL=%~dp0maimai-touch"
set "PY=%~dp0maimai-touch\python\python.exe"

echo ============================================================
echo    maimai DX 触屏手台 - 一键启动
echo    触屏端: 在 Linux/Surface 上运行 mm-start.sh
echo ============================================================

rem ---------- 1. 环境自检 ----------
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOL%\check.ps1"
if errorlevel 1 (
    echo.
    echo [已中止] 环境检查没过，按上面 "->" 提示处理后重试。
    pause
    exit /b 1
)

rem ---------- 2. 分区覆盖层开关判定 ----------
rem     hud=0 不显示（默认，调好后用这个）
rem     hud=1 显示（调试用）
rem     命令行加 /hud 可临时打开：一键启动.bat /hud
set "HUD=0"
if exist "%TOOL%\hud.ini" (
    for /f "tokens=1,2 delims== " %%a in ('findstr /b /i "hud=" "%TOOL%\hud.ini"') do set "HUD=%%b"
)
if /i "%~1"=="/hud" set "HUD=1"

rem ---------- 3. 屏幕转竖屏 ----------
echo.
echo [1/4] 屏幕方向 - 竖屏
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOL%\rotate-display.ps1" -Orientation portrait >nul 2>&1
echo      完成

rem ---------- 4. 触摸桥接 ----------
echo.
echo [2/4] 启动触摸桥接  COM2 - TCP 23333
taskkill /f /fi "WINDOWTITLE eq mm_bridge*" >nul 2>&1
start "mm_bridge" /min cmd /c ""%PY%" "%TOOL%\mm_bridge.py" --com COM2 --port 23333 --hz 1000 --force > "%TOOL%\bridge.log" 2>&1"
ping -n 4 127.0.0.1 >nul
find /i "监听 TCP" "%TOOL%\bridge.log" >nul 2>&1
if errorlevel 1 (
    echo      [警告] 桥接可能没起来，见 %TOOL%\bridge.log
) else (
    echo      桥接已就绪
)

rem ---------- 5. 分区覆盖层（调试用，默认不显示）----------
echo.
echo [3/4] 分区覆盖层  ^(调试用^)
if "%HUD%"=="1" (
    "%PY%" -c "import tkinter" >nul 2>&1
    if errorlevel 1 (
        echo      想显示但内置 Python 无 tkinter，跳过
    ) else (
        start "mm_hud" /min cmd /c ""%PY%" "%TOOL%\hud_win.py" --game 1080x1920 --alpha 0.42 > "%TOOL%\hud.log" 2>&1"
        echo      已显示 ^(F=只看命中 / L=标签 / 关它的窗口或改 hud.ini 为 0 即可隐藏^)
    )
) else (
    echo      不显示 ^(调好后保持这样^)
    echo      需要调试时: 双击『分区覆盖层开关.bat』，或运行 一键启动.bat /hud
)

rem ---------- 6. 启动游戏 ----------
echo.
echo [4/4] 启动游戏
echo ------------------------------------------------------------
set "GAMEBAT="
if exist "%ROOT%启动.bat"         set "GAMEBAT=%ROOT%启动.bat"
if not defined GAMEBAT if exist "%ROOT%start.bat"         set "GAMEBAT=%ROOT%start.bat"
if not defined GAMEBAT if exist "%ROOT%Package\start.bat" set "GAMEBAT=%ROOT%Package\start.bat"
if not defined GAMEBAT (
    echo [错误] 找不到 启动.bat / start.bat
    pause
    exit /b 1
)
echo 调用: %GAMEBAT%
call "%GAMEBAT%"

rem ---------- 7. 收尾 ----------
echo.
echo ------------------------------------------------------------
echo 游戏已退出，清理中...
taskkill /f /fi "WINDOWTITLE eq mm_bridge*" >nul 2>&1
taskkill /f /fi "WINDOWTITLE eq mm_hud*" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%TOOL%\rotate-display.ps1" -Orientation landscape >nul 2>&1
echo 桥接/覆盖层 已停止，屏幕已转回横屏
echo 触屏端记得执行 ~/mm-stop.sh 释放触屏
ping -n 4 127.0.0.1 >nul
exit /b 0
