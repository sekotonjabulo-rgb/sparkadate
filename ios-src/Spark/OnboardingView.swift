import SwiftUI

struct OnboardingView: View {
    @State private var opacity: Double = 0
    @State private var blur: CGFloat = 12
    var onNavigate: (String) -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 120)
                
                // Header Section
                VStack(spacing: 24) {
                    // Wordmark
                    Text("Spark")
                        .font(.customFont("CabinetGrotesk-Medium", size: 48))
                        .tracking(-0.02)
                        .foregroundColor(.white)
                    
                    // Tagline
                    Text("Meet someone before you see them.")
                        .font(.customFont("CabinetGrotesk-Medium", size: 17))
                        .foregroundColor(Color.white.opacity(0.65))
                }
                .padding(.horizontal, 16)
                
                Spacer()
                
                // Actions Section
                VStack(spacing: 16) {
                    // Get Started Button
                    Button(action: {
                        onNavigate("onboarding1.html")
                    }) {
                        Text("Get Started")
                            .font(.customFont("CabinetGrotesk-Medium", size: 17))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                    }
                    .buttonStyle(OnboardingButtonStyle())
                    
                    // Login Link
                    Button(action: {
                        onNavigate("login.html")
                    }) {
                        Text("I already have an account")
                            .font(.customFont("CabinetGrotesk-Medium", size: 15))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .buttonStyle(OnboardingLinkStyle())
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .opacity(opacity)
            .blur(radius: blur)
            .frame(maxWidth: 428)
        }
        .onAppear {
            // Blur fade-in animation
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1
                blur = 0
            }
        }
    }
}

// Custom button styles to match HTML behavior
struct OnboardingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct OnboardingLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .white : Color.white.opacity(0.65))
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

