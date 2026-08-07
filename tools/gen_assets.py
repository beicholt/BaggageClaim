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
import colorsys
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
# Seeding from the border is not the safeguard it looks like: the antialiased rim
# is a continuous ramp from backdrop to subject, so any tolerance wide enough to
# span that ramp lets the fill walk straight into the bag. At 78 it ate most of
# the mustard suitcase and the teal guitar case, whose colours sit ~75 from the
# green field. Keep this tight enough that the ramp stops it.
CHROMA_TOL = 40

# The backdrop also carries a contact shadow, too dark for CHROMA_TOL but the same
# hue, which survives as a green blob under the bag. A second pass takes anything
# that shares the backdrop's hue and is darker than it — correct for a shadow,
# wrong for a subject painted in the backdrop's own hue, which is what
# "shadow": false in assets.json is for.
SHADOW_HUE_TOL = 0.055   # fraction of the hue circle
SHADOW_MIN_SAT = 0.08    # below this it is a grey, not the tinted backdrop

# Backdrop the border fill cannot reach, because the subject encloses it. Tighter
# than CHROMA_TOL: this test is not anchored to the border, so it is the only
# thing standing between a subject's midtones and a hole punched through them.
HOLE_TOL = 28


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

def key_out_background(img, shadow=True):
    """Flood-fill the chroma backdrop away, starting from the frame border.

    Seeding from the border rather than keying globally is what lets a bag keep
    a colour the backdrop also contains — but only as far as CHROMA_TOL stays
    narrower than the antialiased rim, or the fill crosses it and keeps going.

    `shadow` adds the hue-matched second pass that lifts the contact shadow.
    Turn it off for a subject painted in the backdrop's own hue.
    """
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    kr = sum(c[0] for c in corners) // 4
    kg = sum(c[1] for c in corners) // 4
    kb = sum(c[2] for c in corners) // 4
    tol2 = CHROMA_TOL * CHROMA_TOL
    k_hue, k_light, _ = colorsys.rgb_to_hls(kr / 255, kg / 255, kb / 255)

    def is_shadow(r, g, b):
        hue, light, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        drift = abs(hue - k_hue)
        return (min(drift, 1 - drift) <= SHADOW_HUE_TOL
                and light < k_light and sat > SHADOW_MIN_SAT)

    def is_bg(x, y):
        r, g, b, _ = px[x, y]
        if (r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2 <= tol2:
            return True
        return shadow and is_shadow(r, g, b)

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

    # The border fill cannot reach backdrop it does not touch — the gap under a
    # handle, the triangle inside a strap — so those survive as green patches
    # welded to the bag. Sweep them separately, on a tolerance tight enough that
    # only the flat field qualifies and no part of a subject does.
    hole_tol2 = HOLE_TOL * HOLE_TOL
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx]:
                continue
            r, g, b, _ = px[sx, sy]
            if (r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2 > hole_tol2:
                continue
            blob = [(sx, sy)]
            seen[sy * w + sx] = 1
            hq = deque(blob)
            while hq:
                x, y = hq.popleft()
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if not (0 <= nx < w and 0 <= ny < h) or seen[ny * w + nx]:
                        continue
                    r, g, b, _ = px[nx, ny]
                    if (r - kr) ** 2 + (g - kg) ** 2 + (b - kb) ** 2 <= hole_tol2:
                        seen[ny * w + nx] = 1
                        blob.append((nx, ny))
                        hq.append((nx, ny))

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
        img = key_out_background(img, shadow=spec.get("shadow", True))
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
