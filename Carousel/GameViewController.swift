import UIKit
import SpriteKit

final class GameViewController: UIViewController {

    private var skView: SKView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = false      // the belt depends on zPosition order
        // CAROUSEL_STATS=1 turns on the frame counter. Off by default so a
        // release build cannot ship with a debug overlay on it.
        let stats = ProcessInfo.processInfo.environment["CAROUSEL_STATS"] == "1"
        skView.showsFPS = stats
        skView.showsNodeCount = stats
        skView.showsDrawCount = stats
        view.addSubview(skView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Present after the first layout pass so the scene sees final bounds
        // and real safe-area insets — both are still zero in viewDidLoad, and
        // the camera solve depends on the aspect ratio.
        guard skView.scene == nil, skView.bounds.width > 1 else { return }
        let scene = GameScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { true }
}
