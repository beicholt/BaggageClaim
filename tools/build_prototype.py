#!/usr/bin/env python3
"""Inline three.js and every generated PNG into a single openable prototype.

    python3 tools/build_prototype.py

Reads prototype/carousel3d.src.html and writes prototype/carousel3d.html.

The inlining is not a size optimisation, it is the only way the file runs off a
phone. Browsers treat every file:// URL as its own opaque origin, so a texture
uploaded from a sibling PNG taints the WebGL context and throws — the game would
boot to a black belt. Data URIs are same-origin, so the built file works from a
filesystem, an AirDrop, a static host or an iframe with no server anywhere.

Assets that have not been generated yet are simply skipped; the prototype falls
back to its procedural art for those, so this is always safe to run.
"""

import base64
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "prototype" / "carousel3d.src.html"
OUT = ROOT / "prototype" / "carousel3d.html"
THREE = ROOT / "prototype" / "vendor" / "three.global.js"
ASSET_DIR = ROOT / "assets"
SPEC = ROOT / "tools" / "assets.json"


def as_script(js):
    """Embed JS in an inline <script>. `</script` inside a string literal would
    close the tag early, so break it the way the HTML spec expects."""
    return "<script>\n" + js.replace("</script", "<\\/script") + "\n</script>"


def main():
    if not SRC.exists():
        sys.exit(f"missing {SRC.relative_to(ROOT)}")
    if not THREE.exists():
        sys.exit(f"missing {THREE.relative_to(ROOT)} — see prototype/vendor/README.md")

    html = SRC.read_text()

    tag = '<script src="vendor/three.global.js"></script><!-- @@THREE@@ -->'
    if tag not in html:
        sys.exit("three.js script tag marker not found in the source")
    html = html.replace(tag, as_script(THREE.read_text()))

    wanted = [a["id"] for a in json.loads(SPEC.read_text())["assets"]]
    inline, missing, total = {}, [], 0
    for asset_id in wanted:
        png = ASSET_DIR / f"{asset_id}.png"
        if not png.exists():
            missing.append(asset_id)
            continue
        raw = png.read_bytes()
        total += len(raw)
        inline[asset_id] = "data:image/png;base64," + base64.b64encode(raw).decode()

    line = re.compile(r"^.*// @@ASSETS@@.*$", re.M)
    if not line.search(html):
        sys.exit("asset marker not found in the source")
    html = line.sub(
        "  const INLINE_ASSETS = " + json.dumps(inline) + "; // @@ASSETS@@",
        html, count=1)

    OUT.write_text(html)
    size = OUT.stat().st_size
    print(f"{OUT.relative_to(ROOT)}  {size / 1048576:.2f} MB")
    print(f"  three.js inlined, {len(inline)}/{len(wanted)} assets "
          f"({total / 1048576:.2f} MB of PNG)")
    if missing:
        print("  procedural fallback still in use for: " + ", ".join(missing))


if __name__ == "__main__":
    main()
