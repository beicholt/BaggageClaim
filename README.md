# Brainstorm

Ideas.

## Carousel

An iPhone puzzle game: baggage claim, but a puzzle. Bags loop endlessly around an
airport carousel, your claim tray holds seven, three matching bags send a traveler
home. The twist that separates it from triple-match: **the loop forgives** — a bag
you skip comes back around, so a wrong tap costs time, never the run.

- [`concepts/carousel.md`](concepts/carousel.md) — full concept: rules, onboarding,
  the level generator, content roadmap, monetization, build plan, and the CPI gate
  that decides whether it's worth building.
- [`prototype/carousel3d.html`](prototype/carousel3d.html) — the playable
  prototype. A real 3D baggage hall: the carousel is geometry, the claim zone is
  a light, and the apron outside the window has traffic on it. Open it on a
  phone; everything is inlined, so it needs no server.
- [`prototype/carousel.html`](prototype/carousel.html) — the earlier flat build,
  kept as a reference for the rules. Same game, drawn in 2D canvas.

### Art

Art is generated from the Gemini image API and committed, not hand-drawn.

```sh
export GEMINI_API_KEY=…
python3 tools/gen_assets.py        # writes assets/*.png + assets/manifest.json
python3 tools/build_prototype.py   # inlines three.js + the PNGs into the prototype
```

[`tools/assets.json`](tools/assets.json) is the whole art direction — one prompt
per asset plus a shared style block, so the set stays coherent and any single
piece can be re-rolled without touching the others.

Both steps are safe to run at any time. `gen_assets.py` caches raw returns under
`assets/_raw/` and only re-runs the cheap post-processing, and the prototype
falls back to procedural vector art for anything not generated yet — so a fresh
clone with an empty `assets/` still builds and plays.
