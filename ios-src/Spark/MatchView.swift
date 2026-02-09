import SwiftUI

// MARK: - Match View Model
class MatchViewModel: ObservableObject {
    @Published var state: MatchState = .loading
    @Published var partnerName: String = ""
    @Published var partnerAge: Int = 0
    @Published var matchId: String = ""

    private let api = SparkAPIService.shared
    private var pollTimer: Timer?

    enum MatchState {
        case loading
        case searching
        case found
        case error(String)
    }

    func checkForMatch() {
        state = .loading
        Task {
            do {
                let result = try await api.apiRequest("/matches/current")
                await MainActor.run {
                    if let match = result["match"] as? [String: Any],
                       let partner = match["partner"] as? [String: Any] {
                        self.partnerName = partner["name"] as? String ?? "Someone"
                        self.partnerAge = partner["age"] as? Int ?? 0
                        self.matchId = match["id"] as? String ?? ""
                        self.state = .found
                    } else {
                        self.findNewMatch()
                    }
                }
            } catch {
                await MainActor.run {
                    self.findNewMatch()
                }
            }
        }
    }

    private func findNewMatch() {
        state = .searching
        Task {
            do {
                let result = try await api.apiRequest("/matches/find", method: "POST")
                await MainActor.run {
                    if let match = result["match"] as? [String: Any],
                       let partner = match["partner"] as? [String: Any] {
                        self.partnerName = partner["name"] as? String ?? "Someone"
                        self.partnerAge = partner["age"] as? Int ?? 0
                        self.matchId = match["id"] as? String ?? ""
                        self.state = .found
                    } else {
                        // Queued - start polling
                        self.startPolling()
                    }
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollForMatch()
        }
    }

    private func pollForMatch() {
        Task {
            do {
                let result = try await api.apiRequest("/matches/current")
                await MainActor.run {
                    if let match = result["match"] as? [String: Any],
                       let partner = match["partner"] as? [String: Any] {
                        self.pollTimer?.invalidate()
                        self.partnerName = partner["name"] as? String ?? "Someone"
                        self.partnerAge = partner["age"] as? Int ?? 0
                        self.matchId = match["id"] as? String ?? ""
                        self.state = .found
                    }
                }
            } catch {}
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

// MARK: - Match View
struct MatchView: View {
    @StateObject private var viewModel = MatchViewModel()
    @State private var showContent = false
    @State private var navigateAfterDelay = false
    var onNavigateToChat: (() -> Void)?
    var onNavigateToPlan: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                switch viewModel.state {
                case .loading:
                    loadingView

                case .searching:
                    searchingView

                case .found:
                    matchFoundView

                case .error(let msg):
                    errorView(msg)
                }
            }
            .frame(maxWidth: 428)
        }
        .onAppear {
            viewModel.checkForMatch()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            // Skeleton shimmer
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .frame(width: 180, height: 20)
                .shimmer()

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .frame(width: 120, height: 32)
                .shimmer()

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
                .frame(width: 60, height: 16)
                .shimmer()
            Spacer()
        }
    }

    private var searchingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)

            Text("Searching...")
                .font(.customFont("CabinetGrotesk-Medium", size: 20))
                .foregroundColor(Color.white.opacity(0.65))

            Text("Looking for your next connection")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.4))
            Spacer()
        }
    }

    private var matchFoundView: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("You're matched with")
                .font(.customFont("CabinetGrotesk-Medium", size: 15))
                .foregroundColor(Color.white.opacity(0.65))
                .opacity(showContent ? 1 : 0)

            Text(viewModel.partnerName)
                .font(.customFont("CabinetGrotesk-Medium", size: 32))
                .foregroundColor(.white)
                .opacity(showContent ? 1 : 0)

            if viewModel.partnerAge > 0 {
                Text("\(viewModel.partnerAge)")
                    .font(.customFont("CabinetGrotesk-Medium", size: 16))
                    .foregroundColor(Color.white.opacity(0.5))
                    .opacity(showContent ? 1 : 0)
            }

            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
            // Auto-navigate to chat after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                onNavigateToChat?()
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Something went wrong")
                .font(.customFont("CabinetGrotesk-Medium", size: 20))
                .foregroundColor(.white)

            Text(message)
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)

            SparkButton(title: "Try Again", isEnabled: true) {
                viewModel.checkForMatch()
            }
            .frame(width: 200)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Shimmer Modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [.clear, Color.white.opacity(0.1), .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}
