import SwiftUI

// MARK: - Reveal Request View (partner wants to reveal)
struct RevealRequestView: View {
    @State private var partnerName = ""
    @State private var isAccepting = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var opacity: Double = 0

    private let api = SparkAPIService.shared
    var matchData: [String: Any]?
    var onAccepted: (() -> Void)?
    var onNotYet: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Pulsing eye icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .scaleEffect(pulseScale)
                .padding(.bottom, 24)

                Text("Reveal request")
                    .font(.customFont("CabinetGrotesk-Medium", size: 24))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("\(partnerName) wants to reveal")
                    .font(.customFont("CabinetGrotesk-Medium", size: 15))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.bottom, 8)

                Text("If you accept, both will see each other's\nphotos at the same time. This cannot be undone.")
                    .font(.customFont("CabinetGrotesk-Medium", size: 13))
                    .foregroundColor(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: 16) {
                    SparkButton(title: isAccepting ? "Accepting..." : "Accept & Reveal", isEnabled: !isAccepting) {
                        acceptReveal()
                    }
                    Button(action: { onNotYet?() }) {
                        Text("Not yet")
                            .font(.customFont("CabinetGrotesk-Medium", size: 15))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .buttonStyle(OnboardingLinkStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            if let match = matchData {
                partnerName = match["name"] as? String ?? "Your match"
            }
            withAnimation(.easeOut(duration: 0.5)) { opacity = 1 }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }

    private func acceptReveal() {
        isAccepting = true
        let matchId = matchData?["id"] as? String ?? ""
        Task {
            do {
                let _ = try await api.apiRequest("/matches/\(matchId)/reveal", method: "POST")
                await MainActor.run {
                    isAccepting = false
                    onAccepted?()
                }
            } catch {
                await MainActor.run { isAccepting = false }
            }
        }
    }
}
