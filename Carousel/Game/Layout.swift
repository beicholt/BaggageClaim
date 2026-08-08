import SpriteKit

/// The grid everything on screen is placed against.
///
/// Written because the first pass positioned things by eye — a button `width -
/// 100` wide starting 16 from the left, a counter nudged `+62` from a midpoint,
/// stat columns at 13% / 38% / 63% / 88%. Every one of those is defensible on
/// its own and none of them line up with each other, which is exactly what
/// makes a screen look homemade.
///
/// The rules: one margin, so every edge in the game agrees where the screen
/// starts. Gaps come from a scale, never from a number someone typed. Type
/// comes from a ramp. Anything that cannot be expressed in those terms is
/// probably wrong.
struct Layout {

    /// Spacing scale. Nothing is allowed a gap that is not on it.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    let size: CGSize
    let insets: UIEdgeInsets

    /// The one margin. Every left edge and every right edge uses it.
    static let margin: CGFloat = Space.l

    init(size: CGSize, insets: UIEdgeInsets) {
        self.size = size
        self.insets = insets
    }

    /// Everything the game may draw UI inside, safe areas already removed.
    var content: CGRect {
        CGRect(x: Self.margin,
               y: max(insets.bottom, Space.s) + Space.m,
               width: size.width - Self.margin * 2,
               height: size.height - max(insets.bottom, Space.s) - max(insets.top, Space.m))
    }

    var contentLeft: CGFloat { content.minX }
    var contentRight: CGFloat { content.maxX }
    var contentWidth: CGFloat { content.width }
    var centreX: CGFloat { size.width / 2 }

    /// Centre of column `i` of `n`, spread across the content width. Used for
    /// the stat readouts so they sit on the same grid as everything else rather
    /// than at percentages of the raw screen.
    func columnCentre(_ i: Int, of n: Int) -> CGFloat {
        contentLeft + contentWidth * (CGFloat(i) + 0.5) / CGFloat(n)
    }

    // MARK: - Type

    /// The type ramp. Sizes are fixed; picking one is a design decision, and
    /// inventing a new one is a decision to make the screen less coherent.
    enum Style {
        case display        // the one big word on a card
        case title
        case body
        case caption        // small, tracked, upper case — labels above numbers
        case readout        // numbers that change every frame
        case button

        var font: UIFont {
            switch self {
            case .display: return .systemFont(ofSize: 44, weight: .heavy)
            case .title:   return .systemFont(ofSize: 20, weight: .bold)
            case .body:    return .systemFont(ofSize: 15, weight: .regular)
            case .caption: return .systemFont(ofSize: 10, weight: .semibold)
            case .button:  return .systemFont(ofSize: 16, weight: .semibold)
            case .readout:
                // Monospaced digits, or the clock jitters as its glyphs change
                // width and the whole bar looks unstable.
                return .monospacedDigitSystemFont(ofSize: 22, weight: .bold)
            }
        }

        var tracking: CGFloat {
            switch self {
            case .caption: return 1.4
            case .display: return -0.5
            case .button:  return 0.6
            default:       return 0
            }
        }

        var uppercase: Bool {
            switch self {
            case .caption, .button: return true
            default: return false
            }
        }
    }
}

/// An SKLabelNode that knows its own style, so setting `string` cannot quietly
/// drop the tracking or the monospaced digits.
final class StyledLabel: SKLabelNode {

    private let style: Layout.Style
    private var colour: UIColor

    private var value = ""

    init(_ style: Layout.Style, _ colour: UIColor, align: SKLabelHorizontalAlignmentMode = .center) {
        self.style = style
        self.colour = colour
        super.init()
        horizontalAlignmentMode = align
        verticalAlignmentMode = .center
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Shadows SKLabelNode's own `text`, so a plain assignment cannot bypass
    /// the style and drop the tracking or the monospaced digits.
    override var text: String? {
        get { value }
        set {
            value = newValue ?? ""
            render()
        }
    }

    func tint(_ c: UIColor) {
        guard c != colour else { return }
        colour = c
        render()
    }

    private func render() {
        let shown = style.uppercase ? value.uppercased() : value
        attributedText = NSAttributedString(string: shown, attributes: [
            .font: style.font,
            .foregroundColor: colour,
            .kern: style.tracking,
        ])
    }
}
