import UIKit
import SwiftUI

class LoginViewController: UIViewController {
    private var hostingController: UIHostingController<LoginView>?
    var onLoginSuccess: (() -> Void)?
    var onForgotPassword: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        var loginView = LoginView()
        loginView.onLoginSuccess = { [weak self] in
            self?.onLoginSuccess?()
        }
        loginView.onForgotPassword = { [weak self] in
            self?.onForgotPassword?()
        }

        let hostingController = UIHostingController(rootView: loginView)
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
