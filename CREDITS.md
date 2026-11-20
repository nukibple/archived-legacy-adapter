# 致谢 / 使用的项目

本项目的核心思路、协议格式与分区数据来自下面这些项目，**没有它们就没有这个仓库**。
本项目只做了「更换取点端 + 更换传输方式」这一层适配，其余协议细节严格对齐上游。

## 直接依赖（协议与分区数据）

### 1. [ERR0RPR0MPT/maimai-android-touch-panel](https://github.com/ERR0RPR0MPT/maimai-android-touch-panel)

* License: MIT
* 用途：
  * **9 字节触摸板数据包格式** `0x28 + 7 字节位掩码 + 0x29`
  * **34 分区表** `exp_list`（A1–A8 / B1–B8 / C1–C2 / D1–D8 / E1–E8 的 7 行排列）
  * **分区颜色表** `exp_image_dict`（RGB → 分区名）
  * **握手字节语义**：`'r'/'k'` 回写设置包、`'A'` 激活、`'L'/'E'` 停止
  * **分区彩图素材** `image/color_exp_panel.png`（本仓库 `linux/color_exp_panel.png` 即该文件）
  * 采样参数思想：`AREA_SCOPE` / `AREA_POINT_NUM`（对应本项目的 `scope` / `points`）

### 2. [ERR0RPR0MPT/maimai-windows-touch-panel](https://github.com/ERR0RPR0MPT/maimai-windows-touch-panel)

* License: MIT
* 用途：
  * 串口侧的完整实现参考（`SerialManager` 的读 6 字节 / 回写 `[40,d1,d2,d3,d4,41]` / 写线程刷帧节奏）
  * 「VSPD 建一对虚拟串口（脚本占一端、游戏占另一端）」的部署范式
  * `COM_PORT = "COM33"` 与游戏读 `COM3` 的配对约定

## 运行环境依赖

| 项目 | 版本/说明 | 在本项目中的角色 |
|---|---|---|
| [LizardByte/Sunshine](https://github.com/LizardByte/Sunshine) | 2026.914 | 主机端串流（NVENC HEVC） |
| [moonlight-qt](https://github.com/moonlight-stream/moonlight-qt) | 6.2.0 | 客户端串流（VAAPI 硬解、全屏） |
| [MuNET-OSS/AquaMai](https://github.com/MuNET-OSS/AquaMai) | 2.6 | 游戏侧 mod 框架，本项目使用其中：<br>`TouchPanelPort`（改触摸板串口号）<br>`TouchToButtonInput`（菜单里分区=按键，长按 C1/C2=Select）<br>`DisplayTouchInGame`（游戏内触摸可视化） |
| [MuNET](https://www.mumur.net) | play.mumur.net / aime.mumur.net | 对战服务器与 AimeDB |
| [iptsd](https://github.com/linux-surface/iptsd) + [linux-surface](https://github.com/linux-surface/linux-surface) | 3.1.1 | Surface IPTS 触屏驱动，暴露 `IPTSD Virtual Touchscreen`（MT-B） |
| [Eltima VSPD Pro](https://www.eltima.com/products/vspd/) | 10.0.858 | 主机端虚拟串口对（**闭源商业软件**，仅作为依赖说明，本仓库不含其任何文件） |
| [PyQt6](https://pypi.org/project/PyQt6/) / [python-evdev](https://github.com/gvalkov/python-evdev) / [Pillow](https://python-pillow.org/) / [pyserial](https://github.com/pyserial/pyserial) | — | 校准器/HUD/取点/串口 |

## 与本项目的差异（为什么不是直接 fork）

| 上游假设 | 本项目做法 |
|---|---|
| 取点：`adb shell getevent`（Android）或 pygame 透明窗（Windows 触屏） | **Linux evdev 多点触控协议 B（MT-B）** |
| 传输：同机 `serial.write()` 到 COM3/COM33 | **TCP → 主机端 `mm_bridge.py` → 虚拟串口** |
| 分区对齐：需要按屏幕分辨率 P 一张整屏图 `image_monitor.png` | **极坐标反向映射到原始 583×583 分区图**，只需圆心+半径，免 P 图 |
| 无 | 额外提供：分区状态 HUD、`tap.py` 协议测试、`setmap.py` 在线微调 |

## 引用

如果你在别处使用本项目，请同时署名上游：

```
Protocol & zone tables:
  ERR0RPR0MPT/maimai-android-touch-panel (MIT)
  ERR0RPR0MPT/maimai-windows-touch-panel (MIT)
Game mods:
  MuNET-OSS/AquaMai
Streaming:
  LizardByte/Sunshine, moonlight-qt
Adapter layer:
  maimai-surface-panel (this repo, MIT)
```
