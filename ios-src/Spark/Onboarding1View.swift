import SwiftUI
import CoreLocation

// MARK: - Onboarding Data Model
class OnboardingData: ObservableObject {
    @Published var age: String = ""
    @Published var gender: String? = nil
    @Published var seeking: String? = nil
    @Published var location: String = ""
    @Published var latitude: Double? = nil
    @Published var longitude: Double? = nil
    @Published var photos: [UIImage?] = [nil, nil, nil]

    var ageInt: Int? { Int(age) }
    var isAgeValid: Bool { if let a = ageInt { return a >= 18 && a <= 120 } else { return false } }
    var isGenderStepValid: Bool { gender != nil && seeking != nil }
    var isLocationValid: Bool { !location.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasAtLeastOnePhoto: Bool { photos.contains(where: { $0 != nil }) }

    func toJSON() -> [String: Any] {
        var dict: [String: Any] = [
            "age": ageInt ?? 0,
            "gender": gender ?? "",
            "seeking": seeking ?? "",
            "location": location
        ]
        if let lat = latitude { dict["latitude"] = lat }
        if let lon = longitude { dict["longitude"] = lon }

        var photoStrings: [String] = []
        for photo in photos {
            if let img = photo, let data = img.jpegData(compressionQuality: 0.6) {
                photoStrings.append("data:image/jpeg;base64,\(data.base64EncodedString())")
            }
        }
        dict["photos"] = photoStrings
        return dict
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: String = ""
    @Published var latitude: Double? = nil
    @Published var longitude: Double? = nil

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            if let place = placemarks?.first {
                let city = place.locality ?? place.subAdministrativeArea ?? ""
                let region = place.administrativeArea ?? place.country ?? ""
                DispatchQueue.main.async {
                    self?.location = city.isEmpty ? region : "\(city), \(region)"
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Main Onboarding1 View
struct Onboarding1View: View {
    @StateObject private var data = OnboardingData()
    @StateObject private var locationManager = LocationManager()
    @State private var currentStep = 1
    @State private var opacity: Double = 0
    @State private var blur: CGFloat = 12
    @State private var isLoading = false
    var onComplete: (([String: Any]) -> Void)?
    var onNavigateToSignup: (([String: Any]) -> Void)?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                ProgressBarView(currentStep: currentStep, totalSteps: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                // Content
                Group {
                    switch currentStep {
                    case 1: AgeStepView(data: data, onContinue: { nextStep() })
                    case 2: GenderStepView(data: data, onContinue: { nextStep(); locationManager.requestLocation() })
                    case 3: LocationStepView(data: data, locationManager: locationManager, onContinue: { nextStep() })
                    case 4: PhotosStepView(data: data, isLoading: $isLoading, onContinue: { submitOnboarding() })
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 16)
            }
            .opacity(opacity)
            .blur(radius: blur)
            .frame(maxWidth: 428)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1
                blur = 0
            }
        }
    }

    private func nextStep() {
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep += 1
        }
    }

    private func submitOnboarding() {
        data.latitude = locationManager.latitude
        data.longitude = locationManager.longitude
        if data.location.isEmpty {
            data.location = locationManager.location
        }
        let json = data.toJSON()
        onNavigateToSignup?(json)
    }
}

// MARK: - Progress Bar
struct ProgressBarView: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 4)
                    .animation(.easeInOut(duration: 0.3), value: currentStep)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Step 1: Age
struct AgeStepView: View {
    @ObservedObject var data: OnboardingData
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How old are you?")
                .font(.customFont("CabinetGrotesk-Medium", size: 28))
                .foregroundColor(.white)
                .padding(.bottom, 8)

            Text("You must be at least 18 years old to use Spark.")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.65))
                .padding(.bottom, 24)

            SparkTextField(text: $data.age, placeholder: "Enter your age", keyboardType: .numberPad)

            Spacer()

            SparkButton(title: "Continue", isEnabled: data.isAgeValid, action: onContinue)
                .padding(.bottom, 24)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
    }
}

// MARK: - Step 2: Gender & Seeking
struct GenderStepView: View {
    @ObservedObject var data: OnboardingData
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tell us about yourself")
                .font(.customFont("CabinetGrotesk-Medium", size: 28))
                .foregroundColor(.white)
                .padding(.bottom, 20)

            Text("I am a")
                .font(.customFont("CabinetGrotesk-Medium", size: 13))
                .foregroundColor(Color.white.opacity(0.65))
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                OptionButton(title: "Man", isSelected: data.gender == "man") { data.gender = "man" }
                OptionButton(title: "Woman", isSelected: data.gender == "woman") { data.gender = "woman" }
                OptionButton(title: "Non-binary", isSelected: data.gender == "nonbinary") { data.gender = "nonbinary" }
            }

            Text("Looking for")
                .font(.customFont("CabinetGrotesk-Medium", size: 13))
                .foregroundColor(Color.white.opacity(0.65))
                .padding(.top, 20)
                .padding(.bottom, 10)

            VStack(spacing: 8) {
                OptionButton(title: "Men", isSelected: data.seeking == "men") { data.seeking = "men" }
                OptionButton(title: "Women", isSelected: data.seeking == "women") { data.seeking = "women" }
                OptionButton(title: "Everyone", isSelected: data.seeking == "everyone") { data.seeking = "everyone" }
            }

            Spacer()

            SparkButton(title: "Continue", isEnabled: data.isGenderStepValid, action: onContinue)
                .padding(.bottom, 24)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
    }
}

// MARK: - Step 3: Location
struct LocationStepView: View {
    @ObservedObject var data: OnboardingData
    @ObservedObject var locationManager: LocationManager
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Where are you located?")
                .font(.customFont("CabinetGrotesk-Medium", size: 28))
                .foregroundColor(.white)
                .padding(.bottom, 8)

            Text("This helps us find people near you.")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.65))
                .padding(.bottom, 24)

            SparkTextField(text: $data.location, placeholder: "City or region")

            Spacer()

            SparkButton(title: "Continue", isEnabled: data.isLocationValid, action: onContinue)
                .padding(.bottom, 24)
        }
        .onReceive(locationManager.$location) { loc in
            if data.location.isEmpty && !loc.isEmpty {
                data.location = loc
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
    }
}

// MARK: - Step 4: Photos
struct PhotosStepView: View {
    @ObservedObject var data: OnboardingData
    @Binding var isLoading: Bool
    var onContinue: () -> Void
    @State private var activePickerIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add your photos")
                .font(.customFont("CabinetGrotesk-Medium", size: 28))
                .foregroundColor(.white)
                .padding(.bottom, 8)

            Text("Add at least 1 photo. These stay hidden until you both reveal.")
                .font(.customFont("CabinetGrotesk-Medium", size: 14))
                .foregroundColor(Color.white.opacity(0.65))
                .padding(.bottom, 24)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    PhotoSlotView(image: $data.photos[index], isMain: index == 0) {
                        activePickerIndex = index
                    }
                }
            }

            Spacer()

            SparkButton(title: isLoading ? "Saving..." : "Continue", isEnabled: data.hasAtLeastOnePhoto && !isLoading, action: onContinue)
                .padding(.bottom, 24)
        }
        .sheet(item: $activePickerIndex) { index in
            ImagePicker(image: $data.photos[index])
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
    }
}

// MARK: - Photo Slot
struct PhotoSlotView: View {
    @Binding var image: UIImage?
    let isMain: Bool
    var onTap: () -> Void

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(3/4, contentMode: .fill)
                    .clipped()
                    .cornerRadius(16)

                // Remove button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { image = nil }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }
                    Spacer()
                }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
                    .aspectRatio(3/4, contentMode: .fill)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 24))
                            .foregroundColor(Color.white.opacity(0.65))
                    )
            }

            // "Main" label
            if isMain {
                VStack {
                    Spacer()
                    HStack {
                        Text("Main")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)
                            .padding(8)
                        Spacer()
                    }
                }
            }
        }
        .onTapGesture { if image == nil { onTap() } }
    }
}

// MARK: - Reusable Components
struct SparkTextField: View {
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        TextField("", text: $text)
            .placeholder(when: text.isEmpty) {
                Text(placeholder).foregroundColor(Color.white.opacity(0.65))
            }
            .keyboardType(keyboardType)
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

struct SparkButton: View {
    let title: String
    let isEnabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.customFont("CabinetGrotesk-Medium", size: 16))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white)
                .cornerRadius(28)
                .opacity(isEnabled ? 1 : 0.4)
        }
        .disabled(!isEnabled)
        .buttonStyle(OnboardingButtonStyle())
    }
}

struct OptionButton: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.customFont("CabinetGrotesk-Medium", size: 15))
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .frame(height: 48)
                .background(isSelected ? Color.white : Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.15), lineWidth: 1)
                )
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Placeholder Extension
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.image = img
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Int Identifiable for sheet
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
