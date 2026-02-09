import UIKit
import SwiftUI

class TimerViewController: UIViewController {
    private var hostingController: UIHostingController<TimerView>?
    var matchData: [String: Any]?
    var onBack: (() -> Void)?
    var onRevealed: (() -> Void)?
    var onSkip: (() -> Void)?
    var onUpgrade: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        var timerView = TimerView()
        timerView.matchData = matchData
        timerView.onBack = { [weak self] in
            self?.onBack?()
        }
        timerView.onRevealed = { [weak self] in
            self?.onRevealed?()
        }
        timerView.onSkip = { [weak self] in
            self?.onSkip?()
        }
        timerView.onUpgrade = { [weak self] in
            self?.onUpgrade?()
        }

        let hostingController = UIHostingController(rootView: timerView)
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
