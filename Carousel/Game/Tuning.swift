import CoreGraphics
import Foundation

/// Every number the game is balanced on, in one place.
///
/// These are ported unchanged from the web prototype. The belt is measured in
/// world units, never pixels, so a level plays identically on every phone —
/// that is the whole reason the prototype went to a projected view rather than
/// laying the loop out in screen coordinates.
enum Tune {
    // Rules
    static let trayCapacity = 7
    static let comboWindow: TimeInterval = 4.0
    static let returnsPerLevel = 3
    static let flyTime: TimeInterval = 0.28
    static let multipliers = [1, 1, 2, 3, 5]

    // The loop
    static let rectW: CGFloat = 7.8
    static let rectH: CGFloat = 7.6
    static let rectR: CGFloat = 2.6
    static let beltWidth: CGFloat = 1.15     // belt surface, across the loop
    static let beltY: CGFloat = 0.55         // belt surface height above the floor
    static let wallZ: CGFloat = -3.0         // front face of the baggage hall wall
    static let gateSpan: CGFloat = 0.19      // fraction of the loop you may claim from

    // Bags
    static let baseTile: CGFloat = 0.66      // bag width, world units
    static let minTile: CGFloat = 0.44       // below this a bag stops being readable
    static let hardMinTile: CGFloat = 0.30
    static let bagPad: CGFloat = 0.17        // clear belt between neighbours
    static let bigWidth: CGFloat = 1.66      // how much wider an oversized bag is

    // Camera
    static let camPitch: CGFloat = 0.66      // radians above the belt plane
    static let camFov: CGFloat = 54          // vertical, degrees
    static let camTarget = Vec3(0, 1.25, 0.1)
    /// The tray covers the bottom of the screen and the claim zone is the
    /// nearest part of the loop. Without reserving this band, the one stretch
    /// of belt the player may touch ends up underneath the tray.
    static let bottomReserve: CGFloat = 0.17
    static let fitX: CGFloat = rectW / 2 + 0.85
    static let fitZ: CGFloat = rectH / 2 + 0.85
}
