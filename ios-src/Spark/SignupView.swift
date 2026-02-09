import SwiftUI

// MARK: - Signup View
struct SignupView: View {
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var opacity: Double = 0

    private let api = SparkAPIService.shared
    var userData: [String: Any]? // From onboarding1
    var onSignupComplete: (() -> Void)?
    var onNavigateToLogin: (() -> Void)?

    var isFormValid: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 8 &&
        password == confirmPassword
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 60)

                Text("Create account")
                    .font(.customFont("CabinetGrotesk-Medium", size: 32))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Almost there! Fill in your details")
                    .font(.customFont("CabinetGrotesk-Medium", size: 15))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.bottom, 32)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        SparkTextField(text: $displayName, placeholder: "Display name")
                            .textContentType(.name)

                        SparkTextField(text: $email, placeholder: "Email", keyboardType: .emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        ZStack(alignment: .trailing) {
                            if showPassword {
                                SparkTextField(text: $password, placeholder: "Password (8+ characters)")
                            } else {
                                SecureSparkTextField(text: $password, placeholder: "Password (8+ characters)")
                            }
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.white.opacity(0.65))
                            }
                            .padding(.trailing, 16)
                        }

                        if !password.isEmpty && password.count < 8 {
                            Text("Password must be at least 8 characters")
                                .font(.customFont("CabinetGrotesk-Medium", size: 12))
                                .foregroundColor(Color.white.opacity(0.45))
                        }

                        SecureSparkTextField(text: $confirmPassword, placeholder: "Confirm password")

                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords don't match")
                                .font(.customFont("CabinetGrotesk-Medium", size: 12))
                                .foregroundColor(.red)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                                .foregroundColor(.red)
                        }
                    }
                }

                Spacer()

                VStack(spacing: 16) {
                    SparkButton(title: isLoading ? "Creating account..." : "Create Account", isEnabled: isFormValid && !isLoading) {
                        performSignup()
                    }

                    Button(action: { onNavigateToLogin?() }) {
                        Text("Already have an account?")
                            .font(.customFont("CabinetGrotesk-Medium", size: 15))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .buttonStyle(OnboardingLinkStyle())
                }
                .padding(.bottom, 48)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { opacity = 1 }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private func performSignup() {
        isLoading = true
        errorMessage = nil

        var body: [String: Any] = [
            "email": email.trimmingCharacters(in: .whitespaces),
            "password": password,
            "display_name": displayName.trimmingCharacters(in: .whitespaces)
        ]

        // Merge onboarding data
        if let data = userData {
            if let age = data["age"] { body["age"] = age }
            if let gender = data["gender"] { body["gender"] = gender }
            if let seeking = data["seeking"] { body["seeking"] = seeking }
            if let location = data["location"] { body["location"] = location }
        }

        Task {
            do {
                let result = try await api.apiRequest("/auth/signup", method: "POST", body: body)

                // Save token
                if let token = result["token"] as? String {
                    UserDefaults.standard.set(token, forKey: "sparkToken")
                }
                if let user = result["user"] as? [String: Any],
                   let data = try? JSONSerialization.data(withJSONObject: user) {
                    UserDefaults.standard.set(data, forKey: "sparkUser")
                }

                // Upload photos from onboarding
                if let photos = userData?["photos"] as? [UIImage] {
                    for (index, photo) in photos.enumerated() {
                        if let jpegData = photo.jpegData(compressionQuality: 0.8) {
                            let base64 = "data:image/jpeg;base64," + jpegData.base64EncodedString()
                            let _ = try? await api.apiRequest("/users/me/photos", method: "POST", body: [
                                "photo": base64,
                                "slot_index": index
                            ])
                        }
                    }
                }

                // Save email for verification
                UserDefaults.standard.set(email, forKey: "sparkVerifyEmail")

                await MainActor.run {
                    isLoading = false
                    onSignupComplete?()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
