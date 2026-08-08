import SpriteKit

/// The four readouts across the top, and the Return button under the tray.
///
/// Every edge here comes from `Layout` — the bar's stats sit on the same column
/// grid, and the button spans the same content width as the tray above it, so
/// the two share a left and a right edge instead of each having its own.
final class HUDNode: SKNode {

    var onReturn: (() -> Void)?

    private let stats: [StyledLabel]
    private let level: StyledLabel
    private let time: StyledLabel
    private let flow: StyledLabel
    private let score: StyledLabel

    private var returnButton: SKShapeNode!
    private let returnLabel = StyledLabel(.button, Palette.trayLabel, align: .left)
    private let returnCount = StyledLabel(.button, .hex(0xC97A00), align: .right)
    private var returnRect: CGRect = .zero

    private let layout: Layout

    init(layout: Layout) {
        self.layout = layout
        level = StyledLabel(.readout, Palette.hudText)
        time  = StyledLabel(.readout, Palette.hudText)
        flow  = StyledLabel(.readout, Palette.hudCaption)
        score = StyledLabel(.readout, Palette.hudText)
        stats = [level, time, flow, score]
        super.init()
        buildTopBar()
        buildReturn()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func buildTopBar() {
        let barHeight = max(layout.insets.top, Layout.Space.m) + 56
        let bar = SKShapeNode(rect: CGRect(x: 0, y: layout.size.height - barHeight,
                                           width: layout.size.width, height: barHeight))
        bar.fillColor = Palette.hudBar
        bar.strokeColor = .clear
        addChild(bar)

        // Captions sit on a baseline, readouts on a baseline below it. Both are
        // measured down from the safe area, so the bar looks the same on a
        // phone with a notch and one without.
        let captionY = layout.size.height - max(layout.insets.top, Layout.Space.m) - Layout.Space.m
        let readoutY = captionY - Layout.Space.xl

        for (i, pair) in [("Belt", level), ("Departs", time), ("Flow", flow), ("Score", score)].enumerated() {
            let x = layout.columnCentre(i, of: 4)

            let caption = StyledLabel(.caption, Palette.hudCaption)
            caption.text = pair.0
            caption.position = CGPoint(x: x, y: captionY)
            addChild(caption)

            pair.1.position = CGPoint(x: x, y: readoutY)
            addChild(pair.1)
        }
    }

    private func buildReturn() {
        // Same width and same edges as the tray, which sits directly above it.
        returnRect = CGRect(x: layout.contentLeft, y: layout.content.minY,
                            width: layout.contentWidth, height: 48)
        returnButton = SKShapeNode(rect: returnRect, cornerRadius: 12)
        returnButton.fillColor = Palette.trayPlate
        returnButton.strokeColor = Palette.trayEdge
        returnButton.lineWidth = 1
        addChild(returnButton)

        returnLabel.text = "Return bag"
        returnLabel.position = CGPoint(x: returnRect.minX + Layout.Space.l, y: returnRect.midY)
        addChild(returnLabel)

        // Right-aligned against the button's own padding, not nudged from the
        // middle — so it stays put whatever the label says.
        returnCount.position = CGPoint(x: returnRect.maxX - Layout.Space.l, y: returnRect.midY)
        addChild(returnCount)
    }

    func sync(state: GameState) {
        level.text = String(format: "%02d", state.level)
        let secs = max(0, Int(state.timeLeft.rounded(.up)))
        time.text = String(format: "%d:%02d", secs / 60, secs % 60)
        time.tint(secs <= 15 ? Palette.hudLow : Palette.hudText)
        flow.text = "×\(state.multiplier)"
        flow.tint(state.multiplier > 1 ? Palette.hudHot : Palette.hudCaption)
        score.text = "\(state.score)"

        returnCount.text = "\(state.returnsLeft)"
        let on = state.canReturn
        returnButton.alpha = on ? 1 : 0.4
        returnLabel.alpha = on ? 1 : 0.4
        returnCount.alpha = on ? 1 : 0.4
    }

    /// Returns true when the tap was the button's, so the belt does not also
    /// see it and claim a bag underneath.
    func handleTap(at p: CGPoint) -> Bool {
        guard returnRect.contains(p) else { return false }
        onReturn?()
        return true
    }
}
