import UIKit
import SwiftUI

class MatchViewController: UIViewController {
    private var hostingController: UIHostingController<MatchView>?
    var onNavigateToChat: (() -> Void)?
    var onNavigateToPlan: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        var matchView = MatchView()
        matchView.onNavigateToChat = { [weak self] in
            self?.onNavigateToChat?()
        }
        matchView.onNavigateToPlan = { [weak self] in
            self?.onNavigateToPlan?()
        }

        let hostingController = UIHostingController(rootView: matchView)
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
