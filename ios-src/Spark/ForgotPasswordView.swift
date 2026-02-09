import SwiftUI

// MARK: - Forgot Password View
struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var opacity: Double = 0

    private let api = SparkAPIService.shared
    var onBack: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Back button
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
                .padding(.top, 16)

                Spacer().frame(height: 40)

                if showSuccess {
                    successContent
                } else {
                    formContent
                }

                Spacer()
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

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Forgot password?")
                .font(.customFont("CabinetGrotesk-Medium", size: 32))
                .foregroundColor(.white)
                .padding(.bottom, 8)

            Text("Enter your email and we'll send you a reset link")
                .font(.customFont("CabinetGrotesk-Medium", size: 15))
                .foregroundColor(Color.white.opacity(0.65))
                .padding(.bottom, 32)

            SparkTextField(text: $email, placeholder: "Email", keyboardType: .emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(.bottom, 24)

            SparkButton(title: isLoading ? "Sending..." : "Send Reset Link", isEnabled: !email.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading) {
                sendResetLink()
            }
        }
    }

    private var successContent: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.19, green: 0.82, blue: 0.35).opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)

            Text("Check your email")
                .font(.customFont("CabinetGrotesk-Medium", size: 28))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)

            Text("If an account exists with that email, we've sent a password reset link.")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func sendResetLink() {
        isLoading = true
        Task {
            // Always show success for security
            try? await api.apiRequest("/auth/forgot-password", method: "POST", body: [
                "email": email.trimmingCharacters(in: .whitespaces)
            ])
            await MainActor.run {
                isLoading = false
                showSuccess = true
            }
        }
    }
}
