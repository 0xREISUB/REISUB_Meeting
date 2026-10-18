"""Package an existing Flutter Linux release bundle without installing it.

Usage: python3 tool/package_deb.py [--bundle PATH] [--output-dir PATH]
Requires Debian/Ubuntu tools: dpkg-deb, dpkg-shlibdeps and binutils.
"""
import argparse
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "reisub-meeting"
APP_ID = "com.example.v_meeting"
MAINTAINER = "Yusuf Enes Metin <yusufenes4124@gmail.com>"
HOMEPAGE = "https://github.com/0xREISUB/REISUB_Meeting"


def run(command, **kwargs):
    return subprocess.run(command, check=True, text=True, capture_output=True, **kwargs)


def architecture(executable):
    with executable.open("rb") as stream:
        header = stream.read(20)
    if header[:6] != b"\x7fELF\x02\x01":
        raise ValueError("Expected a 64-bit little-endian Linux release executable.")
    machine = struct.unpack_from("<H", header, 18)[0]
    if machine not in (62, 183):
        raise ValueError(f"Unsupported ELF machine: {machine}")
    return {62: "amd64", 183: "arm64"}[machine]


def write(path, content, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    path.chmod(mode)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle", type=Path, default=ROOT / "build/linux/x64/release/bundle")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build/packages")
    args = parser.parse_args()
    bundle = args.bundle.resolve()
    output = args.output_dir.resolve()
    for command in ("dpkg-deb", "dpkg-shlibdeps", "dpkg", "readelf"):
        if not shutil.which(command):
            raise RuntimeError(f"Required packaging tool is not installed: {command}")
    executable = bundle / "REISUB Meeting"
    if not executable.is_file():
        raise FileNotFoundError(f"Build the Linux release first; missing {executable}")
    arch = architecture(executable)
    host_arch = run(["dpkg", "--print-architecture"]).stdout.strip()
    if arch != host_arch:
        raise ValueError(f"Dependency scanning requires a {arch} host, found {host_arch}.")
    info = json.loads((bundle / "data/flutter_assets/version.json").read_text())
    version = f'{info["version"]}-{info.get("build_number") or "1"}'
    run(["dpkg", "--validate-version", version])
    epoch = int(run(["git", "log", "-1", "--format=%ct"], cwd=ROOT).stdout.strip())
    output.mkdir(parents=True, exist_ok=True)
    package_file = output / f"{PACKAGE}_{version}_{arch}.deb"
    with tempfile.TemporaryDirectory(prefix=".deb-stage-", dir=output) as temp:
        workspace = Path(temp)
        stage = workspace / "root"
        application = stage / "usr/lib" / PACKAGE
        shutil.copytree(bundle, application, symlinks=True)
        (stage / "DEBIAN").mkdir()
        write(stage / "usr/bin" / PACKAGE,
              '#!/bin/sh\nexec "/usr/lib/reisub-meeting/REISUB Meeting" "$@"\n', 0o755)
        write(stage / f"usr/share/applications/{APP_ID}.desktop", f"""[Desktop Entry]
Type=Application
Name=REISUB Meeting
GenericName=Video Conferencing
GenericName[tr]=Görüntülü Toplantı
Comment=Connect to your REISUB Meeting server
Comment[tr]=REISUB Meeting sunucunuza bağlanın
Exec={PACKAGE}
TryExec={PACKAGE}
Icon={APP_ID}
Terminal=false
Categories=Network;VideoConference;
StartupNotify=true
StartupWMClass={APP_ID}
""")
        for size, source in {
            48: "android/app/src/main/res/mipmap-mdpi/ic_launcher.png",
            96: "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png",
            192: "web/icons/Icon-192.png",
            512: "web/icons/Icon-512.png",
        }.items():
            destination = stage / f"usr/share/icons/hicolor/{size}x{size}/apps/{APP_ID}.png"
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / source, destination)
        docs = stage / "usr/share/doc" / PACKAGE
        write(docs / "copyright", (ROOT / "LICENSE").read_text())
        write(docs / "README", "REISUB Meeting\n\n"
              "Start from your application menu or run reisub-meeting.\n"
              "Enter the address and port of your REISUB Meeting server.\n"
              "The server is not included in this desktop client package.\n\n"
              "Built from the supplied Linux release bundle. System library\n"
              "requirements are detected from its ELF binaries; older Linux\n"
              "releases may not provide the required versions.\n")
        changelog = (f"{PACKAGE} ({version}) stable; urgency=medium\n\n"
                     "  * Package the REISUB Meeting Linux release.\n\n"
                     f" -- {MAINTAINER}  "
                     + run(["date", "-u", "-R", "--date", f"@{epoch}"]).stdout.strip() + "\n")
        (docs / "changelog.Debian.gz").write_bytes(gzip.compress(changelog.encode(), mtime=0))
        control = (f"Package: {PACKAGE}\nVersion: {version}\nSection: net\n"
                   f"Priority: optional\nArchitecture: {arch}\nMaintainer: {MAINTAINER}\n"
                   f"Homepage: {HOMEPAGE}\n"
                   "Description: REISUB Meeting video conferencing client\n"
                   " Open-source Flutter client for video meetings, chat and screen sharing.\n"
                   " A separate REISUB Meeting server is required.\n")
        write(stage / "DEBIAN/control", control)
        write(workspace / "debian/control",
              f"Source: {PACKAGE}\nSection: net\nPriority: optional\n"
              f"Maintainer: {MAINTAINER}\n\n{control}")
        libraries = application / "lib"
        elf_files = [application / executable.name, *sorted(libraries.glob("*.so"))]
        scan = run(["dpkg-shlibdeps", "-O", "--ignore-missing-info",
                    f"-l{libraries}", f"-S{stage}",
                    *[f"-e{path}" for path in elf_files]], cwd=workspace)
        # Only bundled Flutter/plugin libraries lack Debian shlibs metadata.
        # Missing system libraries still make dpkg-shlibdeps fail.
        if scan.stderr:
            print(scan.stderr.strip())
        depends = next(line.removeprefix("shlibs:Depends=")
                       for line in scan.stdout.splitlines() if line.startswith("shlibs:Depends="))
        if not depends:
            raise RuntimeError("No system dependencies were detected.")
        for directory in [stage, *stage.rglob("*")]:
            if directory.is_symlink():
                continue
            directory.chmod(0o755 if directory.is_dir() else 0o644)
        (application / executable.name).chmod(0o755)
        (stage / "usr/bin" / PACKAGE).chmod(0o755)
        payload = sorted(path for path in (stage / "usr").rglob("*")
                         if path.is_file() and not path.is_symlink())
        installed_size = math.ceil(sum(path.stat().st_size for path in payload) / 1024)
        write(stage / "DEBIAN/control", control
              + f"Depends: {depends}\nInstalled-Size: {installed_size}\n")
        write(stage / "DEBIAN/md5sums", "".join(
            f"{hashlib.md5(path.read_bytes()).hexdigest()}  {path.relative_to(stage).as_posix()}\n"
            for path in payload))
        desktop = stage / f"usr/share/applications/{APP_ID}.desktop"
        if shutil.which("desktop-file-validate"):
            run(["desktop-file-validate", str(desktop)])
        run(["sh", "-n", str(stage / "usr/bin" / PACKAGE)])
        for path in [*stage.rglob("*"), stage]:
            if not path.is_symlink():
                os.utime(path, (epoch, epoch))
        built = workspace / package_file.name
        env = dict(os.environ, SOURCE_DATE_EPOCH=str(epoch))
        run(["dpkg-deb", "--root-owner-group", "-Zxz", "-z6", "--build",
             str(stage), str(built)], env=env)
        built.replace(package_file)
    write(output / "SHA256SUMS", "".join(
        f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n"
        for path in sorted(output.glob("*.deb"))))
    print(f"Created: {package_file}")
    print(f"Size: {package_file.stat().st_size / 1024 / 1024:.1f} MiB")
    print(f"Dependencies: {depends}")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.stderr or error.stdout or str(error)) from error
