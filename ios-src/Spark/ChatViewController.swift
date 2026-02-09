import UIKit
import SwiftUI

class ChatViewController: UIViewController {
    private var hostingController: UIHostingController<ChatView>?
    var matchData: [String: Any]?
    var onNavigateToTimer: (() -> Void)?
    var onNavigateToReveal: (() -> Void)?
    var onNavigateToRevealRequest: (() -> Void)?
    var onNavigateToSettings: (() -> Void)?
    var onNavigateToPlan: (() -> Void)?
    var onNavigateToRevealed: (() -> Void)?
    var onNavigateToLeft: (() -> Void)?
    var onLogout: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        var chatView = ChatView()
        chatView.matchData = matchData
        chatView.onNavigateToTimer = { [weak self] in self?.onNavigateToTimer?() }
        chatView.onNavigateToReveal = { [weak self] in self?.onNavigateToReveal?() }
        chatView.onNavigateToRevealRequest = { [weak self] in self?.onNavigateToRevealRequest?() }
        chatView.onNavigateToSettings = { [weak self] in self?.onNavigateToSettings?() }
        chatView.onNavigateToPlan = { [weak self] in self?.onNavigateToPlan?() }
        chatView.onNavigateToRevealed = { [weak self] in self?.onNavigateToRevealed?() }
        chatView.onNavigateToLeft = { [weak self] in self?.onNavigateToLeft?() }
        chatView.onLogout = { [weak self] in self?.onLogout?() }

        let hc = UIHostingController(rootView: chatView)
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
