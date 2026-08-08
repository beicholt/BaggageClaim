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
        skView.showsFPS = false
        skView.showsNodeCount = false
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
