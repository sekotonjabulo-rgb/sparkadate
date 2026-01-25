# Build Notes for Sideloadly/IPA

## New Native SwiftUI Views

The app now uses native SwiftUI views instead of loading HTML pages in the WebView for key screens.

### Files Added:
- `Spark/SplashScreenView.swift` - SwiftUI splash screen view (replaces `app.html`)
- `Spark/SplashViewController.swift` - UIKit wrapper for the splash screen
- `Spark/OnboardingView.swift` - SwiftUI onboarding view (replaces `onboarding.html`)
- `Spark/OnboardingViewController.swift` - UIKit wrapper for the onboarding screen
- `Spark/Spark.swift` - Shared WebView reference struct

### Project Configuration:
✅ All new Swift files have been added to `Spark.xcodeproj/project.pbxproj`
✅ Files are included in the build sources

### Assets:
The splash screen will try to load the logo from:
1. Asset catalog: `LaunchIcon` or `spark-icon`
2. Bundle resources: `spark-icon.png`
3. Web assets folder: `sparkadate/spark-icon.png`
4. Fallback: System heart icon (if none found)

**Recommendation:** Add `spark-icon.png` to `Spark/Assets.xcassets` as an image set named "spark-icon" for best results.

### Font:
The splash screen uses `CabinetGrotesk-Medium`. If you want the custom font:
- Add the font file to the project
- Include it in `Info.plist` under `UIAppFonts` (Fonts provided by application)

If the font isn't available, it will fall back to the system font.

### Building the IPA:
When building your IPA (via your build service/CI/CD):
1. Ensure all Swift files are compiled (they're now in the project file)
2. The splash screen will automatically show on app launch
3. After 2 seconds, it navigates to the appropriate page based on auth status

### Testing:
After sideloading with Sideloadly:
- App should show native splash screen with logo and "Spark" text
- After 2 seconds, should navigate to native onboarding view (if not logged in) or match page (if logged in)
- Onboarding screen should show "Spark" wordmark, tagline, and two action buttons
- Tapping "Get Started" should navigate to `onboarding1.html` in WebView
- Tapping "I already have an account" should navigate to `login.html` in WebView
- WebView should load the appropriate HTML pages after native screens

