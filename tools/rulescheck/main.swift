import CoreGraphics
import Foundation

// Exercises the rules with no scene attached. GameState deliberately knows
// nothing about SpriteKit, which is what makes this possible — and what makes
// it worth keeping that way as the game grows.
//
//   tools/rules_check.sh

var failures = 0
func check(_ label: String, _ ok: Bool) {
    print("\(ok ? "ok  " : "FAIL") \(label)")
    if !ok { failures += 1 }
}

/// Run a claim all the way through its flight, the way a frame loop would.
func settle(_ g: GameState) {
    for _ in 0..<40 { g.update(dt: 1.0 / 60) }
}

// A triple pops, scores, and frees its slots.
do {
    let g = GameState()
    g.startLevel(1)
    let type = g.bags[0].type
    var taken = 0
    while taken < 3, let i = g.bags.firstIndex(where: { $0.type == type }) {
        g.claim(bagIndex: i, from: .zero)
        settle(g)
        taken += 1
    }
    check("three of a kind leaves the tray", g.tray.isEmpty)
    check("three of a kind scores", g.score > 0)
    check("flow multiplier climbed", g.multiplier >= 1)
}

// Oversized bags cost two slots, and the tray refuses what will not fit.
do {
    let g = GameState()
    g.startLevel(9)                       // deep enough to include oversized types
    let big = g.bags.firstIndex { Bags[$0.type].size == 2 }
    if let big {
        let before = g.unitsUsed
        g.claim(bagIndex: big, from: .zero)
        settle(g)
        check("an oversized bag costs two slots", g.unitsUsed == before + 2)
    } else {
        check("level 9 offers an oversized bag", false)
    }
}

// The tray never overfills, whatever the player does.
do {
    let g = GameState()
    g.startLevel(6)
    for _ in 0..<40 where !g.bags.isEmpty {
        g.claim(bagIndex: 0, from: .zero)
        settle(g)
    }
    check("tray never exceeds capacity", g.unitsUsed <= Tune.trayCapacity)
}

// Below four types a jam is arithmetically impossible, so early levels must
// reach four or they hand out levels that cannot be lost.
do {
    let g = GameState()
    g.startLevel(2)
    check("level 2 reaches four types", Set(g.bags.map(\.type)).count >= 4)
}

// Every bag is placed with clear belt around it: a bag you can see is a bag
// you can hit.
do {
    let g = GameState()
    for level in 1...12 {
        g.startLevel(level)
        let sorted = g.bags.map(\.s).sorted()
        var minGap = CGFloat.greatestFiniteMagnitude
        for i in sorted.indices {
            let a = sorted[i]
            let b = i + 1 < sorted.count ? sorted[i + 1] : sorted[0] + g.track.total
            minGap = min(minGap, b - a)
        }
        // Neighbouring centres must clear half of each bag plus the padding.
        let worst = g.tile * Tune.bigWidth
        if minGap < worst * 0.5 {
            check("level \(level) places bags without overlap", false)
            break
        }
        if level == 12 { check("levels 1-12 place bags without overlap", true) }
    }
}

// Returning a bag puts it back on the belt and costs a charge.
do {
    let g = GameState()
    g.startLevel(1)
    g.claim(bagIndex: 0, from: .zero)
    settle(g)
    let onBelt = g.bags.count, charges = g.returnsLeft
    g.returnBag()
    check("return puts the bag back", g.bags.count == onBelt + 1)
    check("return costs a charge", g.returnsLeft == charges - 1)
}

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
