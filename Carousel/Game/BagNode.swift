import SpriteKit

/// One bag on the belt: the sprite, plus the contact shadow that stops it
/// reading as floating above the rubber.
final class BagNode: SKNode {

    private let sprite = SKSpriteNode()
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 1, height: 1))
    private var art: String = ""

    override init() {
        super.init()
        shadow.fillColor = .black
        shadow.strokeColor = .clear
        shadow.alpha = 0.34
        shadow.zPosition = -1
        addChild(shadow)

        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(sprite)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func aspect(for art: String, fallback: CGFloat) -> CGFloat {
        Art.aspect(art) ?? fallback
    }

    func apply(art: String, at point: CGPoint, width: CGFloat, height: CGFloat,
               dimmed: Bool, z: CGFloat) {
        if art != self.art {
            self.art = art
            sprite.texture = Art.texture(art)
        }
        position = point
        zPosition = z
        sprite.size = CGSize(width: width, height: height)
        // Out of reach reads as dimmed. It is the cheapest way to say "you can
        // see it, you cannot have it yet" without adding any UI.
        sprite.color = .hex(0x39424E)
        sprite.colorBlendFactor = dimmed ? 0.55 : 0
        sprite.alpha = dimmed ? 0.92 : 1
        shadow.setScale(1)
        shadow.xScale = width * 1.05
        shadow.yScale = height * 0.22
    }

    /// True when the point lands on a part of the bag that is actually drawn.
    /// A bag the player can see must be a bag the player can hit — and the
    /// converse: an empty corner must not swallow the tap.
    func contains(opaquePoint p: CGPoint) -> Bool {
        let local = CGPoint(x: p.x - position.x, y: p.y - position.y)
        let w = sprite.size.width, h = sprite.size.height
        guard w > 0, h > 0 else { return false }
        let u = (local.x + w / 2) / w
        let v = 1 - local.y / h                      // texture space is top-down
        guard u >= 0, u <= 1, v >= 0, v <= 1 else { return false }
        return Art.alpha(art, u: u, v: v) >= 0.35
    }
}

/// Texture loading, plus the 64×64 alpha thumbnails that make tapping honest.
enum Art {
    private static var textures: [String: SKTexture] = [:]
    private static var masks: [String: [UInt8]] = [:]
    private static var aspects: [String: CGFloat] = [:]
    private static let maskSize = 64

    static func texture(_ name: String) -> SKTexture {
        if let t = textures[name] { return t }
        let t = SKTexture(imageNamed: name)
        t.filteringMode = .linear
        textures[name] = t
        aspects[name] = t.size().width / max(1, t.size().height)
        return t
    }

    static func aspect(_ name: String) -> CGFloat? {
        if let a = aspects[name] { return a }
        _ = texture(name)
        return aspects[name]
    }

    static func alpha(_ name: String, u: CGFloat, v: CGFloat) -> CGFloat {
        guard let mask = mask(name) else { return 1 }
        let x = min(maskSize - 1, max(0, Int(u * CGFloat(maskSize))))
        let y = min(maskSize - 1, max(0, Int(v * CGFloat(maskSize))))
        return CGFloat(mask[y * maskSize + x]) / 255
    }

    private static func mask(_ name: String) -> [UInt8]? {
        if let m = masks[name] { return m }
        guard !name.isEmpty, let cg = UIImage(named: name)?.cgImage else { return nil }
        let n = maskSize
        var buffer = [UInt8](repeating: 0, count: n * n)
        guard let ctx = CGContext(data: &buffer, width: n, height: n, bitsPerComponent: 8,
                                  bytesPerRow: n, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
        masks[name] = buffer
        return buffer
    }
}
