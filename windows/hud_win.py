#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
hud_win.py —— 主机端分区触发 HUD（半透明覆盖在游戏画面上，随串流一起传到 Surface）

它从 mm_bridge 的状态端口（TCP 23334）读实时状态，在 1080x1920 的游戏画面上
把 34 个分区画出来：按下的分区高亮，其余暗淡（或透明）。

因为画在主机端，串流会把它一起编码过去，所以一定看得见，
不受 KDE/Wayland 窗口层级影响。

用法： python hud_win.py [--host 127.0.0.1] [--port 23334] [--game 1080x1920]
      Ctrl+Alt+Q 退出（或关窗口）
"""

import argparse
import json
import math
import socket
import sys
import threading
import time
import tkinter as tk

from PIL import Image

ART = r"C:\Users\nukibple\mm\repos\maimai-android-touch-panel\image\color_exp_panel.png"

COLOR_MAP = {
    "41-65-93": "A1", "87-152-13": "A2", "213-109-81": "A3", "23-222-55": "A4", "69-203-71": "A5",
    "147-253-55": "A6", "77-19-35": "A7", "159-109-79": "A8", "87-217-111": "B1", "149-95-154": "B2",
    "97-233-9": "B3", "159-27-222": "B4", "152-173-186": "B5", "192-185-149": "B6", "158-45-23": "B7",
    "197-158-219": "B8", "127-144-79": "C1", "242-41-155": "C2", "69-67-213": "D1", "105-25-130": "D2",
    "17-39-170": "D3", "97-103-203": "D4", "113-25-77": "D5", "21-21-140": "D6", "155-179-166": "D7",
    "55-181-134": "D8", "61-33-27": "E1", "51-91-95": "E2", "143-227-63": "E3", "216-67-226": "E4",
    "202-181-245": "E5", "99-11-183": "E6", "75-119-224": "E7", "182-19-85": "E8",
}


def zone_polar_shapes():
    """从分区彩图算出每个分区的 (r0, r1, a0, a1)（归一化：r 相对图半径，角度弧度）"""
    img = Image.open(ART).convert("RGB")
    w, h = img.size
    px = img.load()
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    R = w / 2.0
    acc = {}
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            n = COLOR_MAP.get(f"{r}-{g}-{b}")
            if not n:
                continue
            dx, dy = x - cx, y - cy
            rad = math.hypot(dx, dy) / R
            ang = math.atan2(dy, dx)
            a = acc.setdefault(n, [1e9, -1e9, [], 0])
            a[0] = min(a[0], rad)
            a[1] = max(a[1], rad)
            a[2].append(ang)
            a[3] += 1
    shapes = {}
    for n, (r0, r1, angs, _c) in acc.items():
        angs.sort()
        # 处理跨 ±pi 的情况：找最大间隙
        gaps = [(angs[(i + 1) % len(angs)] - angs[i], i) for i in range(len(angs))]
        gaps[-1] = (angs[0] + 2 * math.pi - angs[-1], len(angs) - 1)
        g, gi = max(gaps)
        a0 = angs[(gi + 1) % len(angs)]
        a1 = angs[gi]
        if a1 < a0:
            a1 += 2 * math.pi
        shapes[n] = (r0, r1, a0, a1)
    return shapes


class Hud:
    def __init__(self, host, port, gw, gh):
        self.gw, self.gh = gw, gh
        self.shapes = zone_polar_shapes()
        self.zones = set()
        self.geom = {}
        self.stale = True
        self.host, self.port = host, port

        self.root = tk.Tk()
        self.root.overrideredirect(True)
        self.root.geometry(f"{gw}x{gh}+0+0")
        self.root.attributes("-topmost", True)
        self.root.attributes("-alpha", 1.0)
        self.root.configure(bg="black")
        try:
            self.root.wm_attributes("-transparentcolor", "black")
        except Exception:
            self.root.attributes("-alpha", 0.35)

        self.canvas = tk.Canvas(self.root, width=gw, height=gh, bg="black",
                                highlightthickness=0, bd=0)
        self.canvas.pack()

        # 点击穿透
        try:
            import ctypes
            GWL_EXSTYLE, WS_EX_LAYERED, WS_EX_TRANSPARENT = -20, 0x80000, 0x20
            hwnd = ctypes.windll.user32.GetParent(self.root.winfo_id())
            style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
            ctypes.windll.user32.SetWindowLongW(
                hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED | WS_EX_TRANSPARENT)
        except Exception:
            pass

        threading.Thread(target=self.net_loop, daemon=True).start()
        self.root.after(40, self.redraw)
        self.root.mainloop()

    def net_loop(self):
        while True:
            try:
                s = socket.create_connection((self.host, self.port), timeout=2)
                buf = b""
                while True:
                    d = s.recv(4096)
                    if not d:
                        break
                    buf += d
                    while b"\n" in buf:
                        line, buf = buf.split(b"\n", 1)
                        try:
                            st = json.loads(line.decode() or "{}")
                        except Exception:
                            continue
                        self.zones = set(st.get("zones") or [])
                        self.geom = st.get("geom") or {}
                        self.stale = False
                s.close()
            except Exception:
                self.stale = True
                time.sleep(1)

    def redraw(self):
        c = self.canvas
        c.delete("all")
        w, h = self.gw, self.gh
        # 圆：按游戏画面 1080x1920 里量出来的 圆心(544,1430) 半径503
        # 从 mm-panel 的 geom（Surface 逻辑坐标）换算到主机 1080x1920 坐标
        k = 1520.0 / 1920.0          # 串流在 Surface 逻辑屏里的缩放
        x0 = (1014.0 - 1080.0 * k) / 2.0
        g = (self.geom or {})
        if g.get("mode") == "rect":
            rx0, ry0, rx1, ry1 = g.get("rect", [0, 0, 1014, 1520])
            cxl, cyl = (rx0 + rx1) / 2.0, (ry0 + ry1) / 2.0
            rl = min(rx1 - rx0, ry1 - ry0) / 2.0
        else:
            cxl, cyl = g.get("center", [507.0, 1096.0])
            rl = g.get("radius", 424.0)
        cx = (cxl - x0) / k
        cy = cyl / k
        R = rl / k

        for name, (r0, r1, a0, a1) in self.shapes.items():
            touched = name in self.zones
            if touched:
                col = "#00ff66"
            elif self.stale:
                col = ""          # 未连上：不画
            else:
                col = ""
            pts = []
            steps = 8
            for i in range(steps + 1):
                a = a0 + (a1 - a0) * i / steps
                pts.append((cx + math.cos(a) * r0 * R, cy + math.sin(a) * r0 * R))
            for i in range(steps + 1):
                a = a1 - (a1 - a0) * i / steps
                pts.append((cx + math.cos(a) * r1 * R, cy + math.sin(a) * r1 * R))
            flat = [v for p in pts for v in p]
            if len(flat) >= 6:
                if touched:
                    c.create_polygon(flat, fill="#00ff66", outline="#003300", width=2)
                else:
                    # 只画外弧细线做提示
                    arc = []
                    for i in range(steps + 1):
                        a = a0 + (a1 - a0) * i / steps
                        arc.append((cx + math.cos(a) * r1 * R, cy + math.sin(a) * r1 * R))
                    c.create_line([v for p2 in arc for v in p2], fill="#2a6b6b", width=2)

        # 中心十字
        c.create_line(cx - 20, cy, cx + 20, cy, fill="#ff4444", width=3)
        c.create_line(cx, cy - 20, cx, cy + 20, fill="#ff4444", width=3)

        # 顶部状态
        if self.stale:
            txt = "HUD: 未连上 mm_bridge 状态端口 (23334)"
            col = "#ff6666"
        else:
            txt = "命中: " + (" ".join(sorted(self.zones)) if self.zones else "无触摸")
            col = "#00e0ff"
        c.create_rectangle(0, 0, w, 70, fill="#000000", outline="")
        c.create_text(w / 2, 34, text=txt, fill=col,
                      font=("Microsoft YaHei UI", 26, "bold"))
        self.root.after(40, self.redraw)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=23334)
    ap.add_argument("--game", default="1080x1920")
    a = ap.parse_args()
    gw, gh = (int(v) for v in a.game.lower().split("x"))
    Hud(a.host, a.port, gw, gh)


if __name__ == "__main__":
    main()
