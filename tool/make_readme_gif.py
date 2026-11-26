"""Make images/phone-tour.gif from the frames that the README screenshot
test renders (SCREENSHOTS=1 flutter test test/screenshots), then delete the
frames. Needs ffmpeg.

    python3 tool/make_readme_gif.py
"""
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FRAMES = ROOT / "images/gif-frames"
OUT = ROOT / "images/phone-tour.gif"
FPS = 25  # The test renders a frame every 40 ms.
WIDTH = 360


def main() -> None:
    if not any(FRAMES.glob("*.png")):
        raise SystemExit("No frames; run: SCREENSHOTS=1 flutter test test/screenshots")
    # One palette for the whole GIF, from what changes between frames, so
    # the glass's gradients stay smooth.
    scale = f"fps={FPS},scale={WIDTH}:-1:flags=lanczos"
    subprocess.run(
        [
            "ffmpeg", "-loglevel", "error", "-y",
            "-framerate", str(FPS), "-i", str(FRAMES / "%04d.png"),
            "-filter_complex",
            f"[0:v]{scale},split[a][b];[a]palettegen=stats_mode=diff[p];"
            "[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle",
            "-loop", "0", str(OUT),
        ],
        check=True,
    )
    shutil.rmtree(FRAMES)
    print(f"{OUT.relative_to(ROOT)}: {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
