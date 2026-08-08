import CoreGraphics
import Foundation

/// The belt, as a closed loop measured in arclength.
///
/// A rounded rectangle: four straights and four quarter arcs. Every rule in the
/// game addresses a position on the belt as a single number `s`, so this is the
/// only place that knows the loop has a shape at all.
struct Track {
    struct Segment {
        enum Kind { case line, arc }
        let kind: Kind
        let length: CGFloat
        var start: CGFloat = 0
        // line
        var x0: CGFloat = 0, y0: CGFloat = 0, x1: CGFloat = 0, y1: CGFloat = 0
        // arc
        var cx: CGFloat = 0, cy: CGFloat = 0, a0: CGFloat = 0, a1: CGFloat = 0
    }

    let radius: CGFloat
    let total: CGFloat
    let segments: [Segment]
    let gateA: CGFloat
    let gateB: CGFloat

    init(w: CGFloat = Tune.rectW, h: CGFloat = Tune.rectH, r: CGFloat = Tune.rectR) {
        let x = -w / 2, y = -h / 2
        let sw = w - 2 * r, sh = h - 2 * r, arc = (.pi / 2) * r
        var segs: [Segment] = [
            Segment(kind: .line, length: sw, x0: x + r, y0: y, x1: x + w - r, y1: y),
            Segment(kind: .arc, length: arc, cx: x + w - r, cy: y + r, a0: -.pi / 2, a1: 0),
            Segment(kind: .line, length: sh, x0: x + w, y0: y + r, x1: x + w, y1: y + h - r),
            Segment(kind: .arc, length: arc, cx: x + w - r, cy: y + h - r, a0: 0, a1: .pi / 2),
            Segment(kind: .line, length: sw, x0: x + w - r, y0: y + h, x1: x + r, y1: y + h),
            Segment(kind: .arc, length: arc, cx: x + r, cy: y + h - r, a0: .pi / 2, a1: .pi),
            Segment(kind: .line, length: sh, x0: x, y0: y + h - r, x1: x, y1: y + r),
            Segment(kind: .arc, length: arc, cx: x + r, cy: y + r, a0: .pi, a1: .pi * 1.5),
        ]
        var running: CGFloat = 0
        for i in segs.indices {
            segs[i].start = running
            running += segs[i].length
        }
        self.radius = r
        self.segments = segs
        self.total = running

        // Centre the claim zone on the near side of the loop, closest to the camera.
        let bottom = segs[4]
        let mid = bottom.start + bottom.length / 2
        let half = (running * Tune.gateSpan) / 2
        self.gateA = (mid - half).truncatingRemainder(dividingBy: running).wrapped(running)
        self.gateB = (mid + half).truncatingRemainder(dividingBy: running)
    }

    func wrap(_ s: CGFloat) -> CGFloat { s.wrapped(total) }

    func point(at s: CGFloat) -> CGPoint {
        let s = wrap(s)
        for g in segments where s <= g.start + g.length {
            let k = (s - g.start) / g.length
            if g.kind == .line {
                return CGPoint(x: g.x0 + (g.x1 - g.x0) * k, y: g.y0 + (g.y1 - g.y0) * k)
            }
            let a = g.a0 + (g.a1 - g.a0) * k
            return CGPoint(x: g.cx + cos(a) * radius, y: g.cy + sin(a) * radius)
        }
        return .zero
    }

    /// Outward normal, from the tangent. The loop is wound so that rotating the
    /// tangent by -90° always points away from the centre.
    func normal(at s: CGFloat) -> CGPoint {
        let e: CGFloat = 0.01
        let p0 = point(at: s - e), p1 = point(at: s + e)
        let tx = p1.x - p0.x, ty = p1.y - p0.y
        let m = max(0.000_1, sqrt(tx * tx + ty * ty))
        return CGPoint(x: ty / m, y: -tx / m)
    }

    /// The lit stretch — the only place a bag may be claimed.
    func inGate(_ s: CGFloat) -> Bool {
        let s = wrap(s)
        return gateA < gateB ? (s >= gateA && s <= gateB)
                             : (s >= gateA || s <= gateB)   // range wraps past zero
    }

    /// Behind the hall wall: hidden from the player, and not claimable.
    func inHall(_ s: CGFloat) -> Bool { point(at: s).y < Tune.wallZ }

    /// A world-space point on the belt surface, offset across the belt.
    func world(at s: CGFloat, offset: CGFloat = 0, height: CGFloat = Tune.beltY) -> Vec3 {
        let p = point(at: s), n = normal(at: s)
        return Vec3(p.x + n.x * offset, height, p.y + n.y * offset)
    }
}

extension CGFloat {
    /// Always-positive modulo. Negative arclengths wrap to the far end of the loop.
    func wrapped(_ m: CGFloat) -> CGFloat {
        let r = truncatingRemainder(dividingBy: m)
        return r < 0 ? r + m : r
    }
}
