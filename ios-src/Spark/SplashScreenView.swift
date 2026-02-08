import SwiftUI

struct SplashScreenView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var logoBlur: CGFloat = 12
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 20
    @State private var taglineOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0
    @StateObject private var authManager = AuthManager.shared

    var onNavigate: (String) -> Void

    private var logoImage: Image {
        if let image = UIImage(named: "LaunchIcon") {
            return Image(uiImage: image)
        } else if let image = UIImage(named: "spark-icon") {
            return Image(uiImage: image)
        } else if let bundlePath = Bundle.main.path(forResource: "spark-icon", ofType: "png"),
                  let image = UIImage(contentsOfFile: bundlePath) {
            return Image(uiImage: image)
        } else if let bundlePath = Bundle.main.path(forResource: "sparkadate/spark-icon", ofType: "png"),
                  let image = UIImage(contentsOfFile: bundlePath) {
            return Image(uiImage: image)
        }
        return Image(systemName: "heart.fill")
    }

    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Subtle radial glow behind logo
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.06),
                    Color.clear
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            .opacity(glowOpacity)
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Logo with pulse animation
                logoImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .scaleEffect(logoScale * pulseScale)
                    .opacity(logoOpacity)
                    .blur(radius: logoBlur)

                // Wordmark
                Text("Spark")
                    .font(.customFont("CabinetGrotesk-Medium", size: 40))
                    .tracking(-0.02)
                    .foregroundColor(.white)
                    .opacity(wordmarkOpacity)
                    .offset(y: wordmarkOffset)

                // Tagline
                Text("Connection before appearance")
                    .font(.customFont("CabinetGrotesk-Medium", size: 15))
                    .foregroundColor(Color.white.opacity(0.45))
                    .opacity(taglineOpacity)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Phase 1: Logo fades in with scale and blur (0 - 0.6s)
        withAnimation(.easeOut(duration: 0.6)) {
            logoOpacity = 1
            logoScale = 1.0
            logoBlur = 0
            glowOpacity = 1
        }

        // Phase 2: Wordmark slides up into place (0.3 - 0.8s)
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            wordmarkOpacity = 1
            wordmarkOffset = 0
        }

        // Phase 3: Tagline fades in (0.6 - 1.0s)
        withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
            taglineOpacity = 1
        }

        // Phase 4: Subtle pulse on logo (1.0 - 1.4s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.4)) {
                pulseScale = 1.06
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }

        // Phase 5: Fade out everything and navigate (2.2s total)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeIn(duration: 0.5)) {
                logoOpacity = 0
                wordmarkOpacity = 0
                taglineOpacity = 0
                glowOpacity = 0
                logoScale = 1.1
                logoBlur = 8
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                navigateToAppropriateScreen()
            }
        }
    }

    private func navigateToAppropriateScreen() {
        if authManager.isLoggedIn() {
            if let lastPage = authManager.getLastPage() {
                onNavigate(lastPage)
            } else {
                onNavigate("match.html")
            }
        } else {
            onNavigate("onboarding")
        }
    }
}

// MARK: - Auth Manager
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    private let tokenKey = "sparkToken"
    private let userKey = "sparkUser"
    private let lastPageKey = "sparkLastPage"
    private let lastPageTimeKey = "sparkLastPageTime"

    private let restorablePages = ["chat.html", "match.html", "timer.html", "reveal.html", "revealed.html", "revealrequest.html", "settings.html"]

    private init() {}

    func isLoggedIn() -> Bool {
        guard let token = UserDefaults.standard.string(forKey: tokenKey) else {
            return false
        }

        let parts = token.components(separatedBy: ".")
        guard parts.count == 3,
              let payloadData = Data(base64Encoded: parts[1], options: .ignoreUnknownCharacters),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return false
        }

        let expiresAt = exp * 1000
        return Date().timeIntervalSince1970 * 1000 < expiresAt
    }

    func getLastPage() -> String? {
        guard let lastPage = UserDefaults.standard.string(forKey: lastPageKey),
              let lastPageTimeString = UserDefaults.standard.string(forKey: lastPageTimeKey),
              let lastPageTime = TimeInterval(lastPageTimeString) else {
            return nil
        }

        let sevenDaysMs: TimeInterval = 7 * 24 * 60 * 60 * 1000
        if Date().timeIntervalSince1970 * 1000 - lastPageTime > sevenDaysMs {
            clearLastPage()
            return nil
        }

        return lastPage
    }

    func clearLastPage() {
        UserDefaults.standard.removeObject(forKey: lastPageKey)
        UserDefaults.standard.removeObject(forKey: lastPageTimeKey)
    }

    func getCurrentUser() -> [String: Any]? {
        guard let userData = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONSerialization.jsonObject(with: userData) as? [String: Any] else {
            return nil
        }
        return user
    }
}
