import UIKit
import WebKit
import UserNotifications

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
    
    private(set) var webView: WKWebView!
    private var networkOverlay: UIView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebView()
        setupSwipeNavigation()
        setupConnectivityMonitoring()
        loadApp()
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - WebView Setup

    private func setupWebView() {
        let contentController = WKUserContentController()

        // Register native bridge handlers
        let handlers = [
            "nativeShare", "hapticFeedback", "setBadgeCount",
            "openExternalURL", "getDeviceInfo", "getPushToken",
            "showNativeAlert", "copyToClipboard", "setStatusBarStyle"
        ]
        for handler in handlers {
            contentController.add(self, name: handler)
        }

        // Inject the SparkNative JavaScript bridge
        let bridgeScript = WKUserScript(
            source: Self.nativeBridgeJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bridgeScript)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // Enable back-forward cache
        if #available(iOS 15.0, *) {
            configuration.preferences.isTextInteractionEnabled = true
        }

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black

        // Pull-to-refresh
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupSwipeNavigation() {
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgeSwipe(_:)))
        edgeSwipe.edges = .left
        view.addGestureRecognizer(edgeSwipe)
    }

    private func setupConnectivityMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    // MARK: - Loading

    private func loadApp() {
        guard let url = URL(string: "https://sparkadate.online/app.html") else { return }
        webView.load(URLRequest(url: url))
    }

    @objc private func handleRefresh(_ sender: UIRefreshControl) {
        webView.reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sender.endRefreshing()
        }
    }

    @objc private func handleEdgeSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .ended, webView.canGoBack {
            webView.goBack()
        }
    }

    @objc private func appDidBecomeActive() {
        // Clear badge when user opens the app
        UIApplication.shared.applicationIconBadgeNumber = 0
        webView.evaluateJavaScript("window.SparkNative && SparkNative._onResume && SparkNative._onResume()")
    }

    // MARK: - Deep Linking

    func navigateToPath(_ path: String) {
        let js = "window.SparkNative && SparkNative._onDeepLink && SparkNative._onDeepLink('\(path)');"
        webView.evaluateJavaScript(js)
    }

    // MARK: - Offline Handling

    private func showOfflineOverlay() {
        guard networkOverlay == nil else { return }

        let overlay = UIView()
        overlay.backgroundColor = .systemBackground
        overlay.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "wifi.slash"))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true

        let label = UILabel()
        label.text = "No internet connection"
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label

        let button = UIButton(type: .system)
        button.setTitle("Try Again", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(retryConnection), for: .touchUpInside)

        stack.addArrangedSubview(icon)
        stack.addArrangedSubview(label)
        stack.addArrangedSubview(button)
        overlay.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])

        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        networkOverlay = overlay
    }

    private func hideOfflineOverlay() {
        networkOverlay?.removeFromSuperview()
        networkOverlay = nil
    }

    @objc private func retryConnection() {
        hideOfflineOverlay()
        loadApp()
    }

    // MARK: - WKNavigationDelegate

func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    hideOfflineOverlay()
    let js = """
    document.dispatchEvent(new CustomEvent('SparkNativeReady'));
    """
    webView.evaluateJavaScript(js)
}

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain &&
            (nsError.code == NSURLErrorNotConnectedToInternet ||
             nsError.code == NSURLErrorTimedOut ||
             nsError.code == NSURLErrorNetworkConnectionLost) {
            showOfflineOverlay()
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // Allow navigation within sparkadate.online
        if let host = url.host, host.contains("sparkadate.online") {
            decisionHandler(.allow)
            return
        }

        // Open external URLs in Safari
        if navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    // MARK: - WKUIDelegate (JavaScript alerts)

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    // MARK: - WKScriptMessageHandler (Native Bridge)

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {

        case "nativeShare":
            handleShare(message.body)

        case "hapticFeedback":
            handleHaptic(message.body)

        case "setBadgeCount":
            if let count = message.body as? Int {
                UIApplication.shared.applicationIconBadgeNumber = count
            }

        case "openExternalURL":
            if let urlString = message.body as? String, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }

        case "getDeviceInfo":
            sendDeviceInfo()

        case "getPushToken":
            if let token = AppDelegate.shared?.deviceToken {
                webView.evaluateJavaScript("window.SparkNative._onPushToken('\(token)');")
            }

        case "showNativeAlert":
            handleNativeAlert(message.body)

        case "copyToClipboard":
            if let text = message.body as? String {
                UIPasteboard.general.string = text
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }

        case "setStatusBarStyle":
            // Reserved for future use
            break

        default:
            break
        }
    }

    // MARK: - Bridge Handlers

    private func handleShare(_ body: Any) {
        var items: [Any] = []
        if let dict = body as? [String: Any] {
            if let text = dict["text"] as? String { items.append(text) }
            if let urlString = dict["url"] as? String, let url = URL(string: urlString) { items.append(url) }
        } else if let text = body as? String {
            items.append(text)
        }
        guard !items.isEmpty else { return }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        present(activityVC, animated: true)
    }

    private func handleHaptic(_ body: Any) {
        let style = body as? String ?? "medium"
        switch style {
        case "light":
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case "heavy":
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case "success":
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case "warning":
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case "error":
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case "selection":
            UISelectionFeedbackGenerator().selectionChanged()
        default:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func sendDeviceInfo() {
        let device = UIDevice.current
        let info: [String: Any] = [
            "platform": "ios",
            "model": device.model,
            "systemVersion": device.systemVersion,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "buildNumber": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1",
            "bundleId": Bundle.main.bundleIdentifier ?? "",
            "screenWidth": UIScreen.main.bounds.width,
            "screenHeight": UIScreen.main.bounds.height,
            "scale": UIScreen.main.scale,
            "isNativeApp": true
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: info),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webView.evaluateJavaScript("window.SparkNative._onDeviceInfo(\(jsonString));")
        }
    }

    private func handleNativeAlert(_ body: Any) {
        guard let dict = body as? [String: Any],
              let title = dict["title"] as? String,
              let message = dict["message"] as? String else { return }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if let actions = dict["actions"] as? [[String: String]] {
            for action in actions {
                let style: UIAlertAction.Style = action["style"] == "destructive" ? .destructive :
                    action["style"] == "cancel" ? .cancel : .default
                alert.addAction(UIAlertAction(title: action["title"] ?? "OK", style: style) { [weak self] _ in
                    if let id = action["id"] {
                        self?.webView.evaluateJavaScript("window.SparkNative._onAlertAction('\(id)');")
                    }
                })
            }
        } else {
            alert.addAction(UIAlertAction(title: "OK", style: .default))
        }
        present(alert, animated: true)
    }

    // MARK: - JavaScript Bridge Source

    static let nativeBridgeJS = """
    (function() {
        window.SparkNative = {
            // Share content via native share sheet
            share: function(data) {
                window.webkit.messageHandlers.nativeShare.postMessage(data || {});
            },

            // Trigger haptic feedback
            // styles: 'light', 'medium', 'heavy', 'success', 'warning', 'error', 'selection'
            haptic: function(style) {
                window.webkit.messageHandlers.hapticFeedback.postMessage(style || 'medium');
            },

            // Set app icon badge count
            setBadge: function(count) {
                window.webkit.messageHandlers.setBadgeCount.postMessage(count || 0);
            },

            // Open URL in Safari
            openExternal: function(url) {
                window.webkit.messageHandlers.openExternalURL.postMessage(url);
            },

            // Request device info (async - listen via onDeviceInfo)
            getDeviceInfo: function() {
                window.webkit.messageHandlers.getDeviceInfo.postMessage({});
            },

            // Request push notification token (async - listen via onPushToken)
            getPushToken: function() {
                window.webkit.messageHandlers.getPushToken.postMessage({});
            },

            // Show native alert dialog
            showAlert: function(options) {
                window.webkit.messageHandlers.showNativeAlert.postMessage(options);
            },

            // Copy text to clipboard with haptic
            copyToClipboard: function(text) {
                window.webkit.messageHandlers.copyToClipboard.postMessage(text);
            },

            // Check if running inside the native app
            isNativeApp: true,
            platform: 'ios',

            // Callback registrations
            onPushToken: null,
            onDeepLink: null,
            onResume: null,
            onDeviceInfo: null,
            onAlertAction: null,

            // Internal callbacks (called from Swift)
            _onPushToken: function(token) {
                if (SparkNative.onPushToken) SparkNative.onPushToken(token);
            },
            _onDeepLink: function(path) {
                if (SparkNative.onDeepLink) SparkNative.onDeepLink(path);
            },
            _onResume: function() {
                if (SparkNative.onResume) SparkNative.onResume();
            },
            _onDeviceInfo: function(info) {
                if (SparkNative.onDeviceInfo) SparkNative.onDeviceInfo(info);
            },
            _onAlertAction: function(actionId) {
                if (SparkNative.onAlertAction) SparkNative.onAlertAction(actionId);
            }
        };

        // Dispatch event so web app knows native bridge is ready
        document.dispatchEvent(new CustomEvent('SparkNativeReady'));
    })();
    """;
}
