import SwiftUI

// MARK: - Revealed View (shows partner's photo after reveal)
struct RevealedView: View {
    @State private var photoURL: String?
    @State private var partnerName = ""
    @State private var partnerAge = 0
    @State private var blurAmount: CGFloat = 20
    @State private var photoScale: CGFloat = 0.95
    @State private var contentOpacity: Double = 0

    private let api = SparkAPIService.shared
    var matchData: [String: Any]?
    var onKeepChatting: (() -> Void)?
    var onLeave: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Background photo
            if let urlString = photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: blurAmount)
                            .scaleEffect(photoScale)
                            .ignoresSafeArea()
                    }
                }
            }

            // Gradient overlay
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 400)
            }
            .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 6) {
                    Text(partnerName)
                        .font(.customFont("CabinetGrotesk-Medium", size: 28))
                        .foregroundColor(.white)
                    if partnerAge > 0 {
                        Text("\(partnerAge)")
                            .font(.customFont("CabinetGrotesk-Medium", size: 16))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    Text("Would you like to continue?")
                        .font(.customFont("CabinetGrotesk-Medium", size: 14))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.top, 4)
                }

                Spacer().frame(height: 32)

                VStack(spacing: 12) {
                    SparkButton(title: "Keep chatting", isEnabled: true) {
                        onKeepChatting?()
                    }
                    Button(action: { onLeave?() }) {
                        Text("Leave conversation")
                            .font(.customFont("CabinetGrotesk-Medium", size: 15))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .buttonStyle(OnboardingLinkStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            loadData()
            // Photo reveal animation
            withAnimation(.easeOut(duration: 0.8)) {
                blurAmount = 0
                photoScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                contentOpacity = 1
            }
        }
    }

    private func loadData() {
        if let match = matchData {
            partnerName = match["name"] as? String ?? ""
            partnerAge = match["age"] as? Int ?? 0
        }
        // Also read from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "sparkCurrentMatch"),
           let match = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if partnerName.isEmpty { partnerName = match["name"] as? String ?? "" }
            if partnerAge == 0 { partnerAge = match["age"] as? Int ?? 0 }
        }

        // Fetch photos
        Task {
            do {
                let matchId = matchData?["id"] as? String ?? ""
                if !matchId.isEmpty {
                    let result = try await api.apiRequest("/matches/\(matchId)/photos")
                    await MainActor.run {
                        if let photos = result["photos"] as? [[String: Any]],
                           let primary = photos.first(where: { $0["is_primary"] as? Bool == true }) ?? photos.first {
                            self.photoURL = primary["photo_url"] as? String
                        }
                    }
                    // Mark reveal as seen
                    let _ = try? await api.apiRequest("/matches/\(matchId)/reveal-seen", method: "POST")
                }
            } catch {}
        }
    }
}
