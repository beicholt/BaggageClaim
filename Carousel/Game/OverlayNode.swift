import SpriteKit

/// The card that covers the belt between levels: title, win, and the two ways
/// to lose. The belt keeps turning behind it.
///
/// Laid out as one vertical stack with gaps from the spacing scale, measured
/// from a single anchor. Nothing is positioned by eye, so the three cards line
/// up with each other however much text each one carries.
final class OverlayNode: SKNode {

    var onGo: (() -> Void)?
    private(set) var isVisible = false

    private let card = SKNode()
    private let eyebrow: StyledLabel
    private let title: StyledLabel
    private let blurb: [StyledLabel]
    private let scoreValue: StyledLabel
    private let bestValue: StyledLabel
    private let statsRow = SKNode()
    private let buttonLabel: StyledLabel
    private var button: SKShapeNode!
    private var buttonRect: CGRect = .zero

    private let layout: Layout

    init(layout: Layout) {
        self.layout = layout
        eyebrow = StyledLabel(.caption, Palette.hudHot)
        title = StyledLabel(.display, .white)
        blurb = (0..<3).map { _ in StyledLabel(.body, .hex(0xB9C4D0)) }
        scoreValue = StyledLabel(.readout, .white)
        bestValue = StyledLabel(.readout, .white)
        buttonLabel = StyledLabel(.button, Palette.buttonText)
        super.init()
        build()
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func build() {
        let scrim = SKShapeNode(rect: CGRect(origin: .zero, size: layout.size))
        scrim.fillColor = Palette.scrim.withAlphaComponent(0.84)
        scrim.strokeColor = .clear
        addChild(scrim)
        addChild(card)

        // One stack, top down, gaps from the scale.
        var y = layout.size.height * 0.70
        let x = layout.centreX

        eyebrow.position = CGPoint(x: x, y: y)
        card.addChild(eyebrow)
        y -= Layout.Space.xl + 18

        title.position = CGPoint(x: x, y: y)
        card.addChild(title)
        y -= Layout.Space.xl + Layout.Space.m

        for line in blurb {
            line.position = CGPoint(x: x, y: y)
            card.addChild(line)
            y -= Layout.Space.xl
        }
        y -= Layout.Space.l

        // Two stats, on the same column grid the HUD uses — halves rather than
        // arbitrary thirds, so they sit symmetrically about the centre.
        statsRow.position = CGPoint(x: 0, y: y)
        card.addChild(statsRow)
        for (i, pair) in [("Score", scoreValue), ("Best flow", bestValue)].enumerated() {
            let cx = layout.columnCentre(i, of: 2)
            let caption = StyledLabel(.caption, Palette.hudCaption)
            caption.text = pair.0
            caption.position = CGPoint(x: cx, y: -Layout.Space.l)
            statsRow.addChild(caption)
            pair.1.position = CGPoint(x: cx, y: Layout.Space.s)
            statsRow.addChild(pair.1)
        }
        y -= Layout.Space.xxl + Layout.Space.l

        // Full content width, same edges as the tray and the Return button, so
        // every horizontal edge in the game agrees.
        buttonRect = CGRect(x: layout.contentLeft, y: y - 56,
                            width: layout.contentWidth, height: 56)
        button = SKShapeNode(rect: buttonRect, cornerRadius: 14)
        button.fillColor = Palette.button
        button.strokeColor = .clear
        card.addChild(button)

        buttonLabel.position = CGPoint(x: buttonRect.midX, y: buttonRect.midY)
        card.addChild(buttonLabel)

        // How far the button rises when there are no stats to show, so the
        // title card does not carry an empty gap where they would have been.
        statsHeight = Layout.Space.xxl + Layout.Space.l
    }

    private var statsHeight: CGFloat = 0

    // MARK: - Cards

    func showTitle() {
        show(eyebrow: "Arrivals", title: "CAROUSEL",
             lines: ["You can only grab bags in the lit zone.",
                     "Three matching bags send a traveler home.",
                     "Skip one and you wait a full lap for it."],
             button: "Start", stats: nil)
    }

    func showWon(level: Int, score: Int, best: Int) {
        show(eyebrow: "Belt cleared", title: "ALL CLAIMED",
             lines: ["Belt \(String(format: "%02d", level + 1)) runs faster", "and carries more.", ""],
             button: "Next belt", stats: (score, best))
    }

    func showLost(reason: GameState.LossReason, level: Int, score: Int, best: Int) {
        let copy: (String, String, [String]) = reason == .boarded
            ? ("Flight boarded", "TOO SLOW",
               ["Waiting for the perfect bag", "costs you a whole lap.", ""])
            : ("Tray jammed", "NO ROOM",
               ["Seven slots, no match.", "Be choosier about what you take.", ""])
        show(eyebrow: copy.0, title: copy.1, lines: copy.2,
             button: "Retry belt \(String(format: "%02d", level))", stats: (score, best))
    }

    private func show(eyebrow e: String, title t: String, lines: [String],
                      button b: String, stats: (Int, Int)?) {
        eyebrow.text = e
        title.text = t
        for (i, line) in blurb.enumerated() { line.text = i < lines.count ? lines[i] : "" }
        buttonLabel.text = b
        statsRow.isHidden = stats == nil
        let lift = stats == nil ? statsHeight : 0
        button.position.y = lift
        buttonLabel.position.y = buttonRect.midY + lift
        scoreValue.text = "\(stats?.0 ?? 0)"
        bestValue.text = "×\(stats?.1 ?? 1)"

        isHidden = false
        isVisible = true

        // A short settle on appear. Without it the card cuts in like a browser
        // alert, which is most of what makes a game feel unfinished.
        card.alpha = 0
        card.setScale(0.96)
        card.run(.group([.fadeIn(withDuration: 0.18),
                         .scale(to: 1, duration: 0.22)]))
    }

    func hide() {
        isHidden = true
        isVisible = false
    }

    /// Any tap on the card starts — the button is a target, not a gate.
    func handleTap(at p: CGPoint) { onGo?() }
}
