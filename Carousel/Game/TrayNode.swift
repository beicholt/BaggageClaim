import SpriteKit

/// The seven slots at the bottom of the screen.
///
/// Slots are laid out by *units*, not by item count: an oversized bag occupies
/// two slots and is drawn spanning both, so the tray shows its shape rather
/// than just how full it is.
final class TrayNode: SKNode {

    private(set) var box: CGRect = .zero
    private(set) var slotWidth: CGFloat = 0
    private let gap: CGFloat = 6

    private var wells: [SKShapeNode] = []
    private var sprites: [SKSpriteNode] = []

    init(size: CGSize, insets: UIEdgeInsets) {
        super.init()
        layout(size: size, insets: insets)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func layout(size: CGSize, insets: UIEdgeInsets) {
        let bottom = max(insets.bottom, 10)
        let trayH = min(96, max(70, size.height * 0.16))
        let h = trayH - 26
        box = CGRect(x: 14, y: bottom + 54, width: size.width - 28, height: h)
        slotWidth = (box.width - gap * CGFloat(Tune.trayCapacity - 1)) / CGFloat(Tune.trayCapacity)

        let plate = SKShapeNode(rect: box.insetBy(dx: -8, dy: -8), cornerRadius: 14)
        plate.fillColor = Palette.trayPlate
        plate.strokeColor = Palette.trayEdge
        plate.lineWidth = 1
        addChild(plate)

        for i in 0..<Tune.trayCapacity {
            let well = SKShapeNode(rect: CGRect(x: box.minX + CGFloat(i) * (slotWidth + gap),
                                                y: box.minY, width: slotWidth, height: box.height),
                                   cornerRadius: 7)
            well.fillColor = Palette.trayWell
            well.strokeColor = Palette.trayEdge
            well.lineWidth = 1
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

    func sync(state: GameState, projection: Projection) {
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
            var h = box.height - 10
            var w = h * aspect
            if w > span - 6 { w = span - 6; h = w / aspect }
            sprite.size = CGSize(width: w, height: h)

            let target = slotCentre(state: state, index: i)
            if let f = item.flight {
                // Ease out, so the bag arrives settled rather than snapping.
                let k = 1 - pow(1 - min(1, f.t), 3)
                sprite.position = CGPoint(x: f.from.x + (target.x - f.from.x) * k,
                                          y: f.from.y + (target.y - f.from.y) * k)
                sprite.setScale(0.7 + 0.3 * k)
            } else {
                sprite.position = target
                sprite.setScale(1)
            }
        }
    }

    func burst(at slot: Int, color: UIColor, in scene: SKScene) {
        let x = box.minX + (CGFloat(slot) + 0.5) * (slotWidth + gap)
        let at = CGPoint(x: min(box.maxX, x), y: box.midY)
        for _ in 0..<12 {
            let dot = SKShapeNode(circleOfRadius: .random(in: 2...4))
            dot.fillColor = color
            dot.strokeColor = .clear
            dot.position = at
            dot.zPosition = 900
            scene.addChild(dot)
            let a = CGFloat.random(in: 0...(2 * .pi))
            let v = CGFloat.random(in: 40...130)
            dot.run(.sequence([
                .group([
                    .move(by: CGVector(dx: cos(a) * v, dy: sin(a) * v + 40), duration: 0.5),
                    .fadeOut(withDuration: 0.5),
                ]),
                .removeFromParent(),
            ]))
        }
    }
}
