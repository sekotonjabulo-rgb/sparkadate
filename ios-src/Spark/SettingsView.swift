import SwiftUI
import PhotosUI

// MARK: - Settings View Model
class SettingsViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var email = ""
    @Published var location = ""
    @Published var subscriptionTier = "free"
    @Published var ageMin: Double = 18
    @Published var ageMax: Double = 30
    @Published var maxDistance: Double = 50
    @Published var relationshipIntent = "Something serious"
    @Published var photos: [(id: String, url: String, isPrimary: Bool)] = []
    @Published var hasChanges = false
    @Published var isSaving = false
    @Published var saveStatus: SaveStatus = .idle
    @Published var isLoading = true
    @Published var notificationsEnabled = false

    private let api = SparkAPIService.shared
    let intentOptions = ["Something casual", "Something serious", "New friends", "Not sure yet"]

    enum SaveStatus {
        case idle, saving, saved, error(String)
    }

    func loadProfile() {
        Task {
            do {
                let result = try await api.apiRequest("/users/me")
                await MainActor.run {
                    if let user = result["user"] as? [String: Any] {
                        self.displayName = user["display_name"] as? String ?? ""
                        self.email = user["email"] as? String ?? ""
                        self.location = user["location"] as? String ?? ""
                        self.subscriptionTier = user["subscription_tier"] as? String ?? "free"

                        if let photosArray = user["user_photos"] as? [[String: Any]] {
                            self.photos = photosArray.compactMap { photo in
                                guard let id = photo["id"] as? String,
                                      let url = photo["photo_url"] as? String else { return nil }
                                let isPrimary = photo["is_primary"] as? Bool ?? false
                                return (id: id, url: url, isPrimary: isPrimary)
                            }
                        }

                        if let prefs = (user["user_preferences"] as? [[String: Any]])?.first {
                            self.ageMin = Double(prefs["age_min"] as? Int ?? 18)
                            self.ageMax = Double(prefs["age_max"] as? Int ?? 30)
                            self.maxDistance = Double(prefs["max_distance_km"] as? Int ?? 50)
                            self.relationshipIntent = prefs["relationship_intent"] as? String ?? "Something serious"
                        }
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    func saveChanges() {
        isSaving = true
        saveStatus = .saving
        Task {
            do {
                let _ = try await api.apiRequest("/users/me", method: "PUT", body: [
                    "display_name": displayName,
                    "location": location
                ])
                let _ = try await api.apiRequest("/users/me/preferences", method: "PUT", body: [
                    "age_min": Int(ageMin),
                    "age_max": Int(ageMax),
                    "max_distance_km": Int(maxDistance),
                    "relationship_intent": relationshipIntent
                ])

                // Update local storage
                if var userData = UserDefaults.standard.data(forKey: "sparkUser")
                    .flatMap({ try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) {
                    userData["display_name"] = displayName
                    if let data = try? JSONSerialization.data(withJSONObject: userData) {
                        UserDefaults.standard.set(data, forKey: "sparkUser")
                    }
                }

                await MainActor.run {
                    self.isSaving = false
                    self.saveStatus = .saved
                    self.hasChanges = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if case .saved = self.saveStatus { self.saveStatus = .idle }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.saveStatus = .error(error.localizedDescription)
                }
            }
        }
    }

    func uploadPhoto(image: UIImage, slot: Int) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let base64 = "data:image/jpeg;base64," + data.base64EncodedString()

        Task {
            do {
                let result = try await api.apiRequest("/users/me/photos", method: "POST", body: [
                    "photo": base64,
                    "slot_index": slot
                ])
                await MainActor.run {
                    if let photo = result["photo"] as? [String: Any],
                       let id = photo["id"] as? String,
                       let url = photo["photo_url"] as? String {
                        let isPrimary = photo["is_primary"] as? Bool ?? false
                        self.photos.append((id: id, url: url, isPrimary: isPrimary))
                    }
                }
            } catch {
                print("Photo upload error: \(error)")
            }
        }
    }

    func deletePhoto(id: String) {
        Task {
            do {
                let _ = try await api.apiRequest("/users/me/photos/\(id)", method: "DELETE")
                await MainActor.run {
                    self.photos.removeAll { $0.id == id }
                }
            } catch {
                print("Photo delete error: \(error)")
            }
        }
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "sparkToken")
        UserDefaults.standard.removeObject(forKey: "sparkUser")
        UserDefaults.standard.removeObject(forKey: "sparkCurrentMatch")
        UserDefaults.standard.removeObject(forKey: "sparkLastPage")
        UserDefaults.standard.removeObject(forKey: "sparkPlanCompleted")
    }

    func deleteAccount() {
        Task {
            do {
                let _ = try await api.apiRequest("/users/me", method: "DELETE")
                await MainActor.run {
                    self.logout()
                }
            } catch {
                print("Delete account error: \(error)")
            }
        }
    }

    func markChanged() {
        hasChanges = true
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showPhotoPickerForSlot: Int? = nil
    @State private var showDeleteAccountAlert = false
    @State private var showLogoutAlert = false
    @State private var opacity: Double = 0

    var onBack: (() -> Void)?
    var onLogout: (() -> Void)?
    var onNavigateToPlan: (() -> Void)?
    var onNavigateToSupport: (() -> Void)?

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
                    Text("Settings")
                        .font(.customFont("CabinetGrotesk-Medium", size: 17))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 28) {
                            profileSection
                            photosSection
                            preferencesSection
                            linksSection
                            dangerSection
                            versionLabel
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, viewModel.hasChanges ? 80 : 32)
                    }
                }

                // Save bar
                if viewModel.hasChanges {
                    saveBar
                }
            }
            .frame(maxWidth: 428)
            .opacity(opacity)
        }
        .onAppear {
            viewModel.loadProfile()
            withAnimation(.easeOut(duration: 0.5)) { opacity = 1 }
        }
        .sheet(item: Binding(
            get: { showPhotoPickerForSlot.map { SettingsPhotoSlot(slot: $0) } },
            set: { showPhotoPickerForSlot = $0?.slot }
        )) { slotItem in
            ImagePicker(onImagePicked: { image in
                viewModel.uploadPhoto(image: image, slot: slotItem.slot)
                showPhotoPickerForSlot = nil
            })
        }
        .alert("Log out?", isPresented: $showLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Log out", role: .destructive) {
                viewModel.logout()
                onLogout?()
            }
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete permanently", role: .destructive) {
                viewModel.deleteAccount()
                onLogout?()
            }
        } message: {
            Text("This will permanently delete your account and all data. This cannot be undone.")
        }
    }

    // MARK: - Profile Section
    private var profileSection: some View {
        VStack(spacing: 16) {
            sectionHeader("PROFILE")

            // Avatar
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 70, height: 70)
                    if let firstPhoto = viewModel.photos.first(where: { $0.isPrimary }) ?? viewModel.photos.first,
                       let url = URL(string: firstPhoto.url) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Text(String(viewModel.displayName.prefix(1)).uppercased())
                                .font(.customFont("CabinetGrotesk-Medium", size: 24))
                                .foregroundColor(.white)
                        }
                        .frame(width: 70, height: 70)
                        .clipShape(Circle())
                    } else {
                        Text(String(viewModel.displayName.prefix(1)).uppercased())
                            .font(.customFont("CabinetGrotesk-Medium", size: 24))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(viewModel.displayName)
                            .font(.customFont("CabinetGrotesk-Medium", size: 20))
                            .foregroundColor(.white)
                        if viewModel.subscriptionTier == "pro" {
                            Text("PRO")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(6)
                        }
                    }
                    Text(viewModel.email)
                        .font(.customFont("CabinetGrotesk-Medium", size: 13))
                        .foregroundColor(Color.white.opacity(0.65))
                }
                Spacer()
            }

            // Name input
            VStack(alignment: .leading, spacing: 6) {
                Text("Display name")
                    .font(.customFont("CabinetGrotesk-Medium", size: 12))
                    .foregroundColor(Color.white.opacity(0.65))
                SparkTextField(text: $viewModel.displayName, placeholder: "Your name")
                    .onChange(of: viewModel.displayName) { _ in viewModel.markChanged() }
            }

            // Location input
            VStack(alignment: .leading, spacing: 6) {
                Text("Location")
                    .font(.customFont("CabinetGrotesk-Medium", size: 12))
                    .foregroundColor(Color.white.opacity(0.65))
                SparkTextField(text: $viewModel.location, placeholder: "City, Country")
                    .onChange(of: viewModel.location) { _ in viewModel.markChanged() }
            }
        }
    }

    // MARK: - Photos Section
    private var photosSection: some View {
        VStack(spacing: 12) {
            sectionHeader("PHOTOS")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    if index < viewModel.photos.count {
                        let photo = viewModel.photos[index]
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: URL(string: photo.url)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color.white.opacity(0.08)
                            }
                            .frame(minHeight: 120)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            .cornerRadius(12)

                            Button(action: { viewModel.deletePhoto(id: photo.id) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                            }
                            .padding(4)

                            if photo.isPrimary {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Text("Main")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(4)
                                        Spacer()
                                    }
                                    .padding(6)
                                }
                            }
                        }
                        .aspectRatio(1, contentMode: .fit)
                    } else {
                        Button(action: { showPhotoPickerForSlot = index }) {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Image(systemName: "plus")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color.white.opacity(0.3))
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(spacing: 20) {
            sectionHeader("MATCH PREFERENCES")

            // Age range
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Age range")
                        .font(.customFont("CabinetGrotesk-Medium", size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(viewModel.ageMin)) - \(Int(viewModel.ageMax))")
                        .font(.customFont("CabinetGrotesk-Medium", size: 14))
                        .foregroundColor(Color.white.opacity(0.65))
                }
                HStack(spacing: 12) {
                    Slider(value: $viewModel.ageMin, in: 18...64, step: 1) {
                        Text("Min")
                    }
                    .tint(.white)
                    .onChange(of: viewModel.ageMin) { val in
                        if val > viewModel.ageMax { viewModel.ageMax = val }
                        viewModel.markChanged()
                    }
                    Slider(value: $viewModel.ageMax, in: 19...65, step: 1) {
                        Text("Max")
                    }
                    .tint(.white)
                    .onChange(of: viewModel.ageMax) { val in
                        if val < viewModel.ageMin { viewModel.ageMin = val }
                        viewModel.markChanged()
                    }
                }
            }

            // Distance
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Maximum distance")
                        .font(.customFont("CabinetGrotesk-Medium", size: 14))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(viewModel.maxDistance)) km")
                        .font(.customFont("CabinetGrotesk-Medium", size: 14))
                        .foregroundColor(Color.white.opacity(0.65))
                }
                Slider(value: $viewModel.maxDistance, in: 5...200, step: 1)
                    .tint(.white)
                    .onChange(of: viewModel.maxDistance) { _ in viewModel.markChanged() }
            }

            // Relationship intent
            VStack(alignment: .leading, spacing: 8) {
                Text("Looking for")
                    .font(.customFont("CabinetGrotesk-Medium", size: 14))
                    .foregroundColor(.white)

                Menu {
                    ForEach(viewModel.intentOptions, id: \.self) { option in
                        Button(option) {
                            viewModel.relationshipIntent = option
                            viewModel.markChanged()
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.relationshipIntent)
                            .font(.customFont("CabinetGrotesk-Medium", size: 15))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Links Section
    private var linksSection: some View {
        VStack(spacing: 0) {
            sectionHeader("SUPPORT")
                .padding(.bottom, 8)

            settingsLink(icon: "star", title: "Upgrade to Pro") {
                onNavigateToPlan?()
            }
            Divider().background(Color.white.opacity(0.08))
            settingsLink(icon: "questionmark.circle", title: "Help & Support") {
                onNavigateToSupport?()
            }
        }
    }

    // MARK: - Danger Section
    private var dangerSection: some View {
        VStack(spacing: 0) {
            Button(action: { showLogoutAlert = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 1, green: 0.27, blue: 0.23))
                    Text("Log out")
                        .font(.customFont("CabinetGrotesk-Medium", size: 15))
                        .foregroundColor(Color(red: 1, green: 0.27, blue: 0.23))
                    Spacer()
                }
                .padding(.vertical, 14)
            }
            Divider().background(Color.white.opacity(0.08))
            Button(action: { showDeleteAccountAlert = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 1, green: 0.27, blue: 0.23))
                    Text("Delete account")
                        .font(.customFont("CabinetGrotesk-Medium", size: 15))
                        .foregroundColor(Color(red: 1, green: 0.27, blue: 0.23))
                    Spacer()
                }
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - Version
    private var versionLabel: some View {
        Text("Spark v1.0.0")
            .font(.customFont("CabinetGrotesk-Medium", size: 12))
            .foregroundColor(Color.white.opacity(0.3))
            .padding(.top, 8)
    }

    // MARK: - Save Bar
    private var saveBar: some View {
        VStack {
            Button(action: { viewModel.saveChanges() }) {
                Group {
                    switch viewModel.saveStatus {
                    case .saving:
                        ProgressView().tint(.black)
                    case .saved:
                        Text("Saved!")
                            .font(.customFont("CabinetGrotesk-Medium", size: 16))
                            .foregroundColor(.black)
                    default:
                        Text("Save changes")
                            .font(.customFont("CabinetGrotesk-Medium", size: 16))
                            .foregroundColor(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .cornerRadius(28)
            }
            .disabled(viewModel.isSaving)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            Color.black.opacity(0.8)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.customFont("CabinetGrotesk-Medium", size: 12))
                .foregroundColor(Color.white.opacity(0.45))
                .tracking(0.5)
            Spacer()
        }
    }

    private func settingsLink(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text(title)
                    .font(.customFont("CabinetGrotesk-Medium", size: 15))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.3))
            }
            .padding(.vertical, 14)
        }
    }
}

// MARK: - Settings Photo Slot (for sheet binding)
struct SettingsPhotoSlot: Identifiable {
    let slot: Int
    var id: Int { slot }
}
