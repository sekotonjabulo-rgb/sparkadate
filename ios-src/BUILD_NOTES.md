# Build Notes for Sideloadly/IPA

## New Native Splash Screen

The app now uses a native Swift splash screen instead of loading `app.html` in the WebView.

### Files Added:
- `Spark/SplashScreenView.swift` - SwiftUI splash screen view
- `Spark/SplashViewController.swift` - UIKit wrapper for the splash screen
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
- After 2 seconds, should navigate to onboarding (if not logged in) or match page (if logged in)
- WebView should load the appropriate HTML page after splash

