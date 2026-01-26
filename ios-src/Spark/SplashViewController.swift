import UIKit
import SwiftUI
import WebKit

class SplashViewController: UIViewController {
    private var hostingController: UIHostingController<SplashScreenView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let splashView = SplashScreenView { [weak self] page in
            self?.navigateToPage(page)
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

    private func navigateToPage(_ page: String) {
        // Dismiss splash and load the HTML page in webview
        self.dismiss(animated: false) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let mainVC = window.rootViewController as? ViewController else {
                return
            }

            let baseURL = rootUrl.deletingLastPathComponent()
            let targetURL = baseURL.appendingPathComponent(page)

            Spark.webView.load(URLRequest(url: targetURL))
            mainVC.webviewView.isHidden = false
            mainVC.loadingView.isHidden = false
        }
    }
}
