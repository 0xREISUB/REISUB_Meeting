"""Build settings shared by the build tools.

Values come from, in order of precedence: environment variables, .env (local
and secret, ignored by git) and app.env (public defaults, committed).
"""

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _read(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key.strip()] = value
    return values


def load() -> dict[str, str]:
    values = _read(ROOT / "app.env")
    values.update(_read(ROOT / ".env"))
    values.update({k: v for k, v in os.environ.items() if k.startswith("REISUB_")})
    return values


def require(values: dict[str, str], key: str) -> str:
    value = values.get(key, "").strip()
    if not value:
        raise SystemExit(f"{key} is not set; see app.env")
    return value
