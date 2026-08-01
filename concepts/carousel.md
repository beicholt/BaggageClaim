# CAROUSEL

*Baggage claim, but it's a puzzle.*

**One-liner:** Bags loop endlessly around an airport carousel. You can only grab
the ones passing through the lit zone in front of you, and your claim tray holds
seven. Three matching bags send a traveler home. Jam the tray, or miss the flight,
and the run is over.

---

## Why this one

Every hit in this category is a familiar physical annoyance turned into a toy.
Parking Jam is the blocked-in parking lot. Screw Jam is the flat-pack furniture.
Water Sort is the paint tin. The fantasy has to be recognizable in half a second,
from a 4-second ad creative, with no text.

A baggage carousel is one of the most universally understood images there is, and
it already *is* a machine that presents you with a stream of choices you can't
control. It ships with built-in tension (that bag is going away), built-in relief
(it comes back), and built-in theming (every airport on earth is a level pack).

### The three pillars

1. **One verb.** Tap a bag. That's the entire input. No dragging, no aiming, no
   two-finger anything. Playable one-thumbed on a train.
2. **The belt is the constraint.** You can only claim from a lit zone at the bottom
   of the loop — roughly a fifth of it. Everything else is visible but out of reach.
   So every bag that enters the zone is a decision: take it now, or wait a full lap.
   That decision, made 60 times a minute, *is* the game.
3. **The loop forgives, but it charges.** A bag you skip is never lost — it comes
   back. Wrong taps cost time and tray space, never an instant dead end. That keeps
   the failure state feeling self-inflicted and recoverable, which is what keeps
   people tapping "Retry" — while the clock stops "wait for perfect" from being free.
4. **Readable at a glance.** Colored tile + motif. You can tell what a bag is at 20%
   screen height, in sunlight, at 30fps — and without relying on hue alone.

### What makes it different from triple-match

Triple-match (Match Triple 3D, Goods Sort) puts a static pile in front of you and
punishes you for a misclick permanently. Its ads are great and its D7 is bad,
because the frustration is *terminal* — you fail from a mistake you made 90 seconds
ago and can't see anymore.

Carousel keeps the tray-of-seven grammar and replaces the pile with a **moving
queue you're allowed to wait on, at a price**. The skill isn't "spot the item," it's
"decide whether to take this one now or on the next lap." That's a genuine decision
with a real cost on both sides, and it's the reason there's a skill ceiling worth
chasing a leaderboard over.

### The trap this design has to avoid

The first build of the prototype let you tap *any* bag anywhere on the belt. It
played terribly, and it's worth writing down why, because the failure isn't obvious
until you hold it: with free choice over every bag, there is no decision to get
wrong. You simply never make a bad pick. The belt becomes decoration.

The arithmetic is worse than that. You can hold at most two unmatched bags of each
type before the third pops, so with `T` types in play the most you can ever be
holding is `2T` slots. With a seven-slot tray and three types, that's six — **the
level cannot be lost in any order.** Any early level with fewer than four types is
unloseable no matter what the player does.

Both problems are structural, not tuning. The fixes are the claim zone (which makes
choice scarce) and the clock (which makes waiting cost something), plus reaching
four types by level two.

---

## Rules

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
| **Return** | 3 per level: send your last claimed bag back onto the belt. |

Scoring is a **flow meter**, not a point total: pop within 4 seconds of your last
pop and the multiplier climbs (×1 → ×2 → ×3 → ×5). Let it lapse and it resets.
Everyone can clear a level; only good players clear it *hot*. That split is what
gives you a casual audience and a retention audience in the same build.

---

## First 60 seconds

No tutorial text. No hand pointing at the screen. The level teaches itself:

- **0:00** — Belt starts with exactly 3 bags, all identical, moving slowly. The claim
  zone is the only lit thing on screen, so that is where the player looks and taps.
  The bag flies to the tray with a satisfying *thunk*.
- **0:06** — Third tap. The triple pops with a light burst and a chime pitched a
  fifth above the taps. Now they know the rule, and they know where they can reach.
- **0:14** — First bag drifts past the zone unclaimed. It dims. Fifteen seconds later
  it comes back — the moment that teaches skipping is survivable but slow.
- **0:30** — Level 2: four types, 18 bags. Four is deliberate: it is the first count
  at which the tray can actually jam, so this is the level where losing becomes
  possible at all.
- **0:55** — Level 3 adds an oversized bag. Now the tray has a shape, not just a
  count, and the take-or-wait call gets genuinely hard.

The onboarding is complete and the player has never read a word.

---

## Scaling out

This is the part that decides whether it's a weekend toy or a live product.
A level is a **seed plus eight numbers**, so content is generated, not authored.

```
Level = {
  seed,              // deterministic layout, so leaderboards and replays work
  types,             // 3 → 10 distinct bag types in play; 4+ to be losable at all
  triples,           // 5 → 14 matched sets (= 15 → 42 bags)
  beltSpeed,         // 68 → 155 px/s
  gateSpan,          // 0.19 of the loop — shrink it and the game gets brutal fast
  clock,             // laps' worth of time; the knob that punishes dithering
  traySlots,         // 7 (5 in "tight" events, 9 with a permanent upgrade)
  oversizedRate,     // 0 → 0.25
  modifiers[],       // see below
  goal               // clear-all | clear-tagged | survive-90s | quota
}
```

`gateSpan` and `clock` are the two difficulty knobs that matter, because they are
the only ones that constrain *choice*. Bag count and speed just change the texture.

A solver runs at generation time and rejects any seed that isn't clearable with at
least a 2-bag margin of tray space and time to spare, then bins the seed by how
*much* margin it had. Because the claim zone makes bag **order** matter, the
sequence around the loop is now the real content of a level, not just its contents.
That gives you an infinite, difficulty-labeled level supply from day one and lets
you tune the curve as a curve — not as 400 hand-built levels you can never revise.

Hand-author only levels **1–15**. After that it's the generator, with a live
difficulty controller that reads the player's recent fail rate and nudges the bin
selection. Nobody churns on level 47 again.

### Content axes (each is a separate, shippable content drop)

| Axis | Cheap version | Deep version |
|---|---|---|
| **Bag types** | New art on the same tile | Behavior: *fragile* (must pop within 15s), *wrapped* (two taps to open), *locked* (needs the key bag claimed first) |
| **Belt topology** | Speed changes | Figure-eight; two belts at different speeds; a **junction** you tap to switch, routing bags to the near or far loop |
| **Goals** | Clear all | Claim only red-tagged bags; VIP passenger timers; quota before the flight boards |
| **Hazards** | — | A bag you must *never* claim (the unclaimed suspicious package); customs inspection freezing two slots |
| **Theme packs** | Airport re-skins by city | Sushi conveyor, factory line, luggage on a cruise ship, Santa's sorting depot |

Note the pattern: **every one of these is a parameter change plus one sprite set.**
None of them requires touching the core loop, and none of them invalidates existing
levels. That's the definition of scaling out.

### Meta layer (add at soft-launch, not before)

Airport renovation: earn stars, unlock the departure lounge, the duty-free, the
lost luggage office. Proven retention scaffolding (Travel Town, Gossip Harbor), and
it's the natural home for a story character — an overworked baggage handler with
opinions — that gives you something to put in ads and push notifications.

---

## Monetization

Ad-first, IAP-supported, in this order:

1. **Rewarded video** on the fail screen: "Two extra slots, keep going." This is the
   whole business. A forgiving core loop means players *want* the continue.
2. **Interstitial** every 3 levels, hard-capped, skippable after 5s. Never after a
   loss — that's where you burn goodwill fastest.
3. **Remove ads** at $4.99 and a booster bundle at $2.99. Roughly 2–4% of revenue,
   but the players who buy it are the ones who stay.
4. **Season pass** only once you have a 30-day content pipeline. Not at launch.

---

## Build plan

**Stack:** Unity 6 (2D URP) targeting iOS 16+. The reason is not the engine, it's the
ad mediation — AppLovin MAX or LevelPlay with 4+ networks is where the CPM actually
lives, and that ecosystem is Unity-native. Godot 4 is the alternative if avoiding
runtime fees matters more than mediation maturity; SpriteKit only if this stays a
personal project.

**MVP (2 weeks):** belt, tray, match, fail, 15 levels, no meta, no ads, no art
budget — flat colored tiles and silhouettes. Ship it to TestFlight with 20 people.

**The gate:** before building anything else, cut three 15-second video creatives and
buy $300 of traffic against them. If CPI comes back under $0.60 in the US, keep
going. If it's over $1.20, the fantasy doesn't read and no amount of polish fixes
that — kill it and reskin the same code as the sushi conveyor, which costs a week.

**Targets to beat before scaling spend:**

| Metric | Floor | Good |
|---|---|---|
| D1 retention | 35% | 45% |
| D7 retention | 12% | 18% |
| Session length | 4 min | 7 min |
| Sessions/day | 3 | 5 |
| CPI (US) | $0.60 | $0.35 |

---

## Risks

- **It reads as "just triple match."** Mitigated by making the belt motion the hero
  of every creative — the first frame of every ad is a bag going past.
- **Motion sickness / readability at speed.** Cap belt speed well below the point
  where tiles blur; test with 60fps-locked devices only.
- **Solver cost.** Generating and verifying 42-bag levels is trivial (milliseconds),
  but the *fun* verification isn't automatable. Budget playtesting time per new
  modifier, not per level.
- **Category is crowded.** True of every casual category. The defense is the
  forgiving loop, which is a retention argument, not an acquisition one — so expect
  to win on D7, not on CPI.

---

## Naming

**Carousel** is the working name and probably the right one — short, thematically
exact, and not yet taken in the casual category. Store listing wants the keywords
though: *Carousel: Baggage Claim Sort*. Alternates considered: Claim!, Belt Rush,
Lost & Found, Turnstile.

---

## Runners-up

Kept here because they're reskins of the same architecture if Carousel fails its
CPI gate.

- **Seating Chart** — drag guests to tables at a wedding under constraints ("Aunt May
  won't sit near Uncle Bob"). Delightful, extremely shareable, but it's a constraint
  solver in a trench coat — too cognitively heavy for the 30-second session, and
  hard to generate levels that are unambiguously fair.
- **Bag It** — grocery checkout: heavy on the bottom, eggs on top, cold together.
  Wonderful relatable fantasy, but spatial packing is hard to auto-generate with
  guaranteed solvability and gets fiddly on a phone screen.
- **Cable Chaos** — untangle the charging cables behind the desk. Great fantasy, but
  it's a planar-graph puzzle, which means the difficulty curve is a cliff.

---

## Prototype

`prototype/carousel.html` — playable, touch-first, single file, no dependencies.
Open it on a phone. It implements the belt, the tray, matching, oversized bags,
the flow multiplier, the Return booster, and endless generated levels.
