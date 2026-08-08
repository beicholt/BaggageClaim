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

// A bag you can see must be a bag you can hit — so no two bags may overlap
// *on screen*, which is not the same as not overlapping along the belt. Where
// the belt runs away from the camera, generous arclength buys almost no
// separation, and this is the check that catches it.
do {
    let proj = Projection(size: CGSize(width: 402, height: 874))
    let g = GameState()
    var worstOverlap: CGFloat = 0
    var worstLevel = 0

    for level in 1...20 {
        g.startLevel(level)

        // Screen rect of every bag the player can actually see.
        var boxes: [CGRect] = []
        for bag in g.bags where !g.track.inHall(bag.s) {
            let base = g.track.world(at: bag.s)
            let scale = proj.scale(atDepth: proj.depth(of: base))
            let w = g.tile * Bags.widthFactor(bag.type) * scale
            let h = w / (Bags[bag.type].size == 2 ? 2.4 : 0.6)
            let p = proj.project(base)
            boxes.append(CGRect(x: p.x - w / 2, y: p.y, width: w, height: h))
        }

        for i in boxes.indices {
            for j in (i + 1)..<boxes.count {
                let hit = boxes[i].intersection(boxes[j])
                guard !hit.isNull else { continue }
                let share = (hit.width * hit.height)
                    / min(boxes[i].width * boxes[i].height, boxes[j].width * boxes[j].height)
                if share > worstOverlap { worstOverlap = share; worstLevel = level }
            }
        }
    }
    // Some overlap between a near bag and a far one is honest perspective. A
    // third of a bag hidden is not.
    check("levels 1-20 keep bags legible (worst \(Int(worstOverlap * 100))% on belt \(worstLevel))",
          worstOverlap < 0.34)
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

// Clearing the belt wins the level.
do {
    let g = GameState()
    g.startLevel(1)
    while !g.bags.isEmpty {
        // Take whatever keeps the tray legal; the point is to empty the belt.
        let i = g.bags.firstIndex { Bags[$0.type].size + g.unitsUsed <= Tune.trayCapacity }
        guard let i else { break }
        g.claim(bagIndex: i, from: .zero)
        settle(g)
    }
    check("emptying the belt wins", g.phase == .won)
}

// Winning and moving on resets what a level owns, and keeps what the run owns.
do {
    let g = GameState()
    g.startLevel(4)
    g.claim(bagIndex: 0, from: .zero)
    settle(g)
    g.returnBag()
    let carried = g.score
    g.advanceLevel()
    check("next level steps the counter", g.level == 5)
    check("next level refills returns", g.returnsLeft == Tune.returnsPerLevel)
    check("next level empties the tray", g.tray.isEmpty)
    check("next level keeps the score", g.score == carried)
}

// Retrying hands back the score you had when the level started, so a failed
// attempt cannot bank points.
do {
    let g = GameState()
    g.startLevel(2)
    let atStart = g.score
    let type = g.bags[0].type
    var taken = 0
    while taken < 3, let i = g.bags.firstIndex(where: { $0.type == type }) {
        g.claim(bagIndex: i, from: .zero); settle(g); taken += 1
    }
    g.retryLevel()
    check("retry rolls the score back", g.score == atStart)
}

// The clock has to be long enough to clear the belt at all. A level you cannot
// finish however well you play is a bug, not a difficulty setting.
do {
    let g = GameState()
    var worst = Double.greatestFiniteMagnitude
    for level in 1...20 {
        g.startLevel(level)
        // One lap is the longest any single bag can make you wait.
        let lap = Double(g.track.total) / Double(max(0.01, 1.76))
        worst = min(worst, g.timeLeft / lap)
    }
    check("every level allows at least two laps", worst >= 2.0)
}

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
