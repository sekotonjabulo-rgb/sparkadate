import UIKit
import SwiftUI
import WebKit

class SplashViewController: UIViewController {
    private var hostingController: UIHostingController<SplashScreenView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let splashView = SplashScreenView { [weak self] page in
            // Just dismiss splash - app.html is already loading in webview underneath
            self?.dismissSplash()
        }

        let hostingController = UIHostingController(rootView: splashView)
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

    private func dismissSplash() {
        // Simply dismiss - app.html is already loading underneath
        self.dismiss(animated: false, completion: nil)
    }
}
