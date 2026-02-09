import UIKit
import WebKit

class ViewController: UIViewController, WKNavigationDelegate, UIDocumentInteractionControllerDelegate {
    
    var documentController: UIDocumentInteractionController?
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var connectionProblemView: UIImageView!
    @IBOutlet weak var webviewView: UIView!
    var toolbarView: UIToolbar!
    
    var htmlIsLoaded = false;
    
    private var themeObservation: NSKeyValueObservation?
    var currentWebViewTheme: UIUserInterfaceStyle = .unspecified
    override var preferredStatusBarStyle : UIStatusBarStyle {
        if #available(iOS 13, *), overrideStatusBar{
            if #available(iOS 15, *) {
                return .default
            } else {
                return statusBarTheme == "dark" ? .lightContent : .darkContent
            }
        }
        return .default
    }

    private var splashViewController: SplashViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        initWebView()
        initToolbarView()

        // Load WebView in the background while splash shows
        loadRootUrl()

        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification , object: nil)

        // Add splash as child view controller overlay (present() doesn't work in viewDidLoad)
        showSplashScreen()
    }

    private func showSplashScreen() {
        let splashVC = SplashViewController()
        splashViewController = splashVC

        // Add as child view controller so it overlays everything
        addChild(splashVC)
        splashVC.view.frame = view.bounds
        splashVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(splashVC.view)
        splashVC.didMove(toParent: self)

        splashVC.onComplete = { [weak self] destination in
            guard let self = self else { return }

            // Remove splash overlay
            splashVC.willMove(toParent: nil)
            splashVC.view.removeFromSuperview()
            splashVC.removeFromParent()
            self.splashViewController = nil

            // Route all known pages to native screens
            self.routeToPage(destination)
        }
    }

    private func showOnboarding() {
        let onboardingVC = OnboardingViewController()
        onboardingVC.modalPresentationStyle = .fullScreen
        onboardingVC.onNavigate = { [weak self] page in
            guard let self = self else { return }

            // Route to native screens instead of web
            if page == "onboarding1.html" {
                onboardingVC.dismiss(animated: false) {
                    self.showOnboarding1()
                }
            } else if page == "login.html" {
                onboardingVC.dismiss(animated: false) {
                    self.showLogin()
                }
            } else {
                if let url = URL(string: "https://sparkadate.online/\(page)") {
                    Spark.webView.load(URLRequest(url: url))
                }
                onboardingVC.dismiss(animated: false, completion: nil)
            }
        }
        presentNative(onboardingVC)
    }

    private func showOnboarding1() {
        let onboarding1VC = Onboarding1ViewController()
        onboarding1VC.modalPresentationStyle = .fullScreen
        onboarding1VC.onNavigateToSignup = { [weak self] userData in
            guard let self = self else { return }
            onboarding1VC.dismiss(animated: false) {
                self.showSignup(userData: userData)
            }
        }
        presentNative(onboarding1VC)
    }

    private func showLogin() {
        let loginVC = LoginViewController()
        loginVC.modalPresentationStyle = .fullScreen
        loginVC.onLoginSuccess = { [weak self] in
            guard let self = self else { return }

            // Sync token to WebView
            if let token = UserDefaults.standard.string(forKey: "sparkToken") {
                let js = "localStorage.setItem('sparkToken', '\(token)');"
                Spark.webView.evaluateJavaScript(js)
            }

            loginVC.dismiss(animated: false) {
                if UserDefaults.standard.string(forKey: "sparkPlanCompleted") != nil {
                    self.showMatch()
                } else {
                    self.showPlan()
                }
            }
        }
        loginVC.onForgotPassword = { [weak self] in
            guard let self = self else { return }
            loginVC.dismiss(animated: false) { self.showForgotPassword() }
        }
        presentNative(loginVC)
    }

    private func showMatch() {
        let matchVC = MatchViewController()
        matchVC.modalPresentationStyle = .fullScreen
        matchVC.onNavigateToChat = { [weak self] in
            guard let self = self else { return }
            matchVC.dismiss(animated: false) { self.showChat(matchData: nil) }
        }
        matchVC.onNavigateToPlan = { [weak self] in
            guard let self = self else { return }
            matchVC.dismiss(animated: false) { self.showPlan() }
        }
        presentNative(matchVC)
    }

    private func showPlan() {
        let planVC = PlanViewController()
        planVC.modalPresentationStyle = .fullScreen
        planVC.onNavigateToMatch = { [weak self] in
            guard let self = self else { return }
            planVC.dismiss(animated: false) { self.showMatch() }
        }
        planVC.onSelectPro = { [weak self] checkoutURL in
            guard let self = self else { return }
            if let url = URL(string: checkoutURL) {
                Spark.webView.load(URLRequest(url: url))
            }
            planVC.dismiss(animated: false, completion: nil)
        }
        presentNative(planVC)
    }

    private func showTimer(matchData: [String: Any]?) {
        let timerVC = TimerViewController()
        timerVC.modalPresentationStyle = .fullScreen
        timerVC.matchData = matchData
        timerVC.onBack = { [weak self] in
            guard let self = self else { return }
            timerVC.dismiss(animated: false) { self.showChat(matchData: matchData) }
        }
        timerVC.onRevealed = { [weak self] in
            guard let self = self else { return }
            timerVC.dismiss(animated: false) { self.showReveal(matchData: matchData) }
        }
        timerVC.onSkip = { [weak self] in
            guard let self = self else { return }
            timerVC.dismiss(animated: false) { self.showMatch() }
        }
        timerVC.onUpgrade = { [weak self] in
            guard let self = self else { return }
            timerVC.dismiss(animated: false) { self.showPlan() }
        }
        presentNative(timerVC)
    }

    private func showReveal(matchData: [String: Any]?) {
        let revealVC = RevealViewController()
        revealVC.modalPresentationStyle = .fullScreen
        revealVC.matchData = matchData
        revealVC.onBack = { [weak self] in
            guard let self = self else { return }
            revealVC.dismiss(animated: false) { self.showChat(matchData: matchData) }
        }
        revealVC.onRevealed = { [weak self] in
            guard let self = self else { return }
            revealVC.dismiss(animated: false) { self.showRevealed(matchData: matchData) }
        }
        presentNative(revealVC)
    }

    // MARK: - Route Helper
    private func routeToPage(_ page: String) {
        switch page {
        case "onboarding":
            showOnboarding()
        case "match.html":
            showMatch()
        case "plan.html":
            showPlan()
        case "timer.html":
            showTimer(matchData: nil)
        case "reveal.html":
            showReveal(matchData: nil)
        case "chat.html":
            showChat(matchData: nil)
        case "settings.html":
            showSettings()
        case "revealed.html":
            showRevealed(matchData: nil)
        case "revealrequest.html":
            showRevealRequest(matchData: nil)
        case "left.html":
            showLeft(partnerName: "")
        case "exit.html":
            showExit(partnerName: "", partnerAge: 0)
        case "prosuccess.html":
            showProSuccess()
        case "support.html":
            showSupport()
        case "login.html":
            showLogin()
        case "signup.html":
            showSignup(userData: nil)
        case "verify-email.html":
            showVerifyEmail()
        case "forgot-password.html":
            showForgotPassword()
        default:
            // Fall back to WebView for unknown pages
            if let url = URL(string: "https://sparkadate.online/\(page)") {
                Spark.webView.load(URLRequest(url: url))
            }
        }
    }

    // MARK: - Chat
    private func showChat(matchData: [String: Any]?) {
        let chatVC = ChatViewController()
        chatVC.modalPresentationStyle = .fullScreen
        chatVC.matchData = matchData
        chatVC.onNavigateToTimer = { [weak self] in
            guard let self = self else { return }
            chatVC.dismiss(animated: false) { self.showTimer(matchData: matchData) }
        }
        chatVC.onNavigateToReveal = { [weak self] in
            guard let self = self else { return }
            chatVC.dismiss(animated: false) { self.showReveal(matchData: matchData) }
        }
        chatVC.onNavigateToRevealRequest = { [weak self] in
            guard let self = self else { return }
            chatVC.dismiss(animated: false) { self.showRevealRequest(matchData: matchData) }
        }
        chatVC.onNavigateToSettings = { [weak self] in
            guard let self = self else { return }
            chatVC.dismiss(animated: false) { self.showSettings() }
        }
        chatVC.onNavigateToPlan = { [weak self] in
            guard let self = self else { return }
            chatVC.dismiss(animated: false) { self.showPlan() }
        }
        chatVC.onNavigateToRevealed = { [weak self] in
            guard let self = self else { return }
            chatVC.dismiss(animated: false) { self.showRevealed(matchData: matchData) }
        }
        chatVC.onNavigateToLeft = { [weak self] in
            guard let self = self else { return }
            chatVC.dismiss(animated: false) { self.showLeft(partnerName: matchData?["name"] as? String ?? "") }
        }
        chatVC.onLogout = { [weak self] in
            guard let self = self else { return }
            self.performLogout(from: chatVC)
        }
        presentNative(chatVC)
    }

    // MARK: - Settings
    private func showSettings() {
        let settingsVC = SettingsViewController()
        settingsVC.modalPresentationStyle = .fullScreen
        settingsVC.onBack = { [weak self] in
            guard let self = self else { return }
            settingsVC.dismiss(animated: false) { self.showChat(matchData: nil) }
        }
        settingsVC.onLogout = { [weak self] in
            guard let self = self else { return }
            self.performLogout(from: settingsVC)
        }
        settingsVC.onNavigateToPlan = { [weak self] in
            guard let self = self else { return }
            settingsVC.dismiss(animated: false) { self.showPlan() }
        }
        settingsVC.onNavigateToSupport = { [weak self] in
            guard let self = self else { return }
            settingsVC.dismiss(animated: false) { self.showSupport() }
        }
        presentNative(settingsVC)
    }

    // MARK: - Revealed
    private func showRevealed(matchData: [String: Any]?) {
        let vc = RevealedViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.matchData = matchData
        vc.onKeepChatting = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showChat(matchData: matchData) }
        }
        vc.onLeave = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) {
                self.showExit(
                    partnerName: matchData?["name"] as? String ?? "",
                    partnerAge: matchData?["age"] as? Int ?? 0
                )
            }
        }
        presentNative(vc)
    }

    // MARK: - Reveal Request
    private func showRevealRequest(matchData: [String: Any]?) {
        let vc = RevealRequestViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.matchData = matchData
        vc.onAccepted = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showRevealed(matchData: matchData) }
        }
        vc.onNotYet = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showChat(matchData: matchData) }
        }
        presentNative(vc)
    }

    // MARK: - Signup
    private func showSignup(userData: [String: Any]?) {
        let vc = SignupViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.userData = userData
        vc.onSignupComplete = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showVerifyEmail() }
        }
        vc.onNavigateToLogin = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showLogin() }
        }
        presentNative(vc)
    }

    // MARK: - Verify Email
    private func showVerifyEmail() {
        let vc = VerifyEmailViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onVerified = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showPlan() }
        }
        presentNative(vc)
    }

    // MARK: - Forgot Password
    private func showForgotPassword() {
        let vc = ForgotPasswordViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onBack = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showLogin() }
        }
        presentNative(vc)
    }

    // MARK: - Exit
    private func showExit(partnerName: String, partnerAge: Int) {
        let vc = ExitViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.partnerName = partnerName
        vc.partnerAge = partnerAge
        vc.onFindNewMatch = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showMatch() }
        }
        presentNative(vc)
    }

    // MARK: - Left (partner left)
    private func showLeft(partnerName: String) {
        let vc = LeftViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.partnerName = partnerName
        vc.onFindNewMatch = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showMatch() }
        }
        presentNative(vc)
    }

    // MARK: - Pro Success
    private func showProSuccess() {
        let vc = ProSuccessViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onContinue = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showMatch() }
        }
        presentNative(vc)
    }

    // MARK: - Support
    private func showSupport() {
        let vc = SupportViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onBack = { [weak self] in
            guard let self = self else { return }
            vc.dismiss(animated: false) { self.showSettings() }
        }
        presentNative(vc)
    }

    // MARK: - Helpers
    private func presentNative(_ vc: UIViewController) {
        DispatchQueue.main.async {
            // Dismiss any existing presented VC first
            if let presented = self.presentedViewController {
                presented.dismiss(animated: false) {
                    self.present(vc, animated: false, completion: nil)
                }
            } else {
                self.present(vc, animated: false, completion: nil)
            }
        }
    }

    private func performLogout(from vc: UIViewController) {
        UserDefaults.standard.removeObject(forKey: "sparkToken")
        UserDefaults.standard.removeObject(forKey: "sparkUser")
        UserDefaults.standard.removeObject(forKey: "sparkCurrentMatch")
        UserDefaults.standard.removeObject(forKey: "sparkLastPage")
        UserDefaults.standard.removeObject(forKey: "sparkPlanCompleted")
        vc.dismiss(animated: false) {
            self.showOnboarding()
        }
    }

    func hideSplashScreen() {
        if let splashVC = splashViewController {
            splashVC.willMove(toParent: nil)
            splashVC.view.removeFromSuperview()
            splashVC.removeFromParent()
            splashViewController = nil
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        Spark.webView.frame = calcWebviewFrame(webviewView: webviewView, toolbarView: nil)
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        Spark.webView.setNeedsLayout()
    }
    
    func initWebView() {
        if Spark.webView == nil {
            Spark.webView = createWebView(container: webviewView, WKSMH: self, WKND: self, NSO: self, VC: self)
        }
        webviewView.addSubview(Spark.webView);
        
        Spark.webView.uiDelegate = self;
        
        Spark.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        if pullToRefresh {
            #if !targetEnvironment(macCatalyst)
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(refreshWebView(_:)), for: .valueChanged)
            Spark.webView.scrollView.addSubview(refreshControl)
            Spark.webView.scrollView.bounces = true
            #endif
        }

        if #available(iOS 15.0, *), adaptiveUIStyle {
            themeObservation = Spark.webView.observe(\.underPageBackgroundColor) { [unowned self] webView, _ in
                currentWebViewTheme = Spark.webView.underPageBackgroundColor.isLight() ?? true ? .light : .dark
                self.overrideUIStyle()
            }
        }
    }

    @objc func refreshWebView(_ sender: UIRefreshControl) {
        Spark.webView?.reload()
        sender.endRefreshing()
    }

    func createToolbarView() -> UIToolbar{
        let winScene = UIApplication.shared.connectedScenes.first
        let windowScene = winScene as! UIWindowScene
        var statusBarHeight = windowScene.statusBarManager?.statusBarFrame.height ?? 60
        
        #if targetEnvironment(macCatalyst)
        if (statusBarHeight == 0){
            statusBarHeight = 30
        }
        #endif
        
        let toolbarView = UIToolbar(frame: CGRect(x: 0, y: 0, width: webviewView.frame.width, height: 0))
        toolbarView.sizeToFit()
        toolbarView.frame = CGRect(x: 0, y: 0, width: webviewView.frame.width, height: toolbarView.frame.height + statusBarHeight)
//        toolbarView.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin, .flexibleWidth]
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let close = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(loadRootUrl))
        toolbarView.setItems([close,flex], animated: true)
        
        toolbarView.isHidden = true
        
        return toolbarView
    }
    
    func overrideUIStyle(toDefault: Bool = false) {
        if #available(iOS 15.0, *), adaptiveUIStyle {
            if (((htmlIsLoaded && !Spark.webView.isHidden) || toDefault) && self.currentWebViewTheme != .unspecified) {
                UIApplication
                    .shared
                    .connectedScenes
                    .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
                    .first { $0.isKeyWindow }?.overrideUserInterfaceStyle = toDefault ? .unspecified : self.currentWebViewTheme;
            }
        }
    }
    
    func initToolbarView() {
        toolbarView =  createToolbarView()
        
        webviewView.addSubview(toolbarView)
    }
    
    @objc func loadRootUrl() {
        Spark.webView.load(URLRequest(url: SceneDelegate.universalLinkToLaunch ?? SceneDelegate.shortcutLinkToLaunch ?? rootUrl))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!){
        htmlIsLoaded = true
        
        self.setProgress(1.0, true)
        self.animateConnectionProblem(false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            Spark.webView.isHidden = false
            self.loadingView.isHidden = true
           
            self.setProgress(0.0, false)
            
            self.overrideUIStyle()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        htmlIsLoaded = false;
        
        if (error as NSError)._code != (-999) {
            self.overrideUIStyle(toDefault: true);

            webView.isHidden = true;
            loadingView.isHidden = false;
            animateConnectionProblem(true);
            
            setProgress(0.05, true);

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.setProgress(0.1, true);
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.loadRootUrl();
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if (keyPath == #keyPath(WKWebView.estimatedProgress) &&
                Spark.webView.isLoading &&
                !self.loadingView.isHidden &&
                !self.htmlIsLoaded) {
                    var progress = Float(Spark.webView.estimatedProgress);
                    
                    if (progress >= 0.8) { progress = 1.0; };
                    if (progress >= 0.3) { self.animateConnectionProblem(false); }
                    
                    self.setProgress(progress, true);
        }
    }
    
    func setProgress(_ progress: Float, _ animated: Bool) {
        self.progressView.setProgress(progress, animated: animated);
    }
    
    
    func animateConnectionProblem(_ show: Bool) {
        if (show) {
            self.connectionProblemView.isHidden = false;
            self.connectionProblemView.alpha = 0
            UIView.animate(withDuration: 0.7, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.connectionProblemView.alpha = 1
            })
        }
        else {
            UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
                self.connectionProblemView.alpha = 0 // Here you will get the animation you want
            }, completion: { _ in
                self.connectionProblemView.isHidden = true;
                self.connectionProblemView.layer.removeAllAnimations();
            })
        }
    }
        
    deinit {
        Spark.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}

extension UIColor {
    // Check if the color is light or dark, as defined by the injected lightness threshold.
    // Some people report that 0.7 is best. I suggest to find out for yourself.
    // A nil value is returned if the lightness couldn't be determined.
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor

        // Now we need to convert it to the RGB colorspace. UIColor.white / UIColor.black are greyscale and not RGB.
        // If you don't do this then you will crash when accessing components index 2 below when evaluating greyscale colors.
        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold)
    }
}

extension ViewController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "print" {
            printView(webView: Spark.webView)
        }
        if message.name == "push-subscribe" {
            handleSubscribeTouch(message: message)
        }
        if message.name == "push-permission-request" {
            handlePushPermission()
        }
        if message.name == "push-permission-state" {
            handlePushState()
        }
        if message.name == "push-token" {
            handleFCMToken()
        }
  }
}
