import CoreGraphics
import Foundation

struct Vec3 {
    var x: CGFloat, y: CGFloat, z: CGFloat
    init(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) { self.x = x; self.y = y; self.z = z }

    static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(a.x + b.x, a.y + b.y, a.z + b.z) }
    static func * (a: Vec3, k: CGFloat) -> Vec3 { Vec3(a.x * k, a.y * k, a.z * k) }

    func dot(_ o: Vec3) -> CGFloat { x * o.x + y * o.y + z * o.z }
    func cross(_ o: Vec3) -> Vec3 {
        Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x)
    }
    var normalized: Vec3 {
        let m = sqrt(x * x + y * y + z * z)
        return m == 0 ? self : Vec3(x / m, y / m, z / m)
    }
}

/// A fixed perspective camera, reduced to the two things the game needs: where
/// a world point lands on screen, and how many points long a world unit is
/// once it gets there.
///
/// The camera never moves, so this is arithmetic rather than a 3D engine. It
/// reproduces the prototype's three.js camera exactly — same pitch, same field
/// of view, same distance solve, same downward tip — so the loop lands in the
/// same place on screen and every rule written against world units still holds.
struct Projection {
    /// Screen size in points. Y grows upward, SpriteKit style.
    let size: CGSize

    private let eye: Vec3
    private let axisX: Vec3
    private let axisY: Vec3
    private let axisZ: Vec3      // points backward, away from what the camera sees
    private let tanHalfV: CGFloat

    init(size: CGSize) {
        self.size = size
        let aspect = size.width / max(1, size.height)
        let vFov = Tune.camFov * .pi / 180
        let tanHalfV = tan(vFov / 2)
        let tanHalfH = tanHalfV * aspect

        // Depth foreshortens into screen height, so the vertical requirement is
        // the loop's depth laid down by the pitch plus headroom for a standing
        // bag, fitted into the part of the frame the tray does not cover.
        let dist = max(Tune.fitX / tanHalfH,
                       (Tune.fitZ * sin(Tune.camPitch) + 1.5) / tan((vFov / 2) * (1 - Tune.bottomReserve)))

        let target = Tune.camTarget
        let eye = Vec3(target.x,
                       target.y + sin(Tune.camPitch) * dist,
                       target.z + cos(Tune.camPitch) * dist)

        // lookAt: z points from target back to the eye, x is right, y is up.
        let z = (eye - target).normalized
        let x = Vec3(0, 1, 0).cross(z).normalized
        let y = z.cross(x)

        // Then tip the view down, which slides the hall up the screen and parks
        // the reserved band under the tray instead of over the belt.
        let t = -(Tune.bottomReserve / 2) * vFov
        self.eye = eye
        self.axisX = x
        self.axisY = y * cos(t) + z * sin(t)
        self.axisZ = z * cos(t) - y * sin(t)
        self.tanHalfV = tanHalfV
    }

    /// Distance in front of the camera. Positive means visible.
    func depth(of p: Vec3) -> CGFloat { -(p - eye).dot(axisZ) }

    func project(_ p: Vec3) -> CGPoint {
        let d = p - eye
        let zc = -d.dot(axisZ)
        guard zc > 0.01 else { return CGPoint(x: -9999, y: -9999) }
        let scale = size.height / (2 * tanHalfV * zc)
        return CGPoint(x: size.width / 2 + d.dot(axisX) * scale,
                       y: size.height / 2 + d.dot(axisY) * scale)
    }

    func project(x: CGFloat, y: CGFloat, z: CGFloat) -> CGPoint {
        project(Vec3(x, y, z))
    }

    /// Points on screen per world unit at the given depth.
    func scale(atDepth zc: CGFloat) -> CGFloat {
        guard zc > 0.01 else { return 0 }
        return size.height / (2 * tanHalfV * zc)
    }
}
