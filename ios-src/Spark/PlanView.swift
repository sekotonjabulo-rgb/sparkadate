import SwiftUI

struct PlanView: View {
    @State private var selectedPlan: String = "pro"
    @State private var opacity: Double = 0
    var onSelectFree: (() -> Void)?
    var onSelectPro: ((String) -> Void)? // passes checkout URL
    var onNavigateToMatch: (() -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Header
                Text("Choose your plan")
                    .font(.customFont("CabinetGrotesk-Medium", size: 28))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                Text("Unlock the full Spark experience")
                    .font(.customFont("CabinetGrotesk-Medium", size: 14))
                    .foregroundColor(Color.white.opacity(0.65))
                    .padding(.bottom, 32)

                // Plan Cards
                VStack(spacing: 12) {
                    PlanCard(
                        name: "Free",
                        price: "$0",
                        period: "",
                        features: [
                            PlanFeature(text: "Match with someone new", enabled: true),
                            PlanFeature(text: "Chat before you see them", enabled: true),
                            PlanFeature(text: "3 exits per match cycle", enabled: true),
                            PlanFeature(text: "Reveal when timer expires", enabled: true),
                            PlanFeature(text: "Request reveal anytime", enabled: false),
                            PlanFeature(text: "Buy time extensions", enabled: false)
                        ],
                        isSelected: selectedPlan == "free",
                        badge: nil
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedPlan = "free" }
                    }

                    PlanCard(
                        name: "Pro",
                        price: "$20",
                        period: "/month",
                        features: [
                            PlanFeature(text: "Match with someone new", enabled: true),
                            PlanFeature(text: "Chat before you see them", enabled: true),
                            PlanFeature(text: "Unlimited exits", enabled: true),
                            PlanFeature(text: "Reveal when timer expires", enabled: true),
                            PlanFeature(text: "Request reveal anytime", enabled: true),
                            PlanFeature(text: "Buy time extensions", enabled: true)
                        ],
                        isSelected: selectedPlan == "pro",
                        badge: "Popular"
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedPlan = "pro" }
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    SparkButton(title: selectedPlan == "pro" ? "Continue with Pro" : "Continue with Free", isEnabled: true) {
                        if selectedPlan == "pro" {
                            // Build checkout URL with user ID
                            let userId = getUserId()
                            let checkoutURL = "https://spark-thesocialapp.lemonsqueezy.com/checkout/buy/c2f6c83c-a035-4a53-8c93-7c1f98b3e1da?checkout[custom][user_id]=\(userId)"
                            onSelectPro?(checkoutURL)
                        } else {
                            // Mark plan as completed
                            UserDefaults.standard.set("true", forKey: "sparkPlanCompleted")
                            onNavigateToMatch?()
                        }
                    }

                    if selectedPlan == "pro" {
                        Button(action: {
                            UserDefaults.standard.set("true", forKey: "sparkPlanCompleted")
                            onNavigateToMatch?()
                        }) {
                            Text("Continue with Free")
                                .font(.customFont("CabinetGrotesk-Medium", size: 15))
                                .foregroundColor(Color.white.opacity(0.65))
                        }
                        .buttonStyle(OnboardingLinkStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
            }
        }
    }

    private func getUserId() -> String {
        if let userData = UserDefaults.standard.data(forKey: "sparkUser"),
           let user = try? JSONSerialization.jsonObject(with: userData) as? [String: Any],
           let id = user["id"] as? String {
            return id
        }
        return ""
    }
}

// MARK: - Plan Feature
struct PlanFeature {
    let text: String
    let enabled: Bool
}

// MARK: - Plan Card
struct PlanCard: View {
    let name: String
    let price: String
    let period: String
    let features: [PlanFeature]
    let isSelected: Bool
    let badge: String?
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.customFont("CabinetGrotesk-Medium", size: 20))
                            .foregroundColor(isSelected ? .black : .white)

                        if let badge = badge {
                            Text(badge)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(isSelected ? .white : .black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isSelected ? Color.black.opacity(0.3) : Color.white.opacity(0.2))
                                .cornerRadius(10)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(price)
                            .font(.customFont("CabinetGrotesk-Medium", size: 24))
                            .foregroundColor(isSelected ? .black : .white)
                        if !period.isEmpty {
                            Text(period)
                                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                                .foregroundColor(isSelected ? Color.black.opacity(0.6) : Color.white.opacity(0.5))
                        }
                    }
                }
                Spacer()

                // Selection indicator
                Circle()
                    .fill(isSelected ? Color.black : Color.clear)
                    .overlay(
                        Circle().stroke(isSelected ? Color.black : Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .overlay(
                        isSelected ? Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white) : nil
                    )
                    .frame(width: 22, height: 22)
            }

            // Feature list
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(features.enumerated()), id: \.offset) { _, feature in
                    HStack(spacing: 8) {
                        Image(systemName: feature.enabled ? "checkmark" : "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(
                                feature.enabled
                                    ? (isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.7))
                                    : (isSelected ? Color.black.opacity(0.25) : Color.white.opacity(0.25))
                            )
                            .frame(width: 16)

                        Text(feature.text)
                            .font(.customFont("CabinetGrotesk-Medium", size: 13))
                            .foregroundColor(
                                feature.enabled
                                    ? (isSelected ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
                                    : (isSelected ? Color.black.opacity(0.3) : Color.white.opacity(0.3))
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(isSelected ? Color.white : Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.white : Color.white.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(20)
        .onTapGesture { onTap() }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
