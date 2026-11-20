@echo off
chcp 65001 >nul
title 分区覆盖层开关（调试用）
cd /d "%~dp0"
set "INI=%~dp0maimai-touch\hud.ini"

if not exist "%INI%" (
    > "%INI%" echo hud=0
)

set "CUR=0"
for /f "tokens=1,2 delims== " %%a in ('findstr /b /i "hud=" "%INI%"') do set "CUR=%%b"

if "%CUR%"=="1" (set "NEW=0") else (set "NEW=1")
> "%INI%" echo hud=%NEW%

echo ============================================================
if "%NEW%"=="1" (
    echo   分区覆盖层: 已开启 [调试模式]
    echo   - 下次双击「一键启动.bat」时，会在游戏画面上叠一层
    echo     半透明的分区状态（手指按到哪一区会亮绿 + 顶部显示分区名）
    echo   - 层内快捷键:  F = 只看命中   L = 分区名   Esc = 关掉覆盖层窗口
    echo   - 调好之后，再双击本文件即可关闭
) else (
    echo   分区覆盖层: 已关闭 [正常游玩]
    echo   - 启动时不再显示覆盖层，画面干净
    echo   - 需要再调试时，双击本文件重新打开
)
echo ============================================================
echo   当前配置: %INI%  -^>  hud=%NEW%
echo.
pause
