import UIKit
import SwiftUI

class Onboarding1ViewController: UIViewController {
    private var hostingController: UIHostingController<Onboarding1View>?
    var onNavigateToSignup: (([String: Any]) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        var onboarding1View = Onboarding1View()
        onboarding1View.onNavigateToSignup = { [weak self] userData in
            self?.onNavigateToSignup?(userData)
        }

        let hostingController = UIHostingController(rootView: onboarding1View)
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
