import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate {

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        if let url = URL(string: "https://sparkadate.online/app.html") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
