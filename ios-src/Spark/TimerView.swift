import SwiftUI

class TimerViewModel: ObservableObject {
    @Published var timeRemaining: TimeInterval = 0
    @Published var timerText: String = "00:00:00"
    @Published var subscriptionTier: String = "free"
    @Published var exitsRemaining: Int = 3
    @Published var isLoading = true

    private var countdownTimer: Timer?
    private var profilePollTimer: Timer?
    private let api = SparkAPIService.shared
    var matchId: String = ""
    var revealTime: Date?

    func loadData(matchData: [String: Any]?) {
        if let match = matchData {
            matchId = match["id"] as? String ?? ""
            if let revealTimeStr = match["reveal_time"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                revealTime = formatter.date(from: revealTimeStr)
            }
        }

        fetchProfile()
        startCountdown()
        startProfilePolling()
    }

    func fetchProfile() {
        Task {
            do {
                let result = try await api.apiRequest("/users/me")
                await MainActor.run {
                    if let user = result["user"] as? [String: Any] {
                        self.subscriptionTier = user["subscription_tier"] as? String ?? "free"
                        self.exitsRemaining = user["exits_remaining"] as? Int ?? 3
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }

    private func updateTimer() {
        guard let revealTime = revealTime else {
            timerText = "00:00:00"
            return
        }

        timeRemaining = revealTime.timeIntervalSince(Date())

        if timeRemaining <= 0 {
            timerText = "00:00:00"
            countdownTimer?.invalidate()
            return
        }

        let days = Int(timeRemaining) / 86400
        let hours = (Int(timeRemaining) % 86400) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60

        if days > 0 {
            timerText = "\(days)d \(hours)h \(minutes)m"
        } else {
            timerText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }

    func startProfilePolling() {
        profilePollTimer?.invalidate()
        profilePollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.fetchProfile()
        }
    }

    func skipMatch() async throws {
        let _ = try await api.apiRequest("/matches/\(matchId)/exit", method: "POST")
    }

    func forceReveal() async throws {
        let _ = try await api.apiRequest("/matches/\(matchId)/force-reveal", method: "POST")
    }

    func cleanup() {
        countdownTimer?.invalidate()
        profilePollTimer?.invalidate()
    }

    var skipButtonTitle: String {
        if subscriptionTier == "pro" {
            return "Skip match"
        } else if exitsRemaining > 0 {
            return "Skip match"
        } else {
            return "Upgrade to Pro"
        }
    }

    var skipSubtext: String {
        if subscriptionTier == "pro" {
            return "Unlimited skips with Pro"
        } else if exitsRemaining > 0 {
            return "\(exitsRemaining) skip\(exitsRemaining == 1 ? "" : "s") remaining"
        } else {
            return "No skips remaining"
        }
    }

    var canSkip: Bool {
        subscriptionTier == "pro" || exitsRemaining > 0
    }
}

struct TimerView: View {
    @StateObject private var viewModel = TimerViewModel()
    @State private var opacity: Double = 0
    var matchData: [String: Any]?
    var onBack: (() -> Void)?
    var onSkip: (() -> Void)?
    var onRevealed: (() -> Void)?
    var onUpgrade: (() -> Void)?

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
                    Text("Timer")
                        .font(.customFont("CabinetGrotesk-Medium", size: 17))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 18) // balance
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)

                Spacer()

                // Timer display
                VStack(spacing: 12) {
                    Text("Reveal available in")
                        .font(.customFont("CabinetGrotesk-Medium", size: 15))
                        .foregroundColor(Color.white.opacity(0.65))

                    Text(viewModel.timerText)
                        .font(.customFont("CabinetGrotesk-Medium", size: 48))
                        .foregroundColor(.white)
                        .monospacedDigit()

                    Text("Photos will be revealed when the timer ends")
                        .font(.customFont("CabinetGrotesk-Medium", size: 13))
                        .foregroundColor(Color.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Skip section
                if !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Button(action: { handleSkip() }) {
                            Text(viewModel.skipButtonTitle)
                                .font(.customFont("CabinetGrotesk-Medium", size: 16))
                                .foregroundColor(viewModel.canSkip ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(viewModel.canSkip ? Color.white : Color.white.opacity(0.15))
                                .cornerRadius(28)
                        }

                        Text(viewModel.skipSubtext)
                            .font(.customFont("CabinetGrotesk-Medium", size: 13))
                            .foregroundColor(Color.white.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 48)
                }
            }
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            viewModel.loadData(matchData: matchData)
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: viewModel.timeRemaining) { remaining in
            if remaining <= 0 && viewModel.revealTime != nil {
                // Timer expired - auto reveal
                Task {
                    try? await viewModel.forceReveal()
                    await MainActor.run { onRevealed?() }
                }
            }
        }
    }

    private func handleSkip() {
        if !viewModel.canSkip {
            onUpgrade?()
            return
        }
        Task {
            do {
                try await viewModel.skipMatch()
                await MainActor.run { onSkip?() }
            } catch {
                print("Skip failed: \(error)")
            }
        }
    }
}
