#!/usr/bin/env python3
"""Generate the game's art from the Gemini image API.

    export GEMINI_API_KEY=...
    python3 tools/gen_assets.py               # everything that isn't on disk yet
    python3 tools/gen_assets.py --only bag_   # id prefix filter
    python3 tools/gen_assets.py --force       # regenerate even if it exists
    python3 tools/gen_assets.py --dry-run     # print the prompts, call nothing

Generation is the expensive, non-deterministic step, so the raw returns are kept
in assets/_raw/ and never overwritten unless you ask. Post-processing — chroma
key, trim, resize — is cheap and re-runs every time, so you can retune the keying
without paying for the image again.

Everything it writes lands in assets/ and is committed: the container this runs
in is ephemeral, the art is not.
"""

import argparse
import base64
import io
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "tools" / "assets.json"
ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

# How far a pixel may drift from the backdrop colour and still count as backdrop.
# Generous, because the model never returns a perfectly flat field — but the fill
# is seeded from the border only, so a matching colour inside the subject is safe.
CHROMA_TOL = 78


# ── the API ─────────────────────────────────────────────────────

def _ssl_context():
    bundle = os.environ.get("SSL_CERT_FILE") or "/root/.ccr/ca-bundle.crt"
    if Path(bundle).exists():
        return ssl.create_default_context(cafile=bundle)
    return ssl.create_default_context()


def generate(model, prompt, api_key, aspect=None, attempts=4):
    """One prompt in, PNG bytes out. Retries transient failures with backoff."""
    body = {"contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseModalities": ["IMAGE"]}}
    if aspect:
        body["generationConfig"]["imageConfig"] = {"aspectRatio": aspect}

    ctx = _ssl_context()
    last = None
    for attempt in range(attempts):
        req = urllib.request.Request(
            ENDPOINT.format(model=model),
            data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
        )
        try:
            with urllib.request.urlopen(req, timeout=180, context=ctx) as r:
                payload = json.load(r)
            for part in payload["candidates"][0]["content"]["parts"]:
                if "inlineData" in part:
                    return base64.b64decode(part["inlineData"]["data"])
            # A text-only answer means the prompt tripped a filter. Retrying an
            # identical prompt won't help, so say what came back and stop.
            said = " ".join(p.get("text", "") for p in
                            payload["candidates"][0]["content"]["parts"])
            raise RuntimeError(f"no image returned; model said: {said.strip()[:300]}")
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")[:300]
            last = RuntimeError(f"HTTP {e.code}: {detail}")
            # An unsupported imageConfig is a hard 400 — drop it and try again
            # rather than burning the remaining attempts on the same request.
            if e.code == 400 and "imageConfig" in detail and aspect:
                body["generationConfig"].pop("imageConfig", None)
                aspect = None
                continue
            if e.code not in (408, 429, 500, 502, 503, 504):
                raise last
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            last = RuntimeError(f"network: {e}")
        if attempt < attempts - 1:
            time.sleep(2 ** attempt * 2)
    raise last


# ── post-processing ─────────────────────────────────────────────

def key_out_background(img):
    """Flood-fill the chroma backdrop away, starting from the frame border.

    Seeding from the border rather than keying globally is the whole point: the
    olive medical case and the pink garment bag would lose chunks of themselves
    to a naive colour key, but nothing inside a bag connects to the edge.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    kr = sum(c[0] for c in corners) // 4
    kg = sum(c[1] for c in corners) // 4
    kb = sum(c[2] for c in corners) // 4
    tol2 = CHROMA_TOL * CHROMA_TOL

    def is_bg(x, y):
        r, g, b, _ = px[x, y]
        return (r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2 <= tol2

    seen = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not seen[y * w + x] and is_bg(x, y):
                seen[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not seen[y * w + x] and is_bg(x, y):
                seen[y * w + x] = 1
                q.append((x, y))

    while q:
        x, y = q.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and is_bg(nx, ny):
                seen[ny * w + nx] = 1
                q.append((nx, ny))

    alpha = Image.frombytes("L", (w, h), bytes(255 if not s else 0 for s in seen))
    # Chroma bleeds a green rim into the antialiased edge. Pulling the matte in
    # by a pixel eats the fringe; the blur then puts a soft edge back.
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))

    out = img.copy()
    out.putalpha(alpha)
    # Unmix the leftover backdrop tint from pixels that are now partly transparent.
    return Image.alpha_composite(Image.new("RGBA", (w, h), (0, 0, 0, 0)), out)


def trim_to_alpha(img, pad=2):
    box = img.getbbox()
    if not box:
        return img
    x0, y0, x1, y1 = box
    return img.crop((max(0, x0 - pad), max(0, y0 - pad),
                     min(img.width, x1 + pad), min(img.height, y1 + pad)))


def fit(img, width=None, height=None):
    if not width and not height:
        return img
    if width and height:
        size = (width, height)
    elif height:
        size = (max(1, round(img.width * height / img.height)), height)
    else:
        size = (width, max(1, round(img.height * width / img.width)))
    return img.resize(size, Image.LANCZOS)


def post(raw_bytes, spec):
    img = Image.open(io.BytesIO(raw_bytes))
    if spec.get("alpha") == "chroma":
        img = key_out_background(img)
        if spec.get("trim", True):
            img = trim_to_alpha(img)
    else:
        img = img.convert("RGB")
    return fit(img, spec.get("width"), spec.get("height"))


# ── driver ──────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="only ids starting with this")
    ap.add_argument("--force", action="store_true", help="regenerate, don't reuse assets/_raw")
    ap.add_argument("--dry-run", action="store_true", help="print prompts, call nothing")
    ap.add_argument("--model", default=None)
    args = ap.parse_args()

    spec = json.loads(SPEC.read_text())
    model = args.model or spec["model"]
    out_dir = ROOT / spec["outDir"]
    raw_dir = out_dir / "_raw"
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_dir.mkdir(exist_ok=True)

    wanted = [a for a in spec["assets"] if a["id"].startswith(args.only)]
    if not wanted:
        sys.exit(f"no asset id starts with {args.only!r}")

    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key and not args.dry_run:
        sys.exit("set GEMINI_API_KEY (or GOOGLE_API_KEY) first")

    manifest, failed = {}, []
    for a in wanted:
        prompt = f'{spec["styles"][a["style"]]}\n\nSubject: {a["prompt"]}'
        if args.dry_run:
            print(f"\n=== {a['id']} ===\n{prompt}")
            continue

        raw_path = raw_dir / f"{a['id']}.png"
        try:
            if raw_path.exists() and not args.force:
                raw = raw_path.read_bytes()
                print(f"{a['id']:22s} reusing raw")
            else:
                print(f"{a['id']:22s} generating…", flush=True)
                raw = generate(model, prompt, api_key, a.get("aspect"))
                raw_path.write_bytes(raw)

            img = post(raw, a)
            dest = out_dir / f"{a['id']}.png"
            img.save(dest, "PNG", optimize=True)
            manifest[a["id"]] = {
                "file": dest.name, "w": img.width, "h": img.height,
                "alpha": a.get("alpha") == "chroma",
            }
            print(f"{a['id']:22s} → {dest.name}  {img.width}×{img.height}  "
                  f"{dest.stat().st_size // 1024}kB")
        except Exception as e:  # one bad asset shouldn't abandon the other 18
            failed.append(a["id"])
            print(f"{a['id']:22s} FAILED: {e}", file=sys.stderr)

    if args.dry_run:
        return

    # Merge, so regenerating a single asset doesn't drop the rest of the manifest.
    man_path = out_dir / "manifest.json"
    existing = json.loads(man_path.read_text()) if man_path.exists() else {}
    existing.update(manifest)
    man_path.write_text(json.dumps(existing, indent=2, sort_keys=True) + "\n")
    print(f"\n{len(manifest)} written, {len(failed)} failed"
          + (f": {', '.join(failed)}" if failed else ""))
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
