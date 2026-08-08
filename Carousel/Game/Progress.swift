import Foundation

/// What survives closing the app.
///
/// Small, but the difference between a game and a demo. Losing your belt
/// number because a call came in is the kind of thing a player forgives once.
enum Progress {

    private static let store = UserDefaults.standard
    private enum Key {
        static let belt = "carousel.belt"
        static let best = "carousel.bestScore"
        static let bestFlow = "carousel.bestFlow"
    }

    /// The furthest belt reached — where "Continue" picks up.
    static var belt: Int {
        get { max(1, store.integer(forKey: Key.belt)) }
        set { store.set(max(1, newValue), forKey: Key.belt) }
    }

    static var bestScore: Int {
        get { store.integer(forKey: Key.best) }
        set { if newValue > bestScore { store.set(newValue, forKey: Key.best) } }
    }

    static var bestFlow: Int {
        get { max(1, store.integer(forKey: Key.bestFlow)) }
        set { if newValue > bestFlow { store.set(newValue, forKey: Key.bestFlow) } }
    }

    static var hasPlayed: Bool { store.integer(forKey: Key.belt) > 0 }

    /// Only used by the debug entry points, so a QA run at belt nine does not
    /// quietly become the player's saved position.
    static var suspended = false

    static func record(belt: Int, score: Int, flow: Int) {
        guard !suspended else { return }
        if belt > self.belt { self.belt = belt }
        bestScore = score
        bestFlow = flow
    }
}
