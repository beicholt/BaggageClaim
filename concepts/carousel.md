# CAROUSEL *(working name — see Naming)*

*Baggage claim, but it's a puzzle.*

Bags loop endlessly around an airport carousel. You can only grab the ones
passing through the lit zone in front of you, and your claim tray holds seven.
Three matching bags send a traveler home. Jam the tray, or miss the flight, and
the run is over.

---

## About this document

The first version of this doc was written by Claude from a one-line prompt and
was mostly invented — a business plan, a $300 ad test, retention targets, a
Unity build plan, a season pass. None of that came from Brian, so it is gone.

Everything under **Decisions** was decided by Brian on 2026-08-07. Everything
under **Design** is reasoning that survived him actually playing the prototype
and saying the core felt right. Everything under **Open** is not decided yet.

---

## Decisions

| | |
|---|---|
| **What it is** | A real product, submitted to the App Store. |
| **Who it's for** | Adults, casual. The people who play Parking Jam or Water Sort on the couch. Not a kids' app. |
| **Platform** | Native iPhone app, built in SpriteKit — the same stack as Tide Pools. iOS only for v1; no Android. |
| **Structure** | Numbered levels. 1, 2, 3, a screen showing progress. |
| **Difficulty** | Waves. Climbs for a stretch, peaks, eases off, climbs again. No unbroken ramp. |
| **Lives** | None. Play as long as you like. The ad break every few levels is the only pause. |
| **Money** | Free with ads. |
| **Power-ups** | Three, each earned by watching an ad: slow the belt, two extra tray slots, sweep one type. |
| **v1 scope** | One airport, ~40 levels, the three power-ups, ads working, everything polished. |
| **Target** | Live in the App Store around **early November 2026**. |
| **Pace** | A few hours a week, steady. |

### How the ads work

- **Rewarded** — the player chooses to watch, in exchange for a power-up or a
  second chance after failing. This is the main channel.
- **A break every third level or so** — short, skippable, hard-capped, and
  **never immediately after a loss.** That is the moment goodwill dies.
- **No banner.** The tray already fights for the bottom of the screen.

No lives means no energy timer to sell, so the whole business rests on players
*wanting* the continue. That is an argument for keeping the core forgiving,
which it already is.

### Who does what

Brian makes the product, design and feel calls, does the acceptance testing on
every build, and reports what is wrong. Claude writes all the code, proposes
ways to scale it out, and walks Brian through App Store submission at the end.
Solo testing for now; other people get builds once it is worth their time.

---

## Design

### The three pillars

1. **One verb.** Tap a bag. No dragging, no aiming, no two-finger anything.
   Playable one-thumbed on a train.
2. **The belt is the constraint.** You can only claim from a lit zone at the
   bottom of the loop — roughly a fifth of it. Everything else is visible but
   out of reach. So every bag entering the zone is a decision: take it now, or
   wait a full lap. That decision, made 60 times a minute, *is* the game.
3. **The loop forgives, but it charges.** A skipped bag is never lost — it
   comes back. Wrong taps cost time and tray space, never an instant dead end.
   The clock stops "wait for perfect" from being free.

### Rules

| | |
|---|---|
| **Belt** | A closed loop carrying every bag in the level. Constant speed. |
| **Zones** | Behind the wall: hidden. The long sides: visible, out of reach — you plan here. The lit claim zone: the only place you can take a bag. |
| **Tray** | 7 slots at the bottom. Auto-groups matching bags side by side. |
| **Claim** | Tap a bag *inside the lit zone* → it flies to the tray. |
| **Match** | 3 identical bags in the tray → they pop, the slots free up, score. |
| **Oversized** | Skis, surfboards, guitars take **2 slots** instead of 1. |
| **Clock** | The flight departs. Roughly enough laps to clear the belt playing well, not enough to dither. |
| **Win** | Belt is empty. |
| **Lose** | Tray is full with no match available, or the flight boards. |

Scoring is a **flow meter**, not a point total: pop within 4 seconds of your
last pop and the multiplier climbs (×1 → ×2 → ×3 → ×5). Let it lapse and it
resets. Everyone can clear a level; only good players clear it *hot*.

### Two traps the prototype already fell into

Worth keeping written down, because neither is obvious until you hold it.

**Free choice kills the game.** The first build let you tap any bag anywhere on
the belt. It played terribly: with free choice over every bag there is no
decision to get wrong, and the belt becomes decoration. The claim zone is what
makes choice scarce; the clock is what makes waiting cost something.

**Fewer than four types cannot be lost.** You can hold at most two unmatched
bags of each type before the third pops, so with `T` types in play the most you
can ever hold is `2T` slots. With a seven-slot tray and three types that is
six — the level is unloseable in any order. Reach four types by level two.

### What legibility costs, and where difficulty has to come from

Bags are drawn facing the camera but spaced along the belt, so the two side
runs — where the belt travels away from you — buy almost no separation per unit
of belt. Spacing is now paid in that local currency, which means **a belt holds
noticeably fewer bags than the arclength suggests**, and later belts hold fewer
than the first version of this doc assumed.

That is the right trade, and it moves where difficulty comes from. It cannot
come from crowding the belt. It has to come from the claim zone, the clock, and
the number of *types* in play — which was already the argument: bag count and
speed change the texture, the zone and the clock change the decision.

### One rule governs all content

**A bag the player can see must be a bag the player can hit.** Difficulty comes
from scarcity of choice — the zone, the clock, the tray — never from an
unreliable tap. Bags are packed by their drawn widths with clear belt between
neighbours, and a level sheds a matched set rather than crowd the loop past
what fits legibly.

### First 60 seconds

No tutorial text, no hand pointing at the screen.

- **0:00** — Three bags, all identical, moving slowly. The claim zone is the
  only lit thing on screen, so that is where the player looks and taps.
- **0:06** — Third tap. The triple pops with a burst and a chime. Now they know
  the rule and where they can reach.
- **0:14** — A bag drifts past unclaimed and dims. Fifteen seconds later it
  comes back — skipping is survivable, but slow.
- **0:30** — Level 2: four types. First level where a jam is possible at all.
- **0:55** — Level 3 adds an oversized bag. The tray now has a shape, not just
  a count.

---

## Art direction

**Stylized, never photographic.** The bag sprites set the style for everything:
clean stylized 3D render, matte materials, simple chunky forms, no fine detail.
Backgrounds match them. The first pass got this wrong — the layer prompts asked
for a "cinematic matte painting" with "colours slightly desaturated and cool",
which produced a photoreal airfield that clashed with every bag on the belt.

**Bright daylight.** The hall is lit like midday, not midnight. Light floors and
walls, a genuinely blue sky through the glass. The belt stays dark on purpose —
it is the one thing the bags are read against, and a light belt leaves the pale
ones floating. The claim zone is warm near-white light *added* to that dark
belt; a saturated amber painted over slate comes out mustard and reads as a mat
rather than a spotlight.

**Colour, not rainbow.** Saturated and warm, not a kids' primary palette.

**No ambient animation.** Nothing moves but the belt, the bags and the tray. The
window is a still view.

**More bags, more sizes.** The roster needs to grow well past ten, across small,
standard and oversized, so a forty-level game does not repeat itself.

The whole room is flat shapes in [`Palette.swift`](../Carousel/Game/Palette.swift)
and [`HallNode.swift`](../Carousel/Game/HallNode.swift), because the camera never
moves. It can be replaced with a single rendered backdrop later without touching
the game.

Assets are generated, not commissioned: `tools/assets.json` holds one prompt
per asset plus a shared style block, `tools/gen_assets.py` renders them through
the Gemini image API and keys out the backdrop. That is how the roster grows
cheaply, and it is why the style stays consistent as it does.

---

## Naming

**Carousel is a placeholder and probably not the name.** Brian wants help
finding one that is not already taken on the App Store. Not urgent — the store
listing is a late step — but it needs doing before submission.

---

## Open

- The name.
- Which airport v1 is set in, and what that does to the look.
- The full bag roster for forty levels — how many types, what mix of sizes.
- Which bag *behaviours* make it into v1, if any, beyond oversized.
- Which ad network. Decided when the Apple account exists and ads get wired up.

---

## Status

- `prototype/carousel3d.html` — the playable web prototype. Real 3D hall,
  generated art, endless generated levels. Open it on a phone; everything is
  inlined, so it needs no server. **This is the reference build, not the
  product** — the iPhone version replaces it.
- `prototype/carousel.html` — the earlier flat 2D build, kept only as the
  smaller thing to read when checking what a rule does.
- Apple Developer Program membership: Brian is getting it in August 2026.
