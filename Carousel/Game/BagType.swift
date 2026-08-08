import UIKit

/// Every bag is identified by hue *and* silhouette, so the game stays readable
/// for colourblind players. The colour is what the tray slot and the manifest
/// tint themselves with; the art is the sprite on the belt.
struct BagType {
    let color: UIColor
    let size: Int          // tray slots consumed: 1, or 2 for oversized
    let art: String        // asset catalog name

    var widthFactor: CGFloat { size == 2 ? Tune.bigWidth : 1 }
}

enum Bags {
    static let all: [BagType] = [
        BagType(color: .hex(0xE0674F), size: 1, art: "bag_rollaboard"),
        BagType(color: .hex(0x4E9BD4), size: 1, art: "bag_duffel"),
        BagType(color: .hex(0xC8A33C), size: 1, art: "bag_vintage"),
        BagType(color: .hex(0x9E6BC9), size: 1, art: "bag_backpack"),
        BagType(color: .hex(0x7FA05A), size: 1, art: "bag_medcase"),
        BagType(color: .hex(0xDE6B95), size: 1, art: "bag_garment"),
        BagType(color: .hex(0x54B3A6), size: 1, art: "bag_petcarrier"),
        BagType(color: .hex(0xD98A3E), size: 2, art: "bag_surfboard"),
        BagType(color: .hex(0x6E7FD1), size: 2, art: "bag_golf"),
        BagType(color: .hex(0x3FA9C4), size: 2, art: "bag_guitar"),
    ]

    static let small: [Int] = all.indices.filter { all[$0].size == 1 }
    static let big:   [Int] = all.indices.filter { all[$0].size == 2 }

    static subscript(i: Int) -> BagType { all[i] }
    static func widthFactor(_ type: Int) -> CGFloat { all[type].widthFactor }
}

extension UIColor {
    static func hex(_ v: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 0xFF) / 255,
                green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255,
                alpha: alpha)
    }
}
