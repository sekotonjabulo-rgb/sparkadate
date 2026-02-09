import UIKit
import SwiftUI

class SettingsViewController: UIViewController {
    private var hostingController: UIHostingController<SettingsView>?
    var onBack: (() -> Void)?
    var onLogout: (() -> Void)?
    var onNavigateToPlan: (() -> Void)?
    var onNavigateToSupport: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        var settingsView = SettingsView()
        settingsView.onBack = { [weak self] in self?.onBack?() }
        settingsView.onLogout = { [weak self] in self?.onLogout?() }
        settingsView.onNavigateToPlan = { [weak self] in self?.onNavigateToPlan?() }
        settingsView.onNavigateToSupport = { [weak self] in self?.onNavigateToSupport?() }

        let hc = UIHostingController(rootView: settingsView)
        hc.view.backgroundColor = .black
        hostingController = hc
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

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
