"""Generate platform icons from design/icon/*.png (Pillow only).

Run from the repo root:  python3 tool/icons/make_icons.py
"""
import json
import os

from PIL import Image

R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
full = Image.open(f"{R}/design/icon/campfire_1024_fullbleed.png").convert("RGB")
rounded = Image.open(f"{R}/design/icon/campfire_1024.png").convert("RGBA")


def save(img, path, size):
    p = f"{R}/{path}"
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(p)


# Android legacy + adaptive foreground
dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
bg = full.getpixel((4, 4))
for d, m in dens.items():
    base = f"android/app/src/main/res/mipmap-{d}"
    save(rounded, f"{base}/ic_launcher.png", round(48 * m))
    save(full.convert("RGBA"), f"{base}/ic_launcher_foreground.png", round(108 * m))

# iOS (RGB, no alpha)
asset = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
c = json.load(open(f"{R}/{asset}/Contents.json"))
for i in c["images"]:
    px = round(float(i["size"].split("x")[0]) * int(i["scale"][0]))
    save(full, f"{asset}/{i['filename']}", px)

# macOS
for s in (16, 32, 64, 128, 256, 512, 1024):
    save(rounded, f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{s}.png", s)

# web
save(rounded, "web/favicon.png", 32)
save(rounded, "web/icons/Icon-192.png", 192)
save(rounded, "web/icons/Icon-512.png", 512)
for s in (192, 512):
    canvas = Image.new("RGB", (s, s), bg)
    inner = round(s * 0.8)
    canvas.paste(full.resize((inner, inner), Image.LANCZOS), ((s - inner) // 2,) * 2)
    canvas.save(f"{R}/web/icons/Icon-maskable-{s}.png")
print("bg", "#%02x%02x%02x" % bg)
