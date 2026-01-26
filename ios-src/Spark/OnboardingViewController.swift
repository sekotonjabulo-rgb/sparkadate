import UIKit
import SwiftUI

class OnboardingViewController: UIViewController {
    private var hostingController: UIHostingController<OnboardingView>?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set black background to match OnboardingView
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
    
    private func navigateToPage(_ page: String) {
        // Convert page name to URL and load in WebView
        let baseURL = rootUrl.deletingLastPathComponent()
        let targetURL = baseURL.appendingPathComponent(page)
        
        // Navigate to the page in the WebView
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Dismiss onboarding screen and load the target page
            self.dismiss(animated: true) {
                if Spark.webView != nil {
                    Spark.webView.load(URLRequest(url: targetURL))
                } else {
                    // Fallback: load root URL
                    Spark.webView?.load(URLRequest(url: rootUrl))
                }
                
                // Show the main view controller's WebView
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

