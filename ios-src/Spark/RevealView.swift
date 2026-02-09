import SwiftUI

class RevealViewModel: ObservableObject {
    @Published var state: RevealState = .initial
    @Published var isLoading = false

    private let api = SparkAPIService.shared
    private var pollTimer: Timer?
    var matchId: String = ""

    enum RevealState {
        case initial
        case waiting
        case revealed
    }

    func loadMatch(matchData: [String: Any]?) {
        if let match = matchData {
            matchId = match["id"] as? String ?? ""

            // Check if already in reveal state
            let revealStatus = match["reveal_status"] as? String ?? ""
            let userId = getCurrentUserId()
            let requestedBy = match["reveal_requested_by"] as? String

            if revealStatus == "both_revealed" || revealStatus == "revealed" {
                state = .revealed
            } else if requestedBy == userId {
                state = .waiting
                startPolling()
            }
        }
    }

    func requestReveal() {
        isLoading = true
        Task {
            do {
                let _ = try await api.apiRequest("/matches/\(matchId)/reveal", method: "POST")
                await MainActor.run {
                    self.isLoading = false
                    self.state = .waiting
                    self.startPolling()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkRevealStatus()
        }
    }

    private func checkRevealStatus() {
        Task {
            do {
                let result = try await api.apiRequest("/matches/current")
                await MainActor.run {
                    if let match = result["match"] as? [String: Any] {
                        let status = match["reveal_status"] as? String ?? ""
                        if status == "both_revealed" || status == "revealed" {
                            self.pollTimer?.invalidate()
                            self.state = .revealed
                        }
                    }
                }
            } catch {}
        }
    }

    func cleanup() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func getCurrentUserId() -> String {
        if let userData = UserDefaults.standard.data(forKey: "sparkUser"),
           let user = try? JSONSerialization.jsonObject(with: userData) as? [String: Any],
           let id = user["id"] as? String {
            return id
        }
        return ""
    }
}

struct RevealView: View {
    @StateObject private var viewModel = RevealViewModel()
    @State private var opacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    var matchData: [String: Any]?
    var onBack: (() -> Void)?
    var onRevealed: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { onBack?() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Reveal")
                        .font(.customFont("CabinetGrotesk-Medium", size: 17))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)

                Spacer()

                // Center content
                VStack(spacing: 20) {
                    // Eye icon
                    Image(systemName: "eye.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color.white.opacity(viewModel.state == .waiting ? 0.8 : 0.5))
                        .scaleEffect(pulseScale)

                    switch viewModel.state {
                    case .initial:
                        initialContent

                    case .waiting:
                        waitingContent

                    case .revealed:
                        revealedContent
                    }
                }

                Spacer()

                // Actions
                if viewModel.state == .initial {
                    VStack(spacing: 16) {
                        SparkButton(title: viewModel.isLoading ? "Requesting..." : "Request Reveal", isEnabled: !viewModel.isLoading) {
                            viewModel.requestReveal()
                        }

                        Button(action: { onBack?() }) {
                            Text("Not yet")
                                .font(.customFont("CabinetGrotesk-Medium", size: 15))
                                .foregroundColor(Color.white.opacity(0.65))
                        }
                        .buttonStyle(OnboardingLinkStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 48)
                }
            }
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            viewModel.loadMatch(matchData: matchData)
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
            }
            // Start pulse animation for waiting state
            startPulse()
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.state) { newState in
            if newState == .revealed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onRevealed?()
                }
            }
        }
    }

    private var initialContent: some View {
        VStack(spacing: 8) {
            Text("Ready to reveal?")
                .font(.customFont("CabinetGrotesk-Medium", size: 24))
                .foregroundColor(.white)

            Text("Both of you need to agree to see\neach other's photos")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private var waitingContent: some View {
        VStack(spacing: 8) {
            Text("Reveal requested")
                .font(.customFont("CabinetGrotesk-Medium", size: 24))
                .foregroundColor(.white)

            Text("Waiting for your match to accept...")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private var revealedContent: some View {
        VStack(spacing: 8) {
            Text("Photos revealed!")
                .font(.customFont("CabinetGrotesk-Medium", size: 24))
                .foregroundColor(.white)

            Text("You can now see each other")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
    }
}
