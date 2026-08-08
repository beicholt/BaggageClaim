import SpriteKit

final class GameScene: SKScene {

    private let state = GameState()
    private var proj = Projection(size: CGSize(width: 390, height: 844))
    private var hall: HallNode!
    private var hud: HUDNode!
    private var tray: TrayNode!
    private var overlay: OverlayNode!
    private let world = SKNode()          // everything the screen shake moves

    private var bagNodes: [BagNode] = []
    private var lastTime: TimeInterval = 0
    private var clock: CGFloat = 0
    private var builtFor: CGSize = .zero

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = .hex(0x090D12)
        scaleMode = .resizeFill
        addChild(world)
        rebuild(for: size)
        wireState()
        // The belt idles behind the title card, so the first thing the player
        // sees is a machine already running.
        state.seedIdleBelt()
        overlay.showTitle()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 1, size.height > 1, size != builtFor else { return }
        rebuild(for: size)
    }

    private func rebuild(for size: CGSize) {
        builtFor = size
        proj = Projection(size: size)

        if hall == nil {
            hall = HallNode(track: state.track, projection: proj)
            world.addChild(hall)
        } else {
            hall.resize(proj)
        }

        hud?.removeFromParent()
        hud = HUDNode(size: size, insets: safeInsets)
        hud.zPosition = 800
        hud.onReturn = { [weak self] in self?.state.returnBag() }
        addChild(hud)

        tray?.removeFromParent()
        tray = TrayNode(size: size, insets: safeInsets)
        tray.zPosition = 700
        addChild(tray)

        overlay?.removeFromParent()
        overlay = OverlayNode(size: size)
        overlay.zPosition = 1000
        overlay.onGo = { [weak self] in self?.startFromOverlay() }
        addChild(overlay)

        for node in bagNodes { node.removeFromParent() }
        bagNodes = []
    }

    private var safeInsets: UIEdgeInsets { view?.safeAreaInsets ?? .zero }

    private func wireState() {
        state.onClaim = { Audio.shared.play(.pick) }
        state.onReject = { Audio.shared.play(.no) }
        state.onReturn = { Audio.shared.play(.returnBag) }
        state.onPop = { [weak self] type, slot in
            guard let self else { return }
            Audio.shared.play(.pop, step: self.state.combo)
            self.tray.burst(at: slot, color: Bags[type].color, in: self)
        }
        state.onPhaseChange = { [weak self] phase in
            guard let self else { return }
            switch phase {
            case .won:  self.overlay.showWon(level: self.state.level, score: self.state.score,
                                             best: self.state.bestMultiplier)
            case .lost: self.overlay.showLost(reason: self.state.lossReason, level: self.state.level,
                                              score: self.state.score, best: self.state.bestMultiplier)
            default:    self.overlay.hide()
            }
        }
    }

    private func startFromOverlay() {
        overlay.hide()
        switch state.phase {
        case .won:  state.advanceLevel()
        case .lost: state.retryLevel()
        default:    state.resumeFromTitle()
        }
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : currentTime - lastTime
        lastTime = currentTime
        clock += CGFloat(dt)

        state.update(dt: dt)
        hall.update(dt: CGFloat(min(0.05, dt)), gateFlash: state.gateFlash, clock: clock)
        syncBags()
        tray.sync(state: state, projection: proj)
        hud.sync(state: state)

        // Screen shake, applied to the hall and belt but never the tray or HUD:
        // shaking the thing you are about to tap makes a miss feel like a bug.
        if state.shake > 0 {
            world.position = CGPoint(x: .random(in: -state.shake...state.shake),
                                     y: .random(in: -state.shake...state.shake))
        } else if world.position != .zero {
            world.position = .zero
        }
    }

    private func syncBags() {
        while bagNodes.count < state.bags.count {
            let node = BagNode()
            // Bags belong to the hall, not the scene: the wall has to be able to
            // occlude the far run, and two nodes only sort against each other
            // reliably when they share a parent.
            hall.addChild(node)
            bagNodes.append(node)
        }
        for (i, node) in bagNodes.enumerated() {
            guard i < state.bags.count else { node.isHidden = true; continue }
            node.isHidden = false
            let bag = state.bags[i]
            let type = Bags[bag.type]
            let base = state.track.world(at: bag.s)
            let depth = proj.depth(of: base)
            let scale = proj.scale(atDepth: depth)

            let worldW = state.tile * type.widthFactor
            let worldH = worldW / node.aspect(for: type.art, fallback: type.widthFactor)

            node.apply(art: type.art,
                       at: proj.project(base),
                       width: worldW * scale,
                       height: worldH * scale,
                       dimmed: !state.track.inGate(bag.s),
                       // Nearer the camera draws on top, and the wall sits between.
                       z: -depth)
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: self)

        if overlay.isVisible { overlay.handleTap(at: p); return }
        if hud.handleTap(at: convert(p, to: hud)) { return }
        guard state.phase == .playing else { return }

        // Nearest bag first, so a bag in front always wins the tap over one
        // behind it. Transparent corners are not the bag: let the tap fall
        // through rather than eating it.
        let local = convert(p, to: hall)
        var sawOutOfReach = false
        let candidates = state.bags.indices
            .map { (i: $0, depth: proj.depth(of: state.track.world(at: state.bags[$0].s))) }
            .sorted { $0.depth < $1.depth }

        for c in candidates {
            let bag = state.bags[c.i]
            guard c.i < bagNodes.count, bagNodes[c.i].contains(opaquePoint: local) else { continue }
            if state.track.inHall(bag.s) { continue }
            if !state.track.inGate(bag.s) { sawOutOfReach = true; continue }
            state.claim(bagIndex: c.i, from: hall.convert(bagNodes[c.i].position, to: self))
            return
        }
        if sawOutOfReach { state.flashGate() }      // teach, don't punish
    }
}
