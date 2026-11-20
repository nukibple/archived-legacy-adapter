@echo off
chcp 65001 >nul
title maimai DX 一键启动 (Windows 主机)
cd /d "%~dp0"

echo ============================================
echo   1) 检查虚拟串口对 (VSPD COM1 <-> COM2)
echo ============================================
python -c "from serial.tools import list_ports; ps=[p.device for p in list_ports.comports()]; print('ports:', ps); import sys; sys.exit(0 if ('COM1' in ps and 'COM2' in ps) else 1)"
if errorlevel 1 (
    echo [!] 没找到 COM1/COM2，请在 VSPD Pro 里建一对 COM1 - COM2
    pause
    exit /b 1
)

echo.
echo ============================================
echo   2) 启动触摸桥接 (COM2 -> 23333, 1000Hz)
echo ============================================
taskkill /f /im python.exe /fi "WINDOWTITLE eq mm_bridge*" >nul 2>&1
for /f "tokens=1" %%p in ('wmic process where "name='python.exe'" get processid,commandline ^| findstr mm_bridge') do taskkill /f /pid %%p >nul 2>&1
start "mm_bridge" /min cmd /c "python mm_bridge.py --com COM2 --port 23333 --hz 1000 > bridge.log 2>&1"
timeout /t 3 >nul

echo.
echo ============================================
echo   2.5) 检查 segatools.ini: dipsw1 必须=0（在线模式）
echo ============================================
powershell -NoProfile -Command "$p='D:\mm\maimai DX SDEZ 1.70\maimai DX SDEZ 1.70\Package\segatools.ini'; $t=[IO.File]::ReadAllText($p); if ($t -match '(?m)^dipsw1=1') { $t = $t -replace '(?m)^dipsw1=.*$','dipsw1=0'; [IO.File]::WriteAllText($p,$t,(New-Object System.Text.UTF8Encoding($false))); Write-Host '   [fix] dipsw1 已改回 0（在线模式）' } else { Write-Host '   dipsw1=0 OK' }"

echo.
echo ============================================
echo   3) 启动/确认 Sunshine 服务
echo ============================================
sc query SunshineService | find "RUNNING" >nul
if errorlevel 1 (
    echo [*] 启动 Sunshine 服务...
    net start SunshineService >nul 2>&1
) else (
    echo [*] Sunshine 已在运行
)

echo.
echo ============================================
echo   4) 启动 HUD（分区触发状态，随串流显示）
echo ============================================
start "mm_hud" /min cmd /c "python hud_win.py --game 1080x1920 > hud_win.log 2>&1"

echo.
echo ============================================
echo   5) 启动游戏
echo ============================================
echo [*] 现在请在 Surface 上双击「一键启动」，或者在 Moonlight 里选 maimai DX
echo [*] 如果要在本机直接启动游戏，按任意键继续（会自己拉起来）
pause >nul
start "" "%~dp0game\launch.bat"

echo.
echo [OK] Windows 侧已就绪：桥接 + Sunshine + HUD + 游戏
echo      关闭请运行 stop-all.bat
timeout /t 3 >nul
