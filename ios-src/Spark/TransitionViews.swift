import SwiftUI

// MARK: - Exit View (user left the match)
struct ExitView: View {
    @State private var opacity: Double = 0
    var partnerName: String = ""
    var partnerAge: Int = 0
    var onFindNewMatch: (() -> Void)?

    private let api = SparkAPIService.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("You left behind")
                    .font(.customFont("CabinetGrotesk-Medium", size: 14))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.bottom, 8)

                Text(partnerName)
                    .font(.customFont("CabinetGrotesk-Medium", size: 28))
                    .foregroundColor(.white)
                    .padding(.bottom, 4)

                if partnerAge > 0 {
                    Text("\(partnerAge)")
                        .font(.customFont("CabinetGrotesk-Medium", size: 16))
                        .foregroundColor(Color.white.opacity(0.5))
                        .padding(.bottom, 16)
                }

                Text("Take a moment to reflect.\nWhen you're ready, we'll find someone new.")
                    .font(.customFont("CabinetGrotesk-Medium", size: 14))
                    .foregroundColor(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)

                Spacer()

                SparkButton(title: "Find new match", isEnabled: true) {
                    exitMatch()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { opacity = 1 }
        }
    }

    private func exitMatch() {
        // Get match ID from stored data
        if let data = UserDefaults.standard.data(forKey: "sparkCurrentMatch"),
           let match = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let matchId = match["id"] as? String {
            Task {
                try? await api.apiRequest("/matches/\(matchId)/exit", method: "POST")
            }
        }
        UserDefaults.standard.removeObject(forKey: "sparkCurrentMatch")
        UserDefaults.standard.removeObject(forKey: "sparkLastPage")
        onFindNewMatch?()
    }
}

// MARK: - Left View (partner left)
struct LeftView: View {
    @State private var opacity: Double = 0
    var partnerName: String = ""
    var onFindNewMatch: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // X icon
                Image(systemName: "xmark.circle")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(Color.white.opacity(0.3))
                    .padding(.bottom, 24)

                Text("They moved on")
                    .font(.customFont("CabinetGrotesk-Medium", size: 28))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("\(partnerName) has left the conversation")
                    .font(.customFont("CabinetGrotesk-Medium", size: 14))
                    .foregroundColor(Color.white.opacity(0.65))

                Spacer()

                SparkButton(title: "Find new match", isEnabled: true) {
                    UserDefaults.standard.removeObject(forKey: "sparkCurrentMatch")
                    UserDefaults.standard.removeObject(forKey: "sparkLastPage")
                    onFindNewMatch?()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { opacity = 1 }
        }
    }
}

// MARK: - Pro Success View
struct ProSuccessView: View {
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 16
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleOffset: CGFloat = 16
    @State private var buttonOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 16

    var onContinue: (() -> Void)?

    private var logoImage: Image {
        if let image = UIImage(named: "LaunchIcon") {
            return Image(uiImage: image)
        }
        return Image(systemName: "heart.fill")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with logo
                HStack(spacing: 10) {
                    logoImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                    Text("Spark")
                        .font(.customFont("CabinetGrotesk-Medium", size: 20))
                        .foregroundColor(.white)
                }
                .padding(.top, 24)

                Spacer()

                Text("You're all set")
                    .font(.customFont("CabinetGrotesk-Medium", size: 32))
                    .foregroundColor(.white)
                    .opacity(titleOpacity)
                    .offset(y: titleOffset)
                    .padding(.bottom, 12)

                Text("Welcome to Spark Pro.\nYour journey to meaningful connections\njust got better.")
                    .font(.customFont("CabinetGrotesk-Medium", size: 15))
                    .foregroundColor(Color.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .opacity(subtitleOpacity)
                    .offset(y: subtitleOffset)

                Spacer()

                SparkButton(title: "Start chatting", isEnabled: true) {
                    // Update subscription tier locally
                    if var userData = UserDefaults.standard.data(forKey: "sparkUser")
                        .flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) {
                        userData["subscription_tier"] = "pro"
                        if let data = try? JSONSerialization.data(withJSONObject: userData) {
                            UserDefaults.standard.set(data, forKey: "sparkUser")
                        }
                    }
                    onContinue?()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
                .opacity(buttonOpacity)
                .offset(y: buttonOffset)
            }
            .frame(maxWidth: 428)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                titleOpacity = 1; titleOffset = 0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                subtitleOpacity = 1; subtitleOffset = 0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
                buttonOpacity = 1; buttonOffset = 0
            }
        }
    }
}

// MARK: - Support View
struct SupportView: View {
    @State private var expandedIndex: Int? = nil
    @State private var opacity: Double = 0

    var onBack: (() -> Void)?

    private let faqs: [(question: String, answer: String)] = [
        (
            "How does blind matching work?",
            "Spark connects you with someone based on compatibility. You chat and get to know each other before seeing photos. When the timer expires, or both agree to reveal, you'll see each other's photos."
        ),
        (
            "How do I report someone?",
            "You can report users through the chat menu. Tap the three-dot menu in the chat header and select 'Report'. Our team reviews all reports promptly."
        ),
        (
            "What does Spark Pro include?",
            "Spark Pro gives you unlimited skips, the ability to request reveals anytime, buy time extensions, and priority matching. It's $20/month."
        ),
        (
            "How do I delete my account?",
            "Go to Settings > Delete Account. This permanently removes all your data including messages, photos, and match history. This action cannot be undone."
        )
    ]

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
                            .frame(width: 36, height: 36)
                    }
                    Spacer()
                    Text("Help & Support")
                        .font(.customFont("CabinetGrotesk-Medium", size: 17))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // FAQ Section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Frequently Asked Questions")
                                .font(.customFont("CabinetGrotesk-Medium", size: 20))
                                .foregroundColor(.white)
                                .padding(.bottom, 16)

                            ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                                VStack(spacing: 0) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            expandedIndex = expandedIndex == index ? nil : index
                                        }
                                    }) {
                                        HStack {
                                            Text(faq.question)
                                                .font(.customFont("CabinetGrotesk-Medium", size: 15))
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                            Image(systemName: "plus")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(Color.white.opacity(0.65))
                                                .rotationEffect(.degrees(expandedIndex == index ? 45 : 0))
                                        }
                                        .padding(.vertical, 16)
                                    }

                                    if expandedIndex == index {
                                        Text(faq.answer)
                                            .font(.customFont("CabinetGrotesk-Medium", size: 14))
                                            .foregroundColor(Color.white.opacity(0.65))
                                            .lineSpacing(4)
                                            .padding(.bottom, 16)
                                    }

                                    Divider().background(Color.white.opacity(0.08))
                                }
                            }
                        }
                        .padding(.top, 16)

                        // Contact section
                        VStack(spacing: 12) {
                            Text("Still need help?")
                                .font(.customFont("CabinetGrotesk-Medium", size: 20))
                                .foregroundColor(.white)

                            Text("Reach out to our support team")
                                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                                .foregroundColor(Color.white.opacity(0.65))

                            Button(action: {
                                if let url = URL(string: "mailto:support@sparkadate.online") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "envelope")
                                        .font(.system(size: 16))
                                    Text("support@sparkadate.online")
                                        .font(.customFont("CabinetGrotesk-Medium", size: 15))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.white)
                                .cornerRadius(24)
                            }
                        }
                        .padding(.vertical, 32)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { opacity = 1 }
        }
    }
}
