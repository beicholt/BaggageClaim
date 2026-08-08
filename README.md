# Carousel

An iPhone puzzle game: baggage claim, but a puzzle. Bags loop endlessly around an
airport carousel, your claim tray holds seven, three matching bags send a traveler
home. The twist that separates it from triple-match: **the loop forgives** — a bag
you skip comes back around, so a wrong tap costs time, never the run.

[`concepts/carousel.md`](concepts/carousel.md) is the spec: what has been decided,
the rules, and what is still open. Read it before proposing anything.

## The app

`Carousel.xcodeproj` — the real thing, a native iPhone app in SpriteKit. iOS 17+,
portrait only.

```sh
open Carousel.xcodeproj          # or build from the command line:
xcodebuild -project Carousel.xcodeproj -scheme Carousel \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

The camera never moves, so the hall is not 3D at runtime: the loop is projected
once through a fixed perspective ([`Projection.swift`](Carousel/Game/Projection.swift))
and filled as flat shapes. Everything is still measured in world units, so a level
is the same level on every phone.

The rules live in [`GameState.swift`](Carousel/Game/GameState.swift) and know
nothing about SpriteKit. That is deliberate — it is what lets them be checked
without a screen:

```sh
tools/rules_check.sh             # runs the rules headless on the simulator
```

Three environment switches exist purely so the game can be QA'd without playing
it to the point in question:

| | |
|---|---|
| `CAROUSEL_FREEZE=1` | Stops the belt and the clock, so the same bag is still under the same pixel a moment later. |
| `CAROUSEL_LEVEL=n` | Drops straight into belt *n*. Oversized bags do not appear until belt three. |
| `CAROUSEL_CARD=won\|jammed\|boarded` | Puts an end-of-level card on screen. Otherwise reachable only by playing a whole belt out. |

```sh
SIMCTL_CHILD_CAROUSEL_FREEZE=1 SIMCTL_CHILD_CAROUSEL_LEVEL=9 \
  xcrun simctl launch booted com.beicholtz.carousel
```

## Art

Art is generated from the Gemini image API and committed, not hand-drawn.

```sh
export GEMINI_API_KEY=…
python3 tools/gen_assets.py      # writes assets/*.png + assets/manifest.json
```

[`tools/assets.json`](tools/assets.json) is the whole art direction — one prompt
per asset plus a shared style block, so the set stays coherent and any single
piece can be re-rolled without touching the others. Generation is the expensive,
non-deterministic step, so raw returns are cached under `assets/_raw/` and the
cheap post-processing re-runs every time; retuning the chroma key costs nothing.

Copy new or changed assets into the app's catalog before building:

```sh
python3 tools/sync_assets.py     # assets/*.png -> Carousel/Assets.xcassets
```

## The web prototype

Kept because it is where the design was proven, and because it is the only build
that runs without Xcode. It is **not** the product.

- [`prototype/carousel3d.html`](prototype/carousel3d.html) — real 3D, three.js,
  everything inlined so it opens on a phone with no server.
- [`prototype/carousel.html`](prototype/carousel.html) — the earlier flat 2D
  build, kept as the smaller thing to read when checking what a rule does.

```sh
python3 tools/build_prototype.py # inlines three.js + the PNGs into carousel3d.html
```
