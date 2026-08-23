"""Drives REBOOT on the iOS Simulator for the fresh-install walkthrough.

Maps logical device points (iPhone 17 Pro: 402x874 pt) to host screen
coordinates inside the Simulator window using Quartz window bounds.
"""
import json
import subprocess
import sys
import time

import pyautogui
import Quartz

pyautogui.FAILSAFE = False
DEVICE_W, DEVICE_H = 402.0, 874.0  # iPhone 17 Pro logical points


def simulator_window_bounds():
    wins = Quartz.CGWindowListCopyWindowInfo(
        Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListOptionAll,
        Quartz.kCGNullWindowID)
    best = None
    for w in wins:
        if str(w.get("kCGWindowOwnerName", "")) != "Simulator":
            continue
        b = dict(w.get("kCGWindowBounds") or {})
        if not b:
            continue
        area = b.get("Width", 0) * b.get("Height", 0)
        if area >= 100_000 and (best is None or area > best[1]):
            best = (b, area)
    if not best:
        raise SystemExit("Simulator window with content area not found")
    b = best[0]
    return b["X"], b["Y"], b["Width"], b["Height"]


def tap(x_pt, y_pt):
    wx, wy, ww, wh = simulator_window_bounds()
    # Content area excludes the macOS title bar (~28pt) but includes bezel-less
    # device screen filling the window below it.
    title_h = 28.0
    scale_x = ww / DEVICE_W
    scale_y = (wh - title_h) / DEVICE_H
    scale = min(scale_x, scale_y)
    content_w = DEVICE_W * scale
    content_h = DEVICE_H * scale
    off_x = wx + (ww - content_w) / 2.0
    off_y = wy + title_h + ((wh - title_h) - content_h) / 2.0
    sx = off_x + x_pt * scale
    sy = off_y + y_pt * scale
    pyautogui.moveTo(sx, sy, duration=0.12)
    pyautogui.click()
    time.sleep(0.4)


def shot(path):
    subprocess.run(["xcrun", "simctl", "io", "iPhone 17 Pro", "screenshot", path],
                   check=True, capture_output=True)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "tap":
        tap(float(sys.argv[2]), float(sys.argv[3]))
    elif cmd == "shot":
        shot(sys.argv[2])
