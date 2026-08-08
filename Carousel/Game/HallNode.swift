import SpriteKit

/// Everything that never moves: the window wall, the floor, and the carousel
/// itself. Rebuilt only on a size change.
///
/// The camera is fixed, so none of this needs to be 3D at runtime — the loop is
/// projected once and filled as flat shapes. That is also why the look pass can
/// later swap the whole thing for a single rendered backdrop without touching a
/// line of the game.
final class HallNode: SKNode {

    private let track: Track
    private var proj: Projection
    private var vehicles: [(node: SKSpriteNode, speed: CGFloat, dir: CGFloat, z: CGFloat, worldH: CGFloat)] = []
    private var plane: SKSpriteNode?
    private var planeClock: CGFloat = 0
    private var planeBaseY: CGFloat = 0
    private var apronLine: CGFloat = 0
    private var windowBand: SKCropNode?
    private(set) var gateNode: SKShapeNode?

    /// Screen y of the wall base — the boundary between the window and the hall.
    private(set) var wallBaseY: CGFloat = 0

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
        vehicles = []
        plane = nil
        build()
    }

    // MARK: - Build

    private func build() {
        let size = proj.size
        buildWindow(size)
        buildFloor(size)
        buildCarousel()
    }

    /// Height of the solid wall the window sits on top of. Tall enough to hide
    /// the far run of the loop, which is the whole reason the wall exists.
    private let wallHeight: CGFloat = 2.35

    private func buildWindow(_ size: CGSize) {
        wallBaseY = proj.project(x: 0, y: 0, z: Tune.wallZ).y
        let sillY = proj.project(x: 0, y: wallHeight, z: Tune.wallZ).y
        let bandH = max(1, size.height - sillY)
        // Where the ground outside meets the sky. Art direction, not geometry:
        // the true horizon of a camera pitched this far down sits off the top
        // of the screen, and putting it there gives you a runway for a sky.
        apronLine = sillY + bandH * 0.46

        let band = SKCropNode()
        band.zPosition = -900
        let mask = SKSpriteNode(color: .white,
                                size: CGSize(width: size.width, height: bandH))
        mask.position = CGPoint(x: size.width / 2, y: sillY + bandH / 2)
        band.maskNode = mask
        addChild(band)
        windowBand = band

        // One image, aspect-filled and cropped. The apron render already carries
        // its own horizon, distant terminal and sky, so layering a separate sky
        // and skyline behind it only creates seams to line up.
        addFill(imageNamed: "bg_apron", to: band, width: size.width,
                from: sillY, to: size.height, z: -10)

        buildApronTraffic(band: band, width: size.width, bandHeight: bandH)

        // Mullions last, so they read as glazing bars in front of the view.
        for i in 0...3 {
            let x = size.width * (0.16 + 0.24 * CGFloat(i))
            let bar = SKSpriteNode(color: .hex(0x0B0F14),
                                   size: CGSize(width: 5, height: bandH))
            bar.position = CGPoint(x: x, y: sillY + bandH / 2)
            bar.zPosition = -5
            band.addChild(bar)
        }
    }

    /// Scale to cover the given screen band without distorting, and let the
    /// crop node trim the overflow.
    private func addFill(imageNamed name: String, to parent: SKNode, width: CGFloat,
                         from y0: CGFloat, to y1: CGFloat, z: CGFloat) {
        let node = SKSpriteNode(imageNamed: name)
        let h = max(1, y1 - y0)
        guard let tex = node.texture else { return }
        let scale = max(width / tex.size().width, h / tex.size().height)
        node.size = CGSize(width: tex.size().width * scale, height: tex.size().height * scale)
        node.position = CGPoint(x: width / 2, y: y0 + h / 2)
        node.zPosition = z
        parent.addChild(node)
    }

    private func buildApronTraffic(band: SKNode, width: CGFloat, bandHeight: CGFloat) {
        // Ground traffic crossing behind the glass. Pure decoration, but a still
        // window reads as a painted backdrop and this one reads as an airport.
        let laneH = bandHeight * 0.11
        for (art, scale, speed, dir, lane) in [
            ("spr_taxi", 1.0 as CGFloat, 62.0 as CGFloat, 1.0 as CGFloat, -0.10 as CGFloat),
            ("spr_tug", 0.72, 38, -1, 0.02),
        ] {
            let node = SKSpriteNode(imageNamed: art)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            let aspect = node.texture.map { $0.size().width / $0.size().height } ?? 1
            node.size = CGSize(width: laneH * scale * aspect, height: laneH * scale)
            node.position = CGPoint(x: .random(in: 0...width), y: apronLine - bandHeight * lane)
            node.zPosition = -7
            band.addChild(node)
            vehicles.append((node, speed, dir, 0, 0))
        }

        let plane = SKSpriteNode(imageNamed: "spr_plane")
        plane.anchorPoint = CGPoint(x: 0.5, y: 0)
        let aspect = plane.texture.map { $0.size().width / $0.size().height } ?? 3
        plane.size = CGSize(width: bandHeight * 0.34 * aspect, height: bandHeight * 0.34)
        plane.zPosition = -6
        band.addChild(plane)
        self.plane = plane
        planeBaseY = apronLine - bandHeight * 0.04
    }

    private func buildFloor(_ size: CGSize) {
        let sillY = proj.project(x: 0, y: wallHeight, z: Tune.wallZ).y

        let floor = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: wallBaseY))
        floor.fillColor = .hex(0x171C23)
        floor.strokeColor = .clear
        floor.zPosition = -800
        addChild(floor)

        // The wall the window sits on. Its depth is what makes the occlusion
        // work: bags further away than the wall plane sort behind it and vanish
        // properly, instead of being switched off at an arbitrary arclength.
        //
        // Measured at belt height, not at the floor. The camera looks down, so
        // raising a point reduces its depth — take the wall's depth at y=0 and
        // it lands *behind* bags standing on the belt at the same distance,
        // which is how the far run ended up drawn over the wall.
        let wall = SKShapeNode(rect: CGRect(x: 0, y: wallBaseY, width: size.width,
                                            height: max(1, sillY - wallBaseY)))
        wall.fillColor = .hex(0x11161D)
        wall.strokeColor = .clear
        wall.zPosition = -proj.depth(of: Vec3(0, Tune.beltY, Tune.wallZ))
        addChild(wall)

        // A skirting line where the wall meets the floor, so the two dark greys
        // do not merge into one flat field.
        let skirting = SKShapeNode(rect: CGRect(x: 0, y: wallBaseY - 1.5, width: size.width, height: 3))
        skirting.fillColor = .hex(0x232C37)
        skirting.strokeColor = .clear
        skirting.zPosition = wall.zPosition + 0.1
        addChild(skirting)
    }

    private func buildCarousel() {
        let inner = -Tune.beltWidth / 2
        let outer = Tune.beltWidth / 2

        // Outer skirt: the drum below the belt lip, down to the floor.
        addRibbon(offsetA: outer, heightA: Tune.beltY,
                  offsetB: outer + 0.22, heightB: 0,
                  color: .hex(0x252C35), z: -500)

        // Belt surface.
        addRibbon(offsetA: inner, heightA: Tune.beltY,
                  offsetB: outer, heightB: Tune.beltY,
                  color: .hex(0x20262E), z: -480)

        // Inner slope up to the island deck.
        addRibbon(offsetA: inner - 0.55, heightA: Tune.beltY + 0.18,
                  offsetB: inner, heightB: Tune.beltY,
                  color: .hex(0x2C333D), z: -470)

        // Island deck, filled from the loop's inner edge inward.
        let deck = SKShapeNode(path: loopPath(offset: inner - 0.55, height: Tune.beltY + 0.18))
        deck.fillColor = .hex(0x222932)
        deck.strokeColor = .hex(0x2E3742)
        deck.lineWidth = 1
        deck.zPosition = -460
        addChild(deck)

        // The claim zone gets its own lit stretch of belt: it is the one thing
        // on screen the player is meant to look at.
        let half = track.total * Tune.gateSpan / 2
        let mid = track.segments[4].start + track.segments[4].length / 2
        let gate = SKShapeNode(path: ribbonPath(from: mid - half, span: half * 2,
                                                offsetA: inner, heightA: Tune.beltY + 0.004,
                                                offsetB: outer, heightB: Tune.beltY + 0.004))
        gate.fillColor = .hex(0xFFB23F, alpha: 0.09)
        gate.strokeColor = .hex(0xFFC96B, alpha: 0.22)
        gate.lineWidth = 1.5
        gate.zPosition = -450
        gate.blendMode = .add
        addChild(gate)
        gateNode = gate
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
    private func addRibbon(offsetA: CGFloat, heightA: CGFloat,
                           offsetB: CGFloat, heightB: CGFloat,
                           color: UIColor, z: CGFloat) {
        let path = CGMutablePath()
        let steps = 160
        var back: [CGPoint] = []
        for i in 0...steps {
            let s = track.total * CGFloat(i) / CGFloat(steps)
            let a = proj.project(track.world(at: s, offset: offsetA, height: heightA))
            let b = proj.project(track.world(at: s, offset: offsetB, height: heightB))
            if i == 0 { path.move(to: a) } else { path.addLine(to: a) }
            back.append(b)
        }
        for p in back.reversed() { path.addLine(to: p) }
        path.closeSubpath()

        let node = SKShapeNode(path: path)
        node.fillColor = color
        node.strokeColor = .clear
        node.zPosition = z
        node.isAntialiased = true
        addChild(node)
    }

    private func ribbonPath(from start: CGFloat, span: CGFloat,
                            offsetA: CGFloat, heightA: CGFloat,
                            offsetB: CGFloat, heightB: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let steps = 40
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

    func update(dt: CGFloat, gateFlash: CGFloat, clock: CGFloat) {
        gateNode?.fillColor = .hex(0xFFB23F, alpha: 0.09 + gateFlash * 0.30 + sin(clock * 2.2) * 0.015)

        for v in vehicles {
            var x = v.node.position.x + v.speed * v.dir * dt
            let halfW = v.node.size.width / 2
            if v.dir > 0 && x - halfW > proj.size.width { x = -halfW }
            if v.dir < 0 && x + halfW < 0 { x = proj.size.width + halfW }
            v.node.position.x = x
        }

        guard let plane else { return }
        planeClock = (planeClock + dt).truncatingRemainder(dividingBy: 26)
        let k = planeClock / 11
        plane.isHidden = k > 1
        guard k <= 1 else { return }
        // Ground roll for the first 55%, then rotate and climb out of the window.
        let lift = max(0, (k - 0.55) / 0.45)
        let w = proj.size.width
        plane.position = CGPoint(x: -w * 0.4 + k * w * 1.8,
                                 y: planeBaseY + lift * lift * proj.size.height * 0.10)
        plane.zRotation = lift * 0.2
        plane.setScale(1 - lift * 0.2)
    }
}

private extension CGPoint {
    func distance(to p: CGPoint) -> CGFloat { hypot(p.x - x, p.y - y) }
}
