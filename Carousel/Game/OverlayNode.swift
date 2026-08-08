import SpriteKit

/// The card that covers the belt between levels: title, win, and the two ways
/// to lose. The belt keeps turning behind it.
final class OverlayNode: SKNode {

    var onGo: (() -> Void)?
    private(set) var isVisible = false

    private let scrim = SKShapeNode()
    private let eyebrow = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let title = SKLabelNode(fontNamed: "HelveticaNeue-CondensedBlack")
    private let blurb: [SKLabelNode]
    private let scoreCaption = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let scoreValue = SKLabelNode(fontNamed: "Menlo-Bold")
    private let bestCaption = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let bestValue = SKLabelNode(fontNamed: "Menlo-Bold")
    private var button: SKShapeNode!
    private let buttonLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let sceneSize: CGSize

    init(size: CGSize) {
        sceneSize = size
        blurb = (0..<3).map { _ in SKLabelNode(fontNamed: "HelveticaNeue") }
        super.init()
        build(size)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func build(_ size: CGSize) {
        scrim.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
        scrim.fillColor = Palette.scrim.withAlphaComponent(0.82)
        scrim.strokeColor = .clear
        addChild(scrim)

        let cy = size.height * 0.58

        eyebrow.fontSize = 12
        eyebrow.fontColor = .hex(0xFFB23F)
        eyebrow.position = CGPoint(x: size.width / 2, y: cy + 96)
        addChild(eyebrow)

        title.fontSize = min(64, size.width * 0.17)
        title.fontColor = .hex(0xEDE8DE)
        title.position = CGPoint(x: size.width / 2, y: cy + 34)
        addChild(title)

        for (i, line) in blurb.enumerated() {
            line.fontSize = 15
            line.fontColor = .hex(0x9AA5B2)
            line.position = CGPoint(x: size.width / 2, y: cy - 6 - CGFloat(i) * 23)
            addChild(line)
        }

        scoreCaption.text = "SCORE"
        bestCaption.text = "BEST FLOW"
        for (caption, value, fx) in [(scoreCaption, scoreValue, 0.34), (bestCaption, bestValue, 0.66)] {
            caption.fontSize = 9
            caption.fontColor = .hex(0x66717F)
            caption.position = CGPoint(x: size.width * fx, y: cy - 118)
            addChild(caption)
            value.fontSize = 28
            value.fontColor = .hex(0xEDE8DE)
            value.position = CGPoint(x: size.width * fx, y: cy - 106)
            addChild(value)
        }

        let rect = CGRect(x: size.width / 2 - 96, y: cy - 200, width: 192, height: 54)
        button = SKShapeNode(rect: rect, cornerRadius: 8)
        button.fillColor = Palette.button
        button.strokeColor = .clear
        addChild(button)

        buttonLabel.fontSize = 17
        buttonLabel.fontColor = Palette.buttonText
        buttonLabel.verticalAlignmentMode = .center
        buttonLabel.position = CGPoint(x: rect.midX, y: rect.midY)
        addChild(buttonLabel)
    }

    // MARK: - Cards

    func showTitle() {
        show(eyebrow: "ARRIVALS", title: "CAROUSEL",
             lines: ["You can only grab bags in the lit zone in front of you.",
                     "Three matching bags send a traveler home.",
                     "Skip one and you wait a full lap for it."],
             button: "START", stats: nil)
    }

    func showWon(level: Int, score: Int, best: Int) {
        show(eyebrow: "BELT CLEARED", title: "ALL CLAIMED",
             lines: [String(format: "Belt %02d runs faster", level + 1), "and carries more.", ""],
             button: "NEXT BELT", stats: (score, best))
    }

    func showLost(reason: GameState.LossReason, level: Int, score: Int, best: Int) {
        let copy: (String, String, [String]) = reason == .boarded
            ? ("FLIGHT BOARDED", "TOO SLOW",
               ["Waiting for the perfect bag costs a whole lap.", "Take the ones you can use.", ""])
            : ("TRAY JAMMED", "NO ROOM",
               ["Seven slots, no match.", "Be choosier about what you let in.", ""])
        show(eyebrow: copy.0, title: copy.1, lines: copy.2,
             button: String(format: "RETRY BELT %02d", level), stats: (score, best))
    }

    private func show(eyebrow e: String, title t: String, lines: [String],
                      button b: String, stats: (Int, Int)?) {
        eyebrow.text = e
        title.text = t
        for (i, line) in blurb.enumerated() { line.text = i < lines.count ? lines[i] : "" }
        buttonLabel.text = b
        scoreValue.text = "\(stats?.0 ?? 0)"
        bestValue.text = "×\(stats?.1 ?? 1)"
        isHidden = false
        isVisible = true
    }

    func hide() {
        isHidden = true
        isVisible = false
    }

    /// Any tap on the card starts — the button is a target, not a gate.
    func handleTap(at p: CGPoint) { onGo?() }
}
