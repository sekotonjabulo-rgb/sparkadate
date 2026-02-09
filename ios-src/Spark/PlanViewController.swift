import UIKit
import SwiftUI

class PlanViewController: UIViewController {
    private var hostingController: UIHostingController<PlanView>?
    var onNavigateToMatch: (() -> Void)?
    var onSelectPro: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        var planView = PlanView()
        planView.onNavigateToMatch = { [weak self] in
            self?.onNavigateToMatch?()
        }
        planView.onSelectPro = { [weak self] checkoutURL in
            self?.onSelectPro?(checkoutURL)
        }

        let hostingController = UIHostingController(rootView: planView)
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
