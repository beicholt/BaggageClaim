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
        backgroundColor = Palette.floorFar
        scaleMode = .resizeFill
        addChild(world)
        rebuild(for: size)
        wireState()
        // CAROUSEL_LEVEL=n drops straight into that belt, skipping the title.
        // Needed to QA the later levels at all — oversized bags do not appear
        // until belt three, and playing up to belt nine by hand every time is
        // not a test, it is a chore nobody repeats.
        if let raw = ProcessInfo.processInfo.environment["CAROUSEL_LEVEL"], let n = Int(raw) {
            // A QA run must never become the player's saved position.
            Progress.suspended = true
            state.startLevel(max(1, n))
            showDebugCard()
            return
        }

        // The belt idles behind the title card, so the first thing the player
        // sees is a machine already running.
        state.seedIdleBelt()
        overlay.showTitle(resumingAt: Progress.hasPlayed ? Progress.belt : nil,
                          best: Progress.bestScore)
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

        let layout = Layout(size: size, insets: safeInsets)

        hud?.removeFromParent()
        hud = HUDNode(layout: layout)
        hud.zPosition = 800
        hud.onReturn = { [weak self] in self?.state.returnBag() }
        addChild(hud)

        tray?.removeFromParent()
        tray = TrayNode(layout: layout)
        tray.zPosition = 700
        addChild(tray)

        overlay?.removeFromParent()
        overlay = OverlayNode(layout: layout)
        overlay.zPosition = 1000
        overlay.onGo = { [weak self] in self?.startFromOverlay() }
        addChild(overlay)

        for node in bagNodes { node.removeFromParent() }
        bagNodes = []
    }

    private var safeInsets: UIEdgeInsets { view?.safeAreaInsets ?? .zero }

    private func wireState() {
        Haptics.warm()
        state.onClaim = {
            Audio.shared.play(.pick)
            Haptics.claim()
        }
        state.onReject = {
            Audio.shared.play(.no)
            Haptics.refuse()
        }
        state.onReturn = {
            Audio.shared.play(.returnBag)
            Haptics.claim()
        }
        state.onLand = { [weak self] slot in
            guard let self else { return }
            self.tray.land(at: slot, state: self.state)
        }
        state.onPop = { [weak self] type, slot in
            guard let self else { return }
            Audio.shared.play(.pop, step: self.state.combo)
            Haptics.pop(step: self.state.combo)
            self.tray.burst(at: slot, color: Bags[type].color, in: self)
        }
        state.onPhaseChange = { [weak self] phase in
            guard let self else { return }
            switch phase {
            case .won:
                Haptics.won()
                Progress.record(belt: self.state.level + 1, score: self.state.score,
                                flow: self.state.bestMultiplier)
                self.overlay.showWon(level: self.state.level, score: self.state.score,
                                     best: self.state.bestMultiplier)
            case .lost:
                Haptics.lost()
                Progress.record(belt: self.state.level, score: self.state.score,
                                flow: self.state.bestMultiplier)
                self.overlay.showLost(reason: self.state.lossReason, level: self.state.level,
                                      score: self.state.score, best: self.state.bestMultiplier)
            case .playing:
                self.overlay.hide()
                self.announceLevel()
            default:
                self.overlay.hide()
            }
        }
    }

    private func startFromOverlay() {
        overlay.hide()
        switch state.phase {
        case .won:  state.advanceLevel()
        case .lost: state.retryLevel()
        default:    state.startLevel(Progress.hasPlayed ? Progress.belt : 1)
        }
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 0 : currentTime - lastTime
        lastTime = currentTime
        clock += CGFloat(dt)

        state.update(dt: dt)
        hall.update(gateFlash: state.gateFlash, clock: clock)
        syncBags()
        tray.sync(state: state)
        hud.sync(state: state, clock: clock)

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
            let bag = state.bags[i]
            // Behind the wall is hidden outright rather than sorted away. A
            // billboard cannot be half-occluded by a flat wall, so trying to do
            // it with depth alone forces a choice between bags that vanish
            // early and bags that hang over the wall — this hides them at the
            // hatch, where the strip curtain covers the moment.
            node.isHidden = state.track.inHall(bag.s)
            if node.isHidden { continue }
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
                       // Nearer draws on top. The constant lift keeps every bag
                       // in front of the belt it stands on, which sits just
                       // ahead of the wall plane.
                       z: -depth + 1.0,
                       // A slight rock as it rides, phased off its own position
                       // on the belt so neighbours are never in step. Nothing
                       // standing on moving rubber sits perfectly still, and
                       // perfectly still is what reads as a sprite.
                       lean: sin(bag.s * 2.1 + clock * 1.6) * 0.025)
        }
    }

    /// CAROUSEL_CARD=won|jammed|boarded puts an end-of-level card straight on
    /// screen. Those three are otherwise only reachable by playing a whole belt
    /// out, which makes them the screens least likely to get looked at and the
    /// most likely to be wrong.
    private func showDebugCard() {
        switch ProcessInfo.processInfo.environment["CAROUSEL_CARD"] {
        case "won":
            overlay.showWon(level: state.level, score: 4_820, best: 3)
        case "jammed":
            overlay.showLost(reason: .jammed, level: state.level, score: 1_150, best: 2)
        case "boarded":
            overlay.showLost(reason: .boarded, level: state.level, score: 960, best: 2)
        default:
            break
        }
    }

    /// The belt number, once, in the middle of the screen. Two seconds of
    /// knowing where you are, without a screen to tap through.
    private func announceLevel() {
        childNode(withName: "levelBanner")?.removeFromParent()
        let banner = StyledLabel(.display, .white)
        banner.name = "levelBanner"
        banner.text = "Belt \(String(format: "%02d", state.level))"
        banner.position = CGPoint(x: size.width / 2, y: size.height * 0.55)
        banner.zPosition = 950
        banner.alpha = 0
        banner.setScale(0.86)
        addChild(banner)
        banner.run(.sequence([
            .group([.fadeAlpha(to: 1, duration: 0.18), .scale(to: 1, duration: 0.22)]),
            .wait(forDuration: 0.55),
            .group([.fadeOut(withDuration: 0.3), .scale(to: 1.08, duration: 0.3)]),
            .removeFromParent(),
        ]))
    }

    /// A brief ghost of the bag, lifting and fading where it was taken.
    ///
    /// Drawn as a throwaway node rather than on the bag itself: the pool
    /// reassigns that index to a different bag on the very next frame, so
    /// animating it would play the flourish on the wrong suitcase.
    private func flashClaim(_ node: BagNode, at point: CGPoint) {
        let shot = node.snapshot
        guard let texture = shot.texture else { return }
        let ghost = SKSpriteNode(texture: texture)
        ghost.size = shot.size
        ghost.anchorPoint = CGPoint(x: 0.5, y: 0)
        ghost.position = point
        ghost.zPosition = 650
        addChild(ghost)
        ghost.run(.sequence([
            .group([
                .scale(to: 1.3, duration: 0.16),
                .moveBy(x: 0, y: shot.size.height * 0.25, duration: 0.16),
                .fadeOut(withDuration: 0.16),
            ]),
            .removeFromParent(),
        ]))
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
            let node = bagNodes[c.i]
            let from = hall.convert(node.position, to: self)
            let before = state.tray.count
            state.claim(bagIndex: c.i, from: from)
            // Only if the claim was actually honoured — a refused tap gets the
            // shake and the buzz, not a flourish.
            if state.tray.count > before { flashClaim(node, at: from) }
            return
        }
        if sawOutOfReach {
            state.flashGate()                       // teach, don't punish
            Haptics.refuse()
        }
    }
}
