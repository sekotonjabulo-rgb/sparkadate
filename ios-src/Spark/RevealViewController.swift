import UIKit
import SwiftUI

class RevealViewController: UIViewController {
    private var hostingController: UIHostingController<RevealView>?
    var matchData: [String: Any]?
    var onBack: (() -> Void)?
    var onRevealed: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        var revealView = RevealView()
        revealView.matchData = matchData
        revealView.onBack = { [weak self] in
            self?.onBack?()
        }
        revealView.onRevealed = { [weak self] in
            self?.onRevealed?()
        }

        let hostingController = UIHostingController(rootView: revealView)
        hostingController.view.backgroundColor = .black
        self.hostingController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
