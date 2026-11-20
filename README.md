# maimai DX · Surface 触屏手台

把一台带触控屏的 Linux 设备（本项目实测为 **Surface Pro 5 / Arch Linux**）当成 maimai DX 的触摸板：
Windows 主机跑游戏 → Sunshine 串流到 Linux → Linux 的触屏按压被换算成 maimai 的 34 分区触摸板数据 →
经 TCP + 虚拟串口回送游戏。

```
┌──────────── Windows 主机（游戏） ────────────┐          ┌──────── Linux + 触屏 ────────┐
│ maimai DX (Sinmai / SDEZ)                    │          │ Moonlight 全屏串流            │
│ Sunshine ── NVENC HEVC 1080x1920@60 ────────┼─────────▶│ 竖屏显示                      │
│                                              │          │                              │
│ mm_bridge.py ─ COM2 ⇄ VSPD ⇄ COM1 ─ 游戏      │◀─────────│ mm_panel.py（独占触屏）        │
│ hud_win.py   （分区状态 HUD，随串流显示）      │ TCP 23333│ 极坐标 → 34 分区 → 9 字节帧    │
└──────────────────────────────────────────────┘          └──────────────────────────────┘
```

## 为什么需要这套东西

moonlight 把触屏动作当鼠标发回主机，而 maimai 需要的是「在哪个扇区按下」的触摸板数据。
两个上游项目（见 [CREDITS.md](CREDITS.md)）解决了协议与分区换算，但都假设**触屏和游戏在同一台机器**：

* `maimai-android-touch-panel`：触屏在 Android 上，靠 `adb getevent` 取点
* `maimai-windows-touch-panel`：触屏在 Windows 上，靠 pygame 透明窗取点

本项目把「取点」换到 Linux（evdev）、把「串口」换成 TCP，于是 **游戏在 A 机、触屏在 B 机** 也能工作。
协议、34 分区表、颜色表、握手字节都与上游**逐字节一致**。

## 快速开始

### Windows 主机

1. 装 **VSPD**（或 com0com），建一对虚拟串口 `COM1 ⇄ COM2`
2. 装 **Sunshine**，服务 `SunshineService`
3. 游戏配置（`Package\` 下）：
   * `mai2.ini` → `DummyTouchPanel=0`
   * `segatools.ini` → `[system] dipsw1=0`（**在线模式，改成 1 会刷不上卡**）
   * `AquaMai.toml` → 见 [docs/02-Windows.md](docs/02-Windows.md)
4. 双击 `windows\start-all.bat`

### Linux（Surface）

```bash
sudo ./install.sh          # 装依赖 + 部署 systemd 服务（见 docs/03-Linux.md）
~/mm-start.sh              # 起触摸服务 + 全屏串流
~/mm-stop.sh               # 关闭并释放触屏
```

## 目录

| 路径 | 作用 |
|---|---|
| `windows/mm_bridge.py` | TCP → 虚拟串口桥接，处理游戏握手（`k`/`A`/`L`），1000Hz 写帧 |
| `windows/hud_win.py` | 分区触发状态 HUD（半透明，画在主机画面上随串流显示） |
| `windows/tap.py` | 直接给桥接发「点击」序列，便于脱离触屏做协议验证 |
| `windows/mm_game_sim.py` | 假游戏，没有 maimai 时验证串口链路 |
| `windows/rotate-display.ps1` | 屏幕旋转（竖屏/横屏） |
| `linux/mm_panel.py` | evdev 多点触控 → 34 分区 → 9 字节帧 → TCP |
| `linux/setmap.py` | 分区圆心/半径/旋转快速微调 |
| `linux/mm-panel.service` | systemd 单元（`User=arch`，`SupplementaryGroups=input`） |
| `docs/` | 架构、双端部署、校准、故障排查 |

## 已验证

| 项 | 结果 |
|---|---|
| 游戏自检 `タッチセンサ(1P)` | `GOOD CHECK` |
| 登录 | MuNET 在线（`110.40.128.13:84`），读 `DEVICE\aime.txt` 卡号登录成功 |
| 串流 | 1080×1920@60 HEVC ~50 Mbps，VAAPI 硬解 |
| 网络 | TCP 下行 526 Mbps、10 分钟 soak 平均 519.8 Mbps、UDP 150 Mbps 零丢包 |
| 实战 | 已能正常打歌（EXPERT Lv.12，combo 正常） |

## 许可证

本项目代码 MIT，见 [LICENSE](LICENSE)。
上游代码/素材的版权归各自作者，署名见 [CREDITS.md](CREDITS.md)。
