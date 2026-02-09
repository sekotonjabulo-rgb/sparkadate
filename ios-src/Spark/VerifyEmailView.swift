import SwiftUI

// MARK: - Verify Email View
struct VerifyEmailView: View {
    @State private var code: [String] = Array(repeating: "", count: 6)
    @State private var activeField: Int = 0
    @State private var isVerifying = false
    @State private var isSuccess = false
    @State private var errorMessage: String? = nil
    @State private var resendCooldown: Int = 0
    @State private var opacity: Double = 0
    @State private var shake = false
    @FocusState private var focusedField: Int?

    private let api = SparkAPIService.shared
    var onVerified: (() -> Void)?

    private var email: String {
        UserDefaults.standard.string(forKey: "sparkVerifyEmail") ??
        (UserDefaults.standard.data(forKey: "sparkUser")
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            .flatMap { $0["email"] as? String } ?? "")
    }

    private var fullCode: String {
        code.joined()
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 64, height: 64)
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 24)

                if isSuccess {
                    successView
                } else {
                    codeEntryView
                }

                Spacer()

                if isSuccess {
                    SparkButton(title: "Continue", isEnabled: true) {
                        onVerified?()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 48)
                }
            }
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { opacity = 1 }
        }
    }

    private var codeEntryView: some View {
        VStack(spacing: 0) {
            Text("Verify your email")
                .font(.customFont("CabinetGrotesk-Medium", size: 28))
                .foregroundColor(.white)
                .padding(.bottom, 8)

            Text("Enter the 6-digit code sent to")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.65))
            Text(email)
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(.white)
                .padding(.bottom, 32)

            // Code fields
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    TextField("", text: Binding(
                        get: { code[index] },
                        set: { newVal in
                            let filtered = newVal.filter { $0.isNumber }
                            if filtered.count <= 1 {
                                code[index] = String(filtered.prefix(1))
                                if !filtered.isEmpty && index < 5 {
                                    focusedField = index + 1
                                }
                            } else if filtered.count == 6 {
                                // Handle paste
                                for (i, char) in filtered.prefix(6).enumerated() {
                                    code[i] = String(char)
                                }
                                focusedField = 5
                                verifyCode()
                            }
                        }
                    ))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.customFont("CabinetGrotesk-Medium", size: 24))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 56)
                    .background(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(focusedField == index ? Color.white.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .focused($focusedField, equals: index)
                }
            }
            .offset(x: shake ? -10 : 0)
            .padding(.bottom, 24)

            if let error = errorMessage {
                Text(error)
                    .font(.customFont("CabinetGrotesk-Medium", size: 14))
                    .foregroundColor(.red)
                    .padding(.bottom, 16)
            }

            SparkButton(title: isVerifying ? "Verifying..." : "Verify", isEnabled: fullCode.count == 6 && !isVerifying) {
                verifyCode()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            // Resend
            if resendCooldown > 0 {
                Text("Resend code in \(resendCooldown)s")
                    .font(.customFont("CabinetGrotesk-Medium", size: 14))
                    .foregroundColor(Color.white.opacity(0.45))
            } else {
                Button(action: { resendCode() }) {
                    Text("Resend code")
                        .font(.customFont("CabinetGrotesk-Medium", size: 14))
                        .foregroundColor(Color.white.opacity(0.65))
                        .underline()
                }
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.19, green: 0.82, blue: 0.35).opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.35))
            }
            .padding(.bottom, 8)

            Text("Email verified!")
                .font(.customFont("CabinetGrotesk-Medium", size: 28))
                .foregroundColor(.white)
            Text("Your account is ready to go")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.65))
        }
    }

    private func verifyCode() {
        guard fullCode.count == 6 else { return }
        isVerifying = true
        errorMessage = nil

        Task {
            do {
                let _ = try await api.apiRequest("/auth/verify-email", method: "POST", body: [
                    "email": email,
                    "code": fullCode
                ])
                await MainActor.run {
                    isVerifying = false
                    isSuccess = true
                    UserDefaults.standard.removeObject(forKey: "sparkVerifyEmail")
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    errorMessage = error.localizedDescription
                    withAnimation(.default.speed(4).repeatCount(3, autoreverses: true)) {
                        shake = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shake = false }
                }
            }
        }
    }

    private func resendCode() {
        resendCooldown = 60
        Task {
            try? await api.apiRequest("/auth/send-verification", method: "POST", body: ["email": email])
        }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                resendCooldown -= 1
                if resendCooldown <= 0 { timer.invalidate() }
            }
        }
    }
}
