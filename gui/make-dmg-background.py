#!/usr/bin/env python3
"""Renders the DMG install-window background: an arrow from the app icon slot
to the Applications slot plus bilingual drag-to-install instructions."""
from PIL import Image, ImageDraw, ImageFont

W, H = 660, 420
OUT = __file__.rsplit("/", 1)[0] + "/Resources/dmg-background.png"

img = Image.new("RGB", (W, H))
top = (234, 247, 242)
bottom = (252, 253, 253)
for y in range(H):
    t = y / (H - 1)
    row = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    ImageDraw.Draw(img).line([(0, y), (W, y)], fill=row)

d = ImageDraw.Draw(img)
y = 190
# Gradient arrow: teal at the tail fading to bright green at the head.
mask = Image.new("L", (W, H), 0)
md = ImageDraw.Draw(mask)
md.line([(240, y), (400, y)], fill=255, width=10)
md.polygon([(400, y - 22), (400, y + 22), (432, y)], fill=255)
grad = Image.new("RGB", (W, H))
gd = ImageDraw.Draw(grad)
c0 = (10, 158, 143)
c1 = (52, 211, 153)
for x in range(W):
    t = min(1.0, max(0.0, (x - 240) / (432 - 240)))
    gd.line([(x, 0), (x, H)], fill=tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3)))
img.paste(grad, (0, 0), mask)


def font(size):
    for path in ("/System/Library/Fonts/Hiragino Sans GB.ttc", "/System/Library/Fonts/PingFang.ttc",
                 "/System/Library/Fonts/STHeiti Light.ttc", "/System/Library/Fonts/Helvetica.ttc"):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def center(text, y, size, color):
    f = font(size)
    box = d.textbbox((0, 0), text, font=f)
    d.text(((W - (box[2] - box[0])) / 2 - box[0], y), text, font=f, fill=color)


center("拖拽 WeChat Multi Launch 到 Applications 安装", 316, 21, (60, 66, 70))
center("Drag WeChat Multi Launch to Applications to install", 352, 14, (130, 138, 142))

img.save(OUT)
print("wrote", OUT)