#!/usr/bin/env python3
"""Copy generated PNGs into the app's asset catalog.

    python3 tools/sync_assets.py

assets/ is the output of the generator and the thing worth reviewing in a diff.
Carousel/Assets.xcassets is what Xcode compiles. Keeping them separate means a
re-roll of one sprite does not churn the catalog, and the catalog never becomes
the place art quietly diverges.

Safe to run at any time: it only writes when the bytes actually differ.
"""

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "tools" / "assets.json"
SRC = ROOT / "assets"
CATALOG = ROOT / "Carousel" / "Assets.xcassets"


def contents_for(asset_id):
    return {
        "images": [{"filename": f"{asset_id}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }


def main():
    if not CATALOG.exists():
        sys.exit(f"missing {CATALOG.relative_to(ROOT)}")

    wanted = [a["id"] for a in json.loads(SPEC.read_text())["assets"]]
    written, missing = 0, []

    for asset_id in wanted:
        src = SRC / f"{asset_id}.png"
        if not src.exists():
            missing.append(asset_id)
            continue

        dest_dir = CATALOG / f"{asset_id}.imageset"
        dest_dir.mkdir(exist_ok=True)
        dest = dest_dir / f"{asset_id}.png"

        if not dest.exists() or dest.read_bytes() != src.read_bytes():
            shutil.copy(src, dest)
            written += 1

        meta = dest_dir / "Contents.json"
        body = json.dumps(contents_for(asset_id), indent=2) + "\n"
        if not meta.exists() or meta.read_text() != body:
            meta.write_text(body)

    print(f"{written} updated, {len(wanted) - len(missing)} in catalog"
          + (f", {len(missing)} not generated yet: {', '.join(missing)}" if missing else ""))


if __name__ == "__main__":
    main()
