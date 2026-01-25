import SwiftUI
import UIKit

// Font extension for safe custom font loading with fallback
extension Font {
    static func customFont(_ name: String, size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if let font = UIFont(name: name, size: size) {
            return Font(font)
        }
        return .system(size: size, weight: weight)
    }
}

