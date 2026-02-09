import UIKit
import SwiftUI

// MARK: - Revealed VC
class RevealedViewController: UIViewController {
    var matchData: [String: Any]?
    var onKeepChatting: (() -> Void)?
    var onLeave: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        var v = RevealedView()
        v.matchData = matchData
        v.onKeepChatting = { [weak self] in self?.onKeepChatting?() }
        v.onLeave = { [weak self] in self?.onLeave?() }
        embed(v)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - Reveal Request VC
class RevealRequestViewController: UIViewController {
    var matchData: [String: Any]?
    var onAccepted: (() -> Void)?
    var onNotYet: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        var v = RevealRequestView()
        v.matchData = matchData
        v.onAccepted = { [weak self] in self?.onAccepted?() }
        v.onNotYet = { [weak self] in self?.onNotYet?() }
        embed(v)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - Signup VC
class SignupViewController: UIViewController {
    var userData: [String: Any]?
    var onSignupComplete: (() -> Void)?
    var onNavigateToLogin: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        var v = SignupView()
        v.userData = userData
        v.onSignupComplete = { [weak self] in self?.onSignupComplete?() }
        v.onNavigateToLogin = { [weak self] in self?.onNavigateToLogin?() }
        embed(v)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - Verify Email VC
class VerifyEmailViewController: UIViewController {
    var onVerified: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        var v = VerifyEmailView()
        v.onVerified = { [weak self] in self?.onVerified?() }
        embed(v)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - Forgot Password VC
class ForgotPasswordViewController: UIViewController {
    var onBack: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        var v = ForgotPasswordView()
        v.onBack = { [weak self] in self?.onBack?() }
        embed(v)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - Exit VC
class ExitViewController: UIViewController {
    var partnerName = ""
    var partnerAge = 0
    var onFindNewMatch: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        var v = ExitView()
        v.partnerName = partnerName
        v.partnerAge = partnerAge
        v.onFindNewMatch = { [weak self] in self?.onFindNewMatch?() }
        embed(v)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - Left VC
class LeftViewController: UIViewController {
    var partnerName = ""
    var onFindNewMatch: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        var v = LeftView()
        v.partnerName = partnerName
        v.onFindNewMatch = { [weak self] in self?.onFindNewMatch?() }
        embed(v)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - Pro Success VC
class ProSuccessViewController: UIViewController {
    var onContinue: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        var v = ProSuccessView()
        v.onContinue = { [weak self] in self?.onContinue?() }
        embed(v)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - Support VC
class SupportViewController: UIViewController {
    var onBack: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        var v = SupportView()
        v.onBack = { [weak self] in self?.onBack?() }
        embed(v)
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// MARK: - UIViewController Helper
extension UIViewController {
    func embed<V: View>(_ swiftUIView: V) {
        let hc = UIHostingController(rootView: swiftUIView)
        hc.view.backgroundColor = .black
        addChild(hc)
        view.addSubview(hc.view)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hc.didMove(toParent: self)
    }
}
