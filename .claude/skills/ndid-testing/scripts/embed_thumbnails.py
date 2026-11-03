"""Replace {{screen_name}} placeholders in a report HTML with JPEG data-URI thumbnails.

Usage (from the repo root):
    python3 .claude/skills/ndid-testing/scripts/embed_thumbnails.py in.html out.html [--screens docs/screens]

Each placeholder name must match a PNG in the screens dir, e.g. {{a1_welcome}} -> docs/screens/a1_welcome.png.
Thumbnails are 216x480 JPEG q72 (~12 KB each), so the page stays small.
"""
import argparse
import base64
import io
import pathlib
import re
import sys

from PIL import Image


def thumb(path: pathlib.Path) -> str:
    im = Image.open(path).convert("RGB").resize((216, 480), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=72, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--screens", default="docs/screens")
    args = ap.parse_args()

    html = pathlib.Path(args.src).read_text(encoding="utf-8")
    screens = pathlib.Path(args.screens)
    cache: dict[str, str] = {}
    missing: set[str] = set()

    def sub(m: re.Match) -> str:
        name = m.group(1)
        png = screens / f"{name}.png"
        if not png.exists():
            missing.add(name)
            return m.group(0)
        if name not in cache:
            cache[name] = thumb(png)
        return cache[name]

    out = re.sub(r"\{\{(\w+)\}\}", sub, html)
    if missing:
        print("missing screenshots: " + ", ".join(sorted(missing)), file=sys.stderr)
        return 1
    pathlib.Path(args.dst).write_text(out, encoding="utf-8")
    print(f"wrote {args.dst} ({len(out) // 1024} KB, {len(cache)} thumbnails)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
