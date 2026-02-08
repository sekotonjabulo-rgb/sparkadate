import UIKit
import SwiftUI
import WebKit

class SplashViewController: UIViewController {
    private var hostingController: UIHostingController<SplashScreenView>?
    var onComplete: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        let splashView = SplashScreenView { [weak self] destination in
            self?.onComplete?(destination)
            self?.dismissSplash()
        }

        let hostingController = UIHostingController(rootView: splashView)
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

    private func dismissSplash() {
        self.dismiss(animated: false, completion: nil)
    }
}
