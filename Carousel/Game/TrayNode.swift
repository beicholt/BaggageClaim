import SpriteKit

/// The seven slots at the bottom of the screen.
///
/// Slots are laid out by *units*, not by item count: an oversized bag occupies
/// two slots and is drawn spanning both, so the tray shows its shape rather
/// than just how full it is.
///
/// Shares its left and right edges with the Return button below it — both come
/// from `Layout.content`, so the bottom of the screen reads as one block rather
/// than two things that happen to be near each other.
final class TrayNode: SKNode {

    private(set) var box: CGRect = .zero
    private(set) var slotWidth: CGFloat = 0
    private let gap = Layout.Space.s

    private var sprites: [SKSpriteNode] = []
    private var wells: [SKShapeNode] = []
    private var plate: SKShapeNode!
    private var crowded = false

    init(layout: Layout) {
        super.init()
        build(layout)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func build(_ layout: Layout) {
        let plateHeight: CGFloat = 82
        // Sits directly above the Return button, one step of the scale away.
        let plateY = layout.content.minY + 48 + Layout.Space.m
        plate = SKShapeNode(rect: CGRect(x: layout.contentLeft, y: plateY,
                                        width: layout.contentWidth, height: plateHeight),
                            cornerRadius: 14)
        plate.fillColor = Palette.trayPlate
        plate.strokeColor = Palette.trayEdge
        plate.lineWidth = 1
        addChild(plate)

        // The wells are inset from the plate by one step, and divide what is
        // left evenly — so the outer gaps match the inner ones.
        box = CGRect(x: layout.contentLeft + Layout.Space.s, y: plateY + Layout.Space.s,
                     width: layout.contentWidth - Layout.Space.s * 2,
                     height: plateHeight - Layout.Space.s * 2)
        slotWidth = (box.width - gap * CGFloat(Tune.trayCapacity - 1)) / CGFloat(Tune.trayCapacity)

        for i in 0..<Tune.trayCapacity {
            let well = SKShapeNode(rect: CGRect(x: box.minX + CGFloat(i) * (slotWidth + gap),
                                                y: box.minY, width: slotWidth, height: box.height),
                                   cornerRadius: 8)
            well.fillColor = Palette.trayWell
            well.strokeColor = .clear
            addChild(well)
            wells.append(well)
        }
    }

    /// Centre of the slot an item sits in, accounting for the units before it.
    func slotCentre(state: GameState, index: Int) -> CGPoint {
        var units = 0
        for i in 0..<index { units += Bags[state.tray[i].type].size }
        let size = Bags[state.tray[index].type].size
        let span = CGFloat(size) * slotWidth + CGFloat(size - 1) * gap
        return CGPoint(x: box.minX + CGFloat(units) * (slotWidth + gap) + span / 2,
                       y: box.midY)
    }

    func sync(state: GameState) {
        // One slot left is the moment before a jam, and the loss screen should
        // never be the first time the player hears about it.
        let tight = state.unitsUsed >= Tune.trayCapacity - 1 && state.phase == .playing
        if tight != crowded {
            crowded = tight
            plate.strokeColor = tight ? Palette.hudLow : Palette.trayEdge
            plate.lineWidth = tight ? 2 : 1
        }

        while sprites.count < state.tray.count {
            let s = SKSpriteNode()
            s.zPosition = 10
            addChild(s)
            sprites.append(s)
        }
        for (i, sprite) in sprites.enumerated() {
            guard i < state.tray.count else { sprite.isHidden = true; continue }
            sprite.isHidden = false
            let item = state.tray[i]
            let type = Bags[item.type]
            sprite.texture = Art.texture(type.art)

            let units = CGFloat(type.size)
            let span = units * slotWidth + (units - 1) * gap
            let aspect = Art.aspect(type.art) ?? type.widthFactor
            var h = box.height - Layout.Space.m
            var w = h * aspect
            if w > span - Layout.Space.s { w = span - Layout.Space.s; h = w / aspect }
            sprite.size = CGSize(width: w, height: h)

            let target = slotCentre(state: state, index: i)
            if let f = item.flight {
                // Ease out along the line, and lift over an arc on the way. A
                // straight slide reads as a UI transition; a thrown bag traces
                // a curve and lands with some weight behind it.
                let t = min(1, f.t)
                let k = 1 - pow(1 - t, 3)
                let lift = sin(t * .pi) * 46
                sprite.position = CGPoint(x: f.from.x + (target.x - f.from.x) * k,
                                          y: f.from.y + (target.y - f.from.y) * k + lift)
                sprite.zRotation = (1 - t) * 0.35
                sprite.setScale(0.72 + 0.28 * k)
            } else {
                sprite.position = target
                sprite.zRotation = 0
                if sprite.action(forKey: "land") == nil { sprite.setScale(1) }
            }
        }
    }

    /// The slot takes the impact: a quick squash on the bag and a flash in the
    /// well underneath, so landing is something you see as well as feel.
    func land(at index: Int, state: GameState) {
        guard index < sprites.count else { return }
        let sprite = sprites[index]
        sprite.removeAction(forKey: "land")
        sprite.setScale(1)
        sprite.run(.sequence([
            .group([.scaleX(to: 1.16, duration: 0.06), .scaleY(to: 0.84, duration: 0.06)]),
            .group([.scaleX(to: 1.0, duration: 0.16), .scaleY(to: 1.0, duration: 0.16)]),
        ]), withKey: "land")

        var units = 0
        for i in 0..<index where i < state.tray.count { units += Bags[state.tray[i].type].size }
        guard units < wells.count else { return }
        let well = wells[units]
        well.removeAllActions()
        well.fillColor = Palette.trayWell
        well.run(.sequence([
            .customAction(withDuration: 0.05) { n, _ in
                (n as? SKShapeNode)?.fillColor = .white
            },
            .customAction(withDuration: 0.28) { n, t in
                let k = min(1, t / 0.28)
                (n as? SKShapeNode)?.fillColor = UIColor.white.blend(to: Palette.trayWell, k)
            },
        ]))
    }

    func burst(at slot: Int, color: UIColor, in scene: SKScene) {
        let x = box.minX + (CGFloat(slot) + 0.5) * (slotWidth + gap)
        let at = CGPoint(x: min(box.maxX, x), y: box.midY)

        let ring = SKShapeNode(circleOfRadius: 14)
        ring.position = at
        ring.strokeColor = color
        ring.lineWidth = 3
        ring.fillColor = .clear
        ring.zPosition = 899
        scene.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 3.0, duration: 0.34), .fadeOut(withDuration: 0.34)]),
            .removeFromParent(),
        ]))

        for _ in 0..<14 {
            let dot = SKShapeNode(circleOfRadius: .random(in: 2...4.5))
            dot.fillColor = color
            dot.strokeColor = .clear
            dot.position = at
            dot.zPosition = 900
            scene.addChild(dot)
            let a = CGFloat.random(in: 0...(2 * .pi))
            let v = CGFloat.random(in: 50...150)
            dot.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(a) * v, dy: sin(a) * v + 50), duration: 0.55),
                    .scale(to: 0.2, duration: 0.55),
                    .fadeOut(withDuration: 0.55),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}
