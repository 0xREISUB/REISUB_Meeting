#!/usr/bin/env python3
"""Build the web client and fill the invite page with the settings from
app.env / .env / the environment.

    python3 tool/build_web.py [extra flutter build web arguments]

Only REISUB_WEB_SERVER_URL is passed into the Dart code, so secrets in .env
never end up in the published JavaScript.
"""

import html
import subprocess
import sys

import app_env

INVITE_PAGE = app_env.ROOT / "build/web/invite/index.html"
PLACEHOLDERS = {
    "__REISUB_DOWNLOAD_URL__": "REISUB_DOWNLOAD_URL",
    "__REISUB_SOURCE_URL__": "REISUB_SOURCE_URL",
    "__REISUB_SERVER_URL__": "REISUB_SERVER_URL",
}


def main() -> None:
    values = app_env.load()
    command = ["flutter", "build", "web", "--release"]
    web_server = values.get("REISUB_WEB_SERVER_URL", "").strip()
    if web_server:
        command.append(f"--dart-define=REISUB_WEB_SERVER_URL={web_server}")
    subprocess.run(command + sys.argv[1:], cwd=app_env.ROOT, check=True)

    page = INVITE_PAGE.read_text(encoding="utf-8")
    for placeholder, key in PLACEHOLDERS.items():
        page = page.replace(placeholder, html.escape(values.get(key, "").strip()))
    INVITE_PAGE.write_text(page, encoding="utf-8")
    print(f"Invite page configured: {INVITE_PAGE.relative_to(app_env.ROOT)}")


if __name__ == "__main__":
    main()
