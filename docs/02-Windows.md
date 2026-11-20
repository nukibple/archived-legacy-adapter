# Windows 主机部署

> 目标：游戏跑在本机，触摸板数据从 `COM1` 读进来。

## 1. 虚拟串口

游戏读串口，桥接也要串口，所以需要一对互通的虚拟串口。

| 方案 | 说明 |
|---|---|
| **VSPD Pro**（推荐） | 面板里新建 `COM1 ⇄ COM2`。付费软件，Win11 驱动签名有效 |
| com0com 3.0.0.0 | 免费，但驱动证书 2018 年过期，**Win11 会拒加载**（`0xC0000428`） |
| USR-VCOM | 驱动实为 Eltima `evserial9.sys`，同样过不了新系统 |

> 重启后如果端口全变成 `CM_PROB_PHANTOM`，说明内核驱动没起来：
> 管理员执行 `sc start evserial9`（可写进开机自检脚本）。

约定：**桥接占 `COM2`，游戏占 `COM1`**。

## 2. Sunshine

安装后确认服务运行：

```powershell
Get-Service SunshineService     # 应为 Running
```

串流参数实测可用：`1080x1920@60`、HEVC、50 Mbps、NVENC。

## 3. 游戏配置（`Package\` 目录）

### `mai2.ini`

```ini
[AM]
DummyTouchPanel=0
```

### `segatools.ini`

```ini
[vfs]
amfs=amfs
option=option
appdata=appdata

[aime]
enable=1
aimeGen=1

[dns]
enable=1
Default=play.mumur.net
AimeDB=aime.mumur.net

[netenv]
enable=1
addrSuffix=103

[keychip]
enable=1
platformld=ACA1
id=A611-03186083437
subnet=192.168.0.0
gameId=SDEZ          ; 必须与游戏版本一致
region=4

[system]
enable=1
dipsw1=0             ; ★ 在线模式。=1 不连服务器 → 刷不上卡 / 登录退回
```

> **保存时必须 UTF-8 无 BOM**。带 BOM 会让第一段 `[vfs]` 解析失败，
> amdaemon 直接 `Vfs: FATAL: AMFS path not specified in INI file` 退出，游戏黑屏。

### `AquaMai.toml`（GBK 编码，别用 UTF-8 覆盖）

```toml
[GameSystem.TouchPanelPort]
PortName_1P = "COM1"      # 默认 COM3，改成桥接对端

[GameSystem.TouchToButtonInput]   # 菜单里分区=按键；长按 C1/C2≥500ms = Select（刷 Aime 卡）

[Utils.DisplayTouchInGame]        # 游戏内触摸可视化，调映射时有用

[GameSystem.Window]
Width = 1080
Height = 1920
```

## 4. 启动

```powershell
windows\start-all.bat
```

依次：检查 COM1/COM2 → 校验并修正 `dipsw1` → 起桥接（1000 Hz）→ 起 Sunshine 服务 → 起 HUD → 起游戏。

收工：

```powershell
windows\stop-all.bat      # 停游戏/桥接/HUD + 屏幕转回横屏
```

## 5. Aime 卡

* 卡号由 segatools 生成在 `Package\DEVICE\aime.txt`（20 位数字）
* 要在 **MuNET 面板**把这张卡绑定到账号，否则登录会被弹回
* 游戏里长按触摸板圆心（C1/C2 ≥500ms）= Select = 刷这张卡

## 6. 可选：没有游戏时验证链路

```powershell
python mm_bridge.py --com COM2 --port 23333 --mock    # 内置假游戏，无需驱动
python mm_game_sim.py --com COM1                      # 假游戏，验证真实串口对
python tap.py --zones C1,C2 --hold 150 --gap 300      # 直接发一次"点击"
```
