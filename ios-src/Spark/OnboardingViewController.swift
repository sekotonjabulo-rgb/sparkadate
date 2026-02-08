import UIKit
import SwiftUI

class OnboardingViewController: UIViewController {
    private var hostingController: UIHostingController<OnboardingView>?
    var onNavigate: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        let onboardingView = OnboardingView { [weak self] page in
            self?.navigateToPage(page)
        }

        let hostingController = UIHostingController(rootView: onboardingView)
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

    private func navigateToPage(_ page: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let onNavigate = self.onNavigate {
                // Use the callback if provided (when presented from ViewController)
                onNavigate(page)
            } else {
                // Fallback: navigate via WebView directly
                let baseURL = rootUrl.deletingLastPathComponent()
                let targetURL = baseURL.appendingPathComponent(page)

                self.dismiss(animated: true) {
                    if Spark.webView != nil {
                        Spark.webView.load(URLRequest(url: targetURL))
                    }

                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first,
                       let mainVC = window.rootViewController as? ViewController {
                        mainVC.webviewView.isHidden = false
                        mainVC.loadingView.isHidden = false
                    }
                }
            }
        }
    }
}
