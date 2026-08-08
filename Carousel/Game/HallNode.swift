import SpriteKit

/// Everything that never moves: the window, the room, and the carousel itself.
/// Rebuilt only on a size change.
///
/// The camera is fixed, so none of this needs to be 3D at runtime — the loop is
/// projected once and filled as flat shapes. That is also why the look pass can
/// later swap the whole room for a single rendered backdrop without touching a
/// line of the game.
final class HallNode: SKNode {

    private let track: Track
    private var proj: Projection
    private(set) var gateNode: SKShapeNode?

    /// Screen y where the wall meets the floor — the base of the window.
    private(set) var wallBaseY: CGFloat = 0

    /// Height of the solid wall the window sits on. Tall enough to hide the far
    /// run of the loop, which is the whole reason the wall exists.
    private let wallHeight: CGFloat = 2.35

    init(track: Track, projection: Projection) {
        self.track = track
        self.proj = projection
        super.init()
        build()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func resize(_ projection: Projection) {
        proj = projection
        removeAllChildren()
        build()
    }

    // MARK: - Build

    private func build() {
        buildWindow(proj.size)
        buildRoom(proj.size)
        buildCarousel()
    }

    private func buildWindow(_ size: CGSize) {
        wallBaseY = proj.project(x: 0, y: 0, z: Tune.wallZ).y
        let sillY = proj.project(x: 0, y: wallHeight, z: Tune.wallZ).y
        let bandH = max(1, size.height - sillY)

        let band = SKCropNode()
        band.zPosition = -900
        let mask = SKSpriteNode(color: .white, size: CGSize(width: size.width, height: bandH))
        mask.position = CGPoint(x: size.width / 2, y: sillY + bandH / 2)
        band.maskNode = mask
        addChild(band)

        // One image, scaled to cover and cropped. Scaling it to fit instead
        // would squash a wide render into a strip, which reads as wrong
        // instantly even if you cannot say why.
        let view = SKSpriteNode(imageNamed: "bg_window")
        if let tex = view.texture {
            let scale = max(size.width / tex.size().width, bandH / tex.size().height)
            view.size = CGSize(width: tex.size().width * scale, height: tex.size().height * scale)
            // Bias downward so the apron and buildings stay in frame and the
            // crop eats sky, which is the part with nothing in it.
            view.position = CGPoint(x: size.width / 2, y: sillY + bandH * 0.42)
            view.zPosition = -10
            band.addChild(view)
        }

        // Glazing bars, so it reads as a window rather than a hole in the wall.
        for i in 0...3 {
            let bar = SKSpriteNode(color: .hex(0x6C7884),
                                   size: CGSize(width: 5, height: bandH))
            bar.position = CGPoint(x: size.width * (0.16 + 0.24 * CGFloat(i)),
                                   y: sillY + bandH / 2)
            bar.zPosition = -5
            band.addChild(bar)
        }
    }

    private func buildRoom(_ size: CGSize) {
        let sillY = proj.project(x: 0, y: wallHeight, z: Tune.wallZ).y

        // Floor. Two bands rather than one flat fill: the far floor sits in the
        // room's own shade and the near floor catches the window light, which
        // is most of what stops a single colour reading as a painted backdrop.
        let far = SKShapeNode(rect: CGRect(x: 0, y: wallBaseY - 1, width: size.width,
                                           height: -(wallBaseY * 0.45)))
        far.fillColor = Palette.floorFar
        far.strokeColor = .clear
        far.zPosition = -800
        addChild(far)

        let near = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width,
                                            height: wallBaseY * 0.55))
        near.fillColor = Palette.floor
        near.strokeColor = .clear
        near.zPosition = -799
        addChild(near)

        // The wall the window sits on. Its depth is what makes the occlusion
        // work: bags further away than the wall plane sort behind it and vanish
        // properly, instead of being switched off at an arbitrary arclength.
        //
        // Measured at belt height, not at the floor. The camera looks down, so
        // raising a point reduces its depth — take the wall's depth at y=0 and
        // it lands behind bags standing on the belt at the same distance.
        let wall = SKShapeNode(rect: CGRect(x: 0, y: wallBaseY, width: size.width,
                                            height: max(1, sillY - wallBaseY)))
        wall.fillColor = Palette.wall
        wall.strokeColor = .clear
        wall.zPosition = -proj.depth(of: Vec3(0, Tune.beltY, Tune.wallZ))
        addChild(wall)

        let shade = SKShapeNode(rect: CGRect(x: 0, y: wallBaseY, width: size.width, height: 14))
        shade.fillColor = Palette.wallShadow
        shade.strokeColor = .clear
        shade.zPosition = wall.zPosition + 0.05
        addChild(shade)

        let skirting = SKShapeNode(rect: CGRect(x: 0, y: wallBaseY - 2, width: size.width, height: 4))
        skirting.fillColor = Palette.skirting
        skirting.strokeColor = .clear
        skirting.zPosition = wall.zPosition + 0.1
        addChild(skirting)
    }

    /// Depth of the wall plane at belt height. Everything sorts against this:
    /// further away is behind the wall, nearer is in front of it.
    private var wallDepth: CGFloat { proj.depth(of: Vec3(0, Tune.beltY, Tune.wallZ)) }

    /// The two arclengths where the loop crosses the wall plane.
    ///
    /// The belt runs from in front of the wall to behind it and back, so it
    /// cannot be drawn at a single depth — do that and the wall either hides
    /// the stretch of belt in front of it (bags at ten o'clock standing on
    /// nothing) or fails to hide the stretch behind it. Split the loop here and
    /// each half gets its own side of the wall.
    private func wallCrossings() -> (front: CGFloat, back: CGFloat) {
        let steps = 720
        var crossings: [CGFloat] = []
        var previous = track.point(at: 0).y
        for i in 1...steps {
            let s = track.total * CGFloat(i) / CGFloat(steps)
            let z = track.point(at: s).y
            if (previous < Tune.wallZ) != (z < Tune.wallZ) { crossings.append(s) }
            previous = z
        }
        guard crossings.count >= 2 else { return (0, track.total) }
        // s = 0 is the far straight, the deepest point behind the wall, so the
        // stretch the player can see is the one *between* the two crossings.
        return (crossings.first!, crossings.last!)
    }

    private func buildCarousel() {
        let inner = -Tune.beltWidth / 2
        let outer = Tune.beltWidth / 2

        let (frontStart, frontEnd) = wallCrossings()
        let frontSpan = frontEnd - frontStart
        let behindStart = frontEnd
        let behindSpan = track.total - frontSpan

        // Just in front of the wall, so the belt runs right up to the hatch
        // instead of being clipped a few points short of it. Bags carry a
        // constant forward bias (see GameScene.syncBags) so they still draw
        // over the stretch they are standing on.
        let front = -wallDepth + 0.10
        let behind = -wallDepth - 40

        for (range, z) in [((frontStart, frontSpan), front), ((behindStart, behindSpan), behind)] {
            let (start, span) = range

            // Outer skirt: the drum below the belt lip, down to the floor.
            addRibbon(from: start, span: span,
                      offsetA: outer, heightA: Tune.beltY,
                      offsetB: outer + 0.22, heightB: 0,
                      color: Palette.skirt, z: z + 0.00)

            // A lip along the top of the skirt, catching the light.
            addRibbon(from: start, span: span,
                      offsetA: outer, heightA: Tune.beltY,
                      offsetB: outer + 0.06, heightB: Tune.beltY - 0.05,
                      color: Palette.skirtEdge, z: z + 0.01)

            // Belt surface. Kept dark on purpose: it is the one thing the bags
            // are read against, and a light belt leaves the pale ones floating.
            addRibbon(from: start, span: span,
                      offsetA: inner, heightA: Tune.beltY,
                      offsetB: outer, heightB: Tune.beltY,
                      color: Palette.belt, z: z + 0.02)

            // Inner slope up to the island deck.
            addRibbon(from: start, span: span,
                      offsetA: inner - 0.55, heightA: Tune.beltY + 0.18,
                      offsetB: inner, heightB: Tune.beltY,
                      color: Palette.slope, z: z + 0.03)
        }

        let pool = SKShapeNode(path: loopPath(offset: outer + 1.15, height: 0.001))
        pool.fillColor = Palette.floorFar.withAlphaComponent(0.75)
        pool.strokeColor = .clear
        pool.zPosition = -wallDepth - 60
        addChild(pool)

        let contact = SKShapeNode(path: loopPath(offset: outer + 0.34, height: 0.001))
        contact.fillColor = Palette.skirtEdge.withAlphaComponent(0.55)
        contact.strokeColor = .clear
        contact.zPosition = -wallDepth - 55
        addChild(contact)

        let deck = SKShapeNode(path: loopPath(offset: inner - 0.55, height: Tune.beltY + 0.18))
        deck.fillColor = Palette.deck
        deck.strokeColor = Palette.deckEdge
        deck.lineWidth = 1
        deck.zPosition = -wallDepth - 45
        addChild(deck)

        // The claim zone is the one warm thing in a cool room. On a bright hall
        // an additive glow washes out to nothing, so this is a painted pool of
        // light with a hot edge instead.
        let half = track.total * Tune.gateSpan / 2
        let mid = track.segments[4].start + track.segments[4].length / 2
        let gate = SKShapeNode(path: ribbonPath(from: mid - half, span: half * 2,
                                                offsetA: inner, heightA: Tune.beltY + 0.004,
                                                offsetB: outer, heightB: Tune.beltY + 0.004))
        gate.fillColor = Palette.gate.withAlphaComponent(0.30)
        gate.strokeColor = Palette.gateEdge
        gate.lineWidth = 2.5
        gate.zPosition = -wallDepth + 0.15
        gate.blendMode = .add
        addChild(gate)
        gateNode = gate

        addHoods(at: [frontStart, frontEnd])
    }

    /// Strip-curtain hoods where the belt passes through the wall.
    ///
    /// Without them a bag is fully visible one frame and gone the next — which
    /// is what an opaque wall genuinely does, but it reads as the bag blinking
    /// out in mid-air. A hatch makes the same disappearance mean something, and
    /// it is what the far run of a real baggage hall actually looks like.
    private func addHoods(at crossings: [CGFloat]) {
        for s in crossings {
            let hood = SKSpriteNode(imageNamed: "spr_strip_curtain")
            guard let tex = hood.texture else { continue }

            let centre = track.world(at: s, offset: 0, height: Tune.beltY)
            let scale = proj.scale(atDepth: proj.depth(of: centre))
            let worldW = Tune.beltWidth * 1.12
            let worldH = worldW / (tex.size().width / tex.size().height)

            hood.anchorPoint = CGPoint(x: 0.5, y: 0.02)   // sit the sill on the belt
            hood.size = CGSize(width: worldW * scale, height: worldH * scale)
            hood.position = proj.project(centre)
            // In front of the wall and of any bag still crossing, so a bag
            // slides behind the curtain rather than popping out of existence.
            hood.zPosition = -wallDepth + 1.02
            addChild(hood)
        }
    }

    // MARK: - Projected geometry

    private func loopPath(offset: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let steps = 160
        for i in 0...steps {
            let s = track.total * CGFloat(i) / CGFloat(steps)
            let p = proj.project(track.world(at: s, offset: offset, height: height))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    /// A closed band between two offset copies of the loop — the shape every
    /// part of the carousel is made from.
    private func addRibbon(from start: CGFloat, span: CGFloat,
                           offsetA: CGFloat, heightA: CGFloat,
                           offsetB: CGFloat, heightB: CGFloat,
                           color: UIColor, z: CGFloat) {
        let steps = max(12, Int(160 * span / track.total))
        let node = SKShapeNode(path: ribbonPath(from: start, span: span,
                                                offsetA: offsetA, heightA: heightA,
                                                offsetB: offsetB, heightB: heightB,
                                                steps: steps))
        node.fillColor = color
        node.strokeColor = .clear
        node.zPosition = z
        node.isAntialiased = true
        addChild(node)
    }

    private func ribbonPath(from start: CGFloat, span: CGFloat,
                            offsetA: CGFloat, heightA: CGFloat,
                            offsetB: CGFloat, heightB: CGFloat,
                            steps: Int = 40) -> CGPath {
        let path = CGMutablePath()
        var back: [CGPoint] = []
        for i in 0...steps {
            let s = start + span * CGFloat(i) / CGFloat(steps)
            let a = proj.project(track.world(at: s, offset: offsetA, height: heightA))
            let b = proj.project(track.world(at: s, offset: offsetB, height: heightB))
            if i == 0 { path.move(to: a) } else { path.addLine(to: a) }
            back.append(b)
        }
        for p in back.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }

    // MARK: - Tick

    func update(gateFlash: CGFloat, clock: CGFloat) {
        // A slow breath so the zone reads as lit rather than painted, and a
        // hard brighten when the player reaches for a bag they cannot have.
        let base = 0.30 + sin(clock * 2.2) * 0.03
        gateNode?.fillColor = Palette.gate.withAlphaComponent(base + gateFlash * 0.45)
    }
}
