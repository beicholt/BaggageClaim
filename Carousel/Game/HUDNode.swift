import SpriteKit

/// The four readouts across the top, and the Return button under the tray.
final class HUDNode: SKNode {

    var onReturn: (() -> Void)?

    private let levelValue = SKLabelNode()
    private let timeValue = SKLabelNode()
    private let flowValue = SKLabelNode()
    private let scoreValue = SKLabelNode()

    private var returnButton: SKShapeNode!
    private let returnLabel = SKLabelNode()
    private let returnCount = SKLabelNode()

    private let sceneSize: CGSize

    init(size: CGSize, insets: UIEdgeInsets) {
        self.sceneSize = size
        super.init()
        buildTopBar(size: size, insets: insets)
        buildReturn(size: size, insets: insets)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildTopBar(size: CGSize, insets: UIEdgeInsets) {
        let top = size.height - max(insets.top, 12)
        let bar = SKShapeNode(rect: CGRect(x: 0, y: top - 58, width: size.width, height: 70))
        bar.fillColor = Palette.hudBar
        bar.strokeColor = .clear
        addChild(bar)

        let columns: [(String, SKLabelNode, CGFloat)] = [
            ("BELT", levelValue, 0.13),
            ("DEPARTS", timeValue, 0.38),
            ("FLOW", flowValue, 0.63),
            ("SCORE", scoreValue, 0.88),
        ]
        for (title, value, fx) in columns {
            let caption = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
            caption.text = title
            caption.fontSize = 9
            caption.fontColor = Palette.hudCaption
            caption.position = CGPoint(x: size.width * fx, y: top - 16)
            caption.horizontalAlignmentMode = .center
            addChild(caption)

            value.fontName = "Menlo-Bold"
            value.fontSize = 22
            value.fontColor = Palette.hudText
            value.position = CGPoint(x: size.width * fx, y: top - 44)
            value.horizontalAlignmentMode = .center
            addChild(value)
        }
    }

    private func buildReturn(size: CGSize, insets: UIEdgeInsets) {
        let bottom = max(insets.bottom, 10)
        let rect = CGRect(x: 16, y: bottom + 4, width: size.width - 100, height: 42)
        returnButton = SKShapeNode(rect: rect, cornerRadius: 10)
        returnButton.fillColor = Palette.trayPlate
        returnButton.strokeColor = Palette.trayEdge
        returnButton.lineWidth = 1
        addChild(returnButton)

        returnLabel.fontName = "HelveticaNeue-Bold"
        returnLabel.text = "RETURN BAG"
        returnLabel.fontSize = 13
        returnLabel.fontColor = Palette.trayLabel
        returnLabel.verticalAlignmentMode = .center
        returnLabel.position = CGPoint(x: rect.midX - 14, y: rect.midY)
        addChild(returnLabel)

        returnCount.fontName = "Menlo-Bold"
        returnCount.fontSize = 14
        returnCount.fontColor = .hex(0xD07A00)
        returnCount.verticalAlignmentMode = .center
        returnCount.position = CGPoint(x: rect.midX + 62, y: rect.midY)
        addChild(returnCount)
    }

    func sync(state: GameState) {
        levelValue.text = String(format: "%02d", state.level)
        let secs = max(0, Int(state.timeLeft.rounded(.up)))
        timeValue.text = String(format: "%d:%02d", secs / 60, secs % 60)
        timeValue.fontColor = secs <= 15 ? Palette.hudLow : Palette.hudText
        flowValue.text = "×\(state.multiplier)"
        flowValue.fontColor = state.multiplier > 1 ? Palette.hudHot : Palette.hudCaption
        scoreValue.text = "\(state.score)"

        returnCount.text = "\(state.returnsLeft)"
        let on = state.canReturn
        returnButton.alpha = on ? 1 : 0.45
        returnLabel.alpha = on ? 1 : 0.45
        returnCount.alpha = on ? 1 : 0.45
    }

    /// Returns true when the tap was the button's, so the belt does not also
    /// see it and claim a bag underneath.
    func handleTap(at p: CGPoint) -> Bool {
        guard returnButton.contains(p) else { return false }
        onReturn?()
        return true
    }
}
