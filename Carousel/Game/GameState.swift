import CoreGraphics
import Foundation

/// The whole game, with nothing that draws.
///
/// Keeping the rules free of SpriteKit is what makes the belt testable and what
/// let this port be checked against the web prototype behaviour by behaviour.
/// The scene reads this and paints it; it never decides anything.
final class GameState {

    enum Phase { case intro, playing, won, lost }
    enum LossReason { case jammed, boarded }

    struct Bag {
        var type: Int
        var s: CGFloat          // arclength along the belt
    }

    struct TrayItem {
        var type: Int
        /// Set while the bag is still flying from the belt to its slot. The
        /// tray is not settled — and cannot be judged — until every flight lands.
        var flight: (from: CGPoint, t: CGFloat)?
    }

    let track = Track()

    private(set) var phase: Phase = .intro
    private(set) var lossReason: LossReason = .jammed
    private(set) var level = 1
    private(set) var score = 0
    private(set) var levelStartScore = 0
    private(set) var combo = 0
    private(set) var bestMultiplier = 1
    private(set) var returnsLeft = Tune.returnsPerLevel
    private(set) var bags: [Bag] = []
    private(set) var tray: [TrayItem] = []
    private(set) var timeLeft: TimeInterval = 60
    private(set) var tile: CGFloat = Tune.baseTile
    private(set) var beltPhase: CGFloat = 0
    private(set) var gateFlash: CGFloat = 0
    private(set) var shake: CGFloat = 0

    private var speed: CGFloat = 70.0 / 88.0     // world units per second
    private var comboTimer: TimeInterval = 0
    private var fitCount = 14
    private var fitFactor: CGFloat = 14

    /// Raised when something happens that the scene should react to.
    var onPop: ((Int, Int) -> Void)?             // type, slot index popped from
    var onLand: ((Int) -> Void)?                 // slot index a claimed bag settled into
    var onClaim: (() -> Void)?
    var onReject: (() -> Void)?
    var onReturn: (() -> Void)?
    var onPhaseChange: ((Phase) -> Void)?

    var multiplier: Int { Tune.multipliers[combo] }
    var unitsUsed: Int { tray.reduce(0) { $0 + Bags[$1.type].size } }
    var anyFlying: Bool { tray.contains { $0.flight != nil } }

    // MARK: - Level generation

    func startLevel(_ n: Int) {
        // Reach four types by level two. Below four a jam is arithmetically
        // impossible — you can hold two of each and still never fill seven
        // slots — so anything slower hands out unloseable levels.
        let typeCount = min(Bags.small.count, 2 + n)
        let smallPool = Array(Bags.small.prefix(typeCount))
        let bigPool = n >= 3 ? Array(Bags.big.prefix(min(Bags.big.count, n / 3))) : []
        let pool = smallPool + bigPool

        speed = min(1.76, 0.77 + CGFloat(n) * 0.08)

        // Draw the level, then drop a matched set at a time until the belt can
        // carry it at a readable size.
        //
        // Every type in the pool gets a set before any type gets a second one.
        // Drawing purely at random can leave a level short of the type count it
        // was meant to have, and a level with three types cannot be lost at all
        // — you can hold two of each and never fill seven slots. That made
        // level two unloseable roughly a third of the time.
        var types: [Int] = []
        for triples in stride(from: min(11, 4 + n), through: 2, by: -1) {
            var sets: [Int] = []

            // Oversized first, and always at least one once they exist. They
            // are the mechanic the level is *about* — a belt that quietly drew
            // none of them is a belt teaching the wrong lesson. Capped at a
            // quarter of the sets so the tray still mostly holds normal bags.
            if !bigPool.isEmpty {
                sets += bigPool.shuffled().prefix(max(1, min(bigPool.count, triples / 4)))
            }
            // Then cover every ordinary type before repeating any of them.
            for t in smallPool.shuffled() where sets.count < triples { sets.append(t) }
            while sets.count < triples { sets.append(pool.randomElement()!) }

            types = sets.flatMap { [$0, $0, $0] }
            if fitsLegibly(types) { break }
        }
        types.shuffle()                                   // spread the matching sets

        bags = placeBags(types)
        tray = []
        returnsLeft = Tune.returnsPerLevel
        combo = 0
        comboTimer = 0
        level = n
        levelStartScore = score
        // Enough laps to clear the belt playing well, not enough to dither.
        timeLeft = TimeInterval(track.total / speed) * (2.0 + Double(bags.count) / 10)
        setPhase(.playing)
    }

    /// A belt turning behind the title card. If it is moving, the game is alive
    /// before the player has touched anything.
    func seedIdleBelt() {
        let types = (0..<14).map { Bags.small[$0 % 5] }
        bags = placeBags(types)
        phase = .intro
    }

    func resumeFromTitle() { startLevel(1) }

    func retryLevel() {
        score = levelStartScore
        startLevel(level)
    }

    func advanceLevel() { startLevel(level + 1) }

    /// How well a stretch of belt separates the bags standing on it.
    ///
    /// Bags are drawn facing the camera, but they are spaced along the belt.
    /// Where the belt runs across the view they separate properly; where it
    /// runs away from the camera — the two side runs — the same arclength
    /// buys almost no horizontal separation and the bags pile into each other.
    /// Spacing has to be bought in the local currency, or a late belt reads as
    /// a heap however carefully the arclength was divided.
    ///
    /// The camera looks along world Z and never moves, so this needs only the
    /// track: no projection, no view size, still testable headless.
    private func spread(at s: CGFloat) -> CGFloat {
        let e: CGFloat = 0.01
        let p0 = track.point(at: s - e), p1 = track.point(at: s + e)
        let tx = p1.x - p0.x, ty = p1.y - p0.y
        let m = max(0.000_1, sqrt(tx * tx + ty * ty))
        // Floored, or a run pointing straight at the camera would demand
        // infinite belt and no level would ever fit.
        return max(0.38, abs(tx / m))
    }

    /// Walk the loop laying bags down, each taking the arclength it needs where
    /// it stands. Returns nil when the set will not fit legibly, which is the
    /// caller's cue to shed a matched set rather than crowd the belt.
    private func layOut(_ types: [Int], slack: CGFloat) -> [Bag]? {
        var cursor: CGFloat = 0
        var placed: [Bag] = []
        placed.reserveCapacity(types.count)

        for type in types {
            let w = Tune.baseTile * Bags.widthFactor(type)
            let s = track.wrap(cursor + w / 2)
            placed.append(Bag(type: type, s: s))
            cursor += (w + Tune.bagPad + slack) / spread(at: s)
            if cursor > track.total { return nil }
        }
        return placed
    }

    private func fitsLegibly(_ types: [Int]) -> Bool {
        layOut(types, slack: 0) != nil
    }

    /// Lay the bags out, then spend whatever belt is left over as extra breathing
    /// room spread evenly. Irregular like a real carousel, never overlapping —
    /// a bag the player can see must be a bag the player can hit.
    private func placeBags(_ types: [Int]) -> [Bag] {
        fitCount = types.count
        fitFactor = types.reduce(CGFloat(0)) { $0 + Bags.widthFactor($1) }
        tile = Tune.baseTile

        // Binary search the extra gap the loop can afford, so a light belt
        // spreads out rather than bunching at the top and leaving a bald patch.
        var low: CGFloat = 0, high: CGFloat = track.total / max(1, CGFloat(types.count))
        var best = layOut(types, slack: 0) ?? []
        for _ in 0..<12 {
            let mid = (low + high) / 2
            if let laid = layOut(types, slack: mid) {
                best = laid
                low = mid
            } else {
                high = mid
            }
        }
        return best
    }

    // MARK: - Player actions

    func claim(bagIndex: Int, from screenPoint: CGPoint) {
        guard phase == .playing, bags.indices.contains(bagIndex) else { return }
        let bag = bags[bagIndex]
        guard unitsUsed + Bags[bag.type].size <= Tune.trayCapacity else {
            shake = 5
            onReject?()
            return
        }
        bags.remove(at: bagIndex)

        // Group with its own kind, so a nearly-complete set reads at a glance.
        var at = tray.count
        for i in stride(from: tray.count - 1, through: 0, by: -1) where tray[i].type == bag.type {
            at = i + 1
            break
        }
        tray.insert(TrayItem(type: bag.type, flight: (from: screenPoint, t: 0)), at: at)
        onClaim?()
    }

    func flashGate() { gateFlash = 0.55 }

    var canReturn: Bool { phase == .playing && returnsLeft > 0 && !tray.isEmpty && !anyFlying }

    func returnBag() {
        guard canReturn else { return }
        let item = tray.removeLast()
        bags.append(Bag(type: item.type, s: track.wrap(beltPhase + track.total * 0.5)))
        returnsLeft -= 1
        combo = 0
        onReturn?()
    }

    // MARK: - Resolution

    private func resolve() {
        var counts: [Int: Int] = [:]
        for item in tray { counts[item.type, default: 0] += 1 }

        for (type, n) in counts.sorted(by: { $0.key < $1.key }) where n >= 3 {
            var left = 3
            var i = 0
            while i < tray.count && left > 0 {
                if tray[i].type == type {
                    onPop?(type, i)
                    tray.remove(at: i)
                    left -= 1
                } else {
                    i += 1
                }
            }
            combo = min(combo + 1, Tune.multipliers.count - 1)
            comboTimer = Tune.comboWindow
            score += 100 * multiplier * Bags[type].size
            bestMultiplier = max(bestMultiplier, multiplier)
            shake = 3
        }
    }

    private func checkEnd() {
        guard phase == .playing, !anyFlying else { return }

        if bags.isEmpty && tray.isEmpty { setPhase(.won); return }

        let used = unitsUsed
        if used >= Tune.trayCapacity { lose(.jammed); return }

        guard let smallest = bags.map({ Bags[$0.type].size }).min() else {
            lose(.jammed)                       // belt empty, tray can never clear
            return
        }
        if used + smallest > Tune.trayCapacity { lose(.jammed) }
    }

    private func lose(_ reason: LossReason) {
        lossReason = reason
        setPhase(.lost)
    }

    private func setPhase(_ p: Phase) {
        phase = p
        onPhaseChange?(p)
    }

    // MARK: - Tick

    /// CAROUSEL_FREEZE=1 stops the belt and the clock. Nothing in the game sets
    /// it — it exists so a build can be driven from a script and the same bag is
    /// still under the same pixel one tool call later.
    static let frozen = ProcessInfo.processInfo.environment["CAROUSEL_FREEZE"] == "1"

    func update(dt: TimeInterval) {
        let dt = CGFloat(min(0.05, dt))
        if Self.frozen {
            // Flights still need to land, or a claimed bag never reaches the tray
            // and the level can never resolve.
            advanceFlights(dt: dt)
            return
        }

        // The belt idles behind the title card. If it is moving, the game is alive.
        let speedNow = phase == .playing ? speed : 0.42
        beltPhase = track.wrap(beltPhase + speedNow * dt)
        for i in bags.indices { bags[i].s = track.wrap(bags[i].s + speedNow * dt) }

        if gateFlash > 0 { gateFlash = max(0, gateFlash - dt * 1.8) }
        if shake > 0 { shake = max(0, shake - dt * 22) }

        guard phase == .playing else { return }

        timeLeft -= TimeInterval(dt)
        if timeLeft <= 0 {
            timeLeft = 0
            lose(.boarded)
            return
        }

        if comboTimer > 0 {
            comboTimer -= TimeInterval(dt)
            if comboTimer <= 0 { combo = 0 }
        }

        advanceFlights(dt: dt)
    }

    private func advanceFlights(dt: CGFloat) {
        var landed = false
        for i in tray.indices {
            guard var f = tray[i].flight else { continue }
            f.t += dt / CGFloat(Tune.flyTime)
            if f.t >= 1 {
                tray[i].flight = nil
                landed = true
                onLand?(i)
            } else {
                tray[i].flight = f
            }
        }
        if landed && !anyFlying {
            resolve()
            checkEnd()
        }
    }
}
