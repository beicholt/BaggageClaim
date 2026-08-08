import UIKit

/// The hall, in one place.
///
/// The prototype was lit like a terminal at midnight, which read as gloomy and
/// fought the bags rather than carrying them. This is a bright daylight hall:
/// light floors and walls, a dark belt so the bags still have something to sit
/// against, and the claim zone as the one genuinely warm thing on screen.
enum Palette {
    // Room
    static let wall        = UIColor.hex(0xE4E9EE)
    static let wallShadow  = UIColor.hex(0xCBD3DB)
    static let skirting    = UIColor.hex(0xAFB9C3)
    static let floor       = UIColor.hex(0xCDD5DD)
    static let floorFar    = UIColor.hex(0xBCC5CE)

    // Carousel
    static let skirt       = UIColor.hex(0x96A2AE)
    static let skirtEdge   = UIColor.hex(0x7F8B97)
    static let belt        = UIColor.hex(0x434C57)
    static let slope       = UIColor.hex(0xB2BCC6)
    static let deck        = UIColor.hex(0xC4CDD6)
    static let deckEdge    = UIColor.hex(0xA6B0BA)

    // The one warm thing in the room. Near-white rather than amber: this is
    // added to the dark belt as light, and a saturated colour added to slate
    // comes out mustard — a mat rather than a spotlight.
    static let gate        = UIColor.hex(0xFFEFC6)
    static let gateEdge    = UIColor.hex(0xFFC33D)

    // Chrome
    static let hudBar      = UIColor.hex(0x1C2531)
    static let hudText     = UIColor.hex(0xF3F6F9)
    static let hudCaption  = UIColor.hex(0x8593A3)
    static let hudHot      = UIColor.hex(0xFFB020)
    static let hudLow      = UIColor.hex(0xFF6B52)

    static let trayPlate   = UIColor.hex(0xEAEEF2)
    static let trayWell    = UIColor.hex(0xD3DAE1)
    static let trayEdge    = UIColor.hex(0xB6C0CA)
    static let trayLabel   = UIColor.hex(0x5A6674)

    static let scrim       = UIColor.hex(0x0E1620)
    static let button      = UIColor.hex(0xFFB43C)
    static let buttonText  = UIColor.hex(0x1A1206)
}
