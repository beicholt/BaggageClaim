import UIKit

/// Taptic feedback for the four things the player does.
///
/// Cheap to add and disproportionate in effect: a tap that answers in the hand
/// is most of the difference between a screen you are poking and a machine you
/// are operating. Generators are kept alive and prepared, because creating one
/// at the moment of use adds latency you can feel.
enum Haptics {

    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notice = UINotificationFeedbackGenerator()

    static func warm() {
        light.prepare()
        medium.prepare()
    }

    /// A bag leaves the belt.
    static func claim() {
        light.impactOccurred(intensity: 0.7)
        light.prepare()
    }

    /// Three matched. Intensity climbs with the flow multiplier, so a run you
    /// are on is something you can feel building.
    static func pop(step: Int) {
        medium.impactOccurred(intensity: min(1, 0.6 + CGFloat(step) * 0.14))
        medium.prepare()
    }

    /// A tap that could not be honoured — full tray, or a bag out of reach.
    static func refuse() {
        rigid.impactOccurred(intensity: 0.5)
        rigid.prepare()
    }

    static func won() { notice.notificationOccurred(.success) }
    static func lost() { notice.notificationOccurred(.error) }
}
