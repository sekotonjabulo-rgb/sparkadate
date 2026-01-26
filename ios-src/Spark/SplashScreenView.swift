import SwiftUI

struct SplashScreenView: View {
    @State private var opacity: Double = 0
    @State private var blur: CGFloat = 12
    @State private var isAnimatingOut = false
    @StateObject private var authManager = AuthManager.shared
    
    var onNavigate: (String) -> Void

    // Computed property for logo image to avoid Group modifier issues
    private var logoImage: Image {
        // Try asset catalog first
        if let image = UIImage(named: "LaunchIcon") {
            return Image(uiImage: image)
        } else if let image = UIImage(named: "spark-icon") {
            return Image(uiImage: image)
        }
        // Try bundle resources (for files included in the app bundle)
        else if let bundlePath = Bundle.main.path(forResource: "spark-icon", ofType: "png"),
                  let image = UIImage(contentsOfFile: bundlePath) {
            return Image(uiImage: image)
        }
        // Try from sparkadate subdirectory (where web assets are)
        else if let bundlePath = Bundle.main.path(forResource: "sparkadate/spark-icon", ofType: "png"),
                  let image = UIImage(contentsOfFile: bundlePath) {
            return Image(uiImage: image)
        }
        // Fallback to system icon
        return Image(systemName: "heart.fill")
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Logo - try multiple possible asset names and bundle paths
                logoImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                
                // Wordmark
                Text("Spark")
                    .font(.customFont("CabinetGrotesk-Medium", size: 36))
                    .tracking(-0.02)
                    .foregroundColor(.white)
            }
            .opacity(opacity)
            .blur(radius: blur)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Fade in animation
        withAnimation(.easeOut(duration: 0.6)) {
            opacity = 1
            blur = 0
        }
        
        // After 2 seconds total (0.6s fade in + 1.4s delay), fade out and navigate
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeIn(duration: 0.6)) {
                opacity = 0
                blur = 12
            }
            
            // Navigate after fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                navigateToAppropriateScreen()
            }
        }
    }
    
    private func navigateToAppropriateScreen() {
        if authManager.isLoggedIn() {
            // User is logged in - try to restore last page
            if let lastPage = authManager.getLastPage() {
                // Restore to last visited page
                onNavigate(lastPage)
            } else {
                // No saved page - go to match selection
                onNavigate("match.html")
            }
        } else {
            // Not logged in - go to native onboarding
            onNavigate("onboarding.html")
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
        
        // Decode JWT to check expiration
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3,
              let payloadData = Data(base64Encoded: parts[1], options: .ignoreUnknownCharacters),
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = payload["exp"] as? TimeInterval else {
            return false
        }
        
        let expiresAt = exp * 1000 // Convert to milliseconds
        return Date().timeIntervalSince1970 * 1000 < expiresAt
    }
    
    func getLastPage() -> String? {
        guard let lastPage = UserDefaults.standard.string(forKey: lastPageKey),
              let lastPageTimeString = UserDefaults.standard.string(forKey: lastPageTimeKey),
              let lastPageTime = TimeInterval(lastPageTimeString) else {
            return nil
        }
        
        // Only restore if the saved page is less than 7 days old
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

