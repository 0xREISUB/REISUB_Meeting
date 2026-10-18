"""Export platform icon sizes from the unchanged brand image. Requires Pillow.

Run from any directory: python3 tool/generate_icons.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/branding/logo.png"


def main():
    with Image.open(SOURCE) as source:
        logo = source.convert("RGBA")
    if logo.width != logo.height:
        raise ValueError("The app logo must be square.")

    def png(path, size):
        target = ROOT / path
        target.parent.mkdir(parents=True, exist_ok=True)
        logo.resize((size, size), Image.Resampling.LANCZOS).save(target)

    for density, size in {
        "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
    }.items():
        png(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)

    for size in (192, 512):
        png(f"web/icons/Icon-{size}.png", size)
        png(f"web/icons/Icon-maskable-{size}.png", size)
    png("web/favicon.png", 32)

    logo.save(
        ROOT / "windows/runner/resources/app_icon.ico",
        format="ICO",
        sizes=[(size, size) for size in (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)],
    )
    print("Android, Windows and web icons exported from assets/branding/logo.png")


if __name__ == "__main__":
    main()
