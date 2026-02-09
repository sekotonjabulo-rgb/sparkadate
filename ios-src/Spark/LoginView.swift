import SwiftUI

// MARK: - API Service
class SparkAPIService {
    static let shared = SparkAPIService()
    private let baseURL = "https://sparkadate-1n.onrender.com/api"

    private init() {}

    func login(email: String, password: String) async throws -> (token: String, user: [String: Any]) {
        guard let url = URL(string: "\(baseURL)/auth/login") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMsg = json["error"] as? String ?? "Invalid credentials"
            throw APIError.serverError(errorMsg)
        }

        guard let token = json["token"] as? String,
              let user = json["user"] as? [String: Any] else {
            throw APIError.invalidResponse
        }

        // Save token and user to UserDefaults (mirrors JS localStorage)
        UserDefaults.standard.set(token, forKey: "sparkToken")
        if let userData = try? JSONSerialization.data(withJSONObject: user) {
            UserDefaults.standard.set(userData, forKey: "sparkUser")
        }

        return (token, user)
    }

    // Generic API request method for all endpoints
    func apiRequest(_ endpoint: String, method: String = "GET", body: [String: Any]? = nil) async throws -> [String: Any] {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = UserDefaults.standard.string(forKey: "sparkToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode >= 400 {
            let errorMsg = json["error"] as? String ?? "Request failed"
            throw APIError.serverError(errorMsg)
        }

        return json
    }

    enum APIError: LocalizedError {
        case invalidURL
        case networkError
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .networkError: return "Network error. Please check your connection."
            case .invalidResponse: return "Invalid server response"
            case .serverError(let msg): return msg
            }
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var opacity: Double = 0
    @State private var offsetY: CGFloat = 8

    var onLoginSuccess: (() -> Void)?
    var onForgotPassword: (() -> Void)?

    var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 80)

                Text("Welcome back")
                    .font(.customFont("CabinetGrotesk-Medium", size: 32))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Sign in to continue")
                    .font(.customFont("CabinetGrotesk-Medium", size: 15))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.bottom, 40)

                // Email field
                SparkTextField(text: $email, placeholder: "Email", keyboardType: .emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.bottom, 16)

                // Password field with toggle
                ZStack(alignment: .trailing) {
                    Group {
                        if showPassword {
                            SparkTextField(text: $password, placeholder: "Password")
                                .textContentType(.password)
                        } else {
                            SecureSparkTextField(text: $password, placeholder: "Password")
                                .textContentType(.password)
                        }
                    }

                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 18))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .padding(.trailing, 16)
                }

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.customFont("CabinetGrotesk-Medium", size: 14))
                        .foregroundColor(.red)
                        .padding(.top, 12)
                }

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    SparkButton(title: isLoading ? "Signing in..." : "Sign In", isEnabled: isFormValid && !isLoading) {
                        performLogin()
                    }

                    Button(action: { onForgotPassword?() }) {
                        Text("Forgot password?")
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
            .offset(y: offsetY)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
                offsetY = 0
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private func performLogin() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let _ = try await SparkAPIService.shared.login(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    onLoginSuccess?()
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

// MARK: - Secure Text Field (matching Spark style)
struct SecureSparkTextField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        SecureField("", text: $text)
            .placeholder(when: text.isEmpty) {
                Text(placeholder).foregroundColor(Color.white.opacity(0.65))
            }
            .font(.customFont("CabinetGrotesk-Medium", size: 16))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .cornerRadius(16)
    }
}
