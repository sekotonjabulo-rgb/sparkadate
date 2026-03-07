import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    static var shared: AppDelegate? {
        return UIApplication.shared.delegate as? AppDelegate
    }

    var deviceToken: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        registerForPushNotifications()
        registerNotificationCategories()

        // Handle notification that launched the app
        if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
            handleNotificationPayload(notification)
        }

        return true
    }

    // MARK: - Push Notification Registration

    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func registerNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ACTION",
            title: "View",
            options: [.foreground]
        )

        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [.foreground],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Type a message..."
        )

        let matchCategory = UNNotificationCategory(
            identifier: "MATCH",
            actions: [viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE",
            actions: [viewAction, replyAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let generalCategory = UNNotificationCategory(
            identifier: "GENERAL",
            actions: [viewAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            matchCategory, messageCategory, generalCategory
        ])
    }

    // MARK: - Token Handling

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken tokenData: Data
    ) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        print("APNs device token: \(token)")

        // Forward token to web app if it's loaded
        DispatchQueue.main.async {
            self.activeViewController?.webView.evaluateJavaScript(
                "window.SparkNative && SparkNative._onPushToken && SparkNative._onPushToken('\(token)');"
            )
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            handleNotificationPayload(userInfo)

        case "VIEW_ACTION":
            handleNotificationPayload(userInfo)

        case "REPLY_ACTION":
            if let textResponse = response as? UNTextInputNotificationResponse {
                let replyText = textResponse.userText
                handleReply(replyText, payload: userInfo)
            }

        case UNNotificationDismissActionIdentifier:
            break

        default:
            break
        }

        completionHandler()
    }

    // MARK: - Notification Payload Handling

    private func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        guard let deepLink = userInfo["deep_link"] as? String ?? userInfo["path"] as? String else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.activeViewController?.navigateToPath(deepLink)
        }
    }

    private func handleReply(_ text: String, payload: [AnyHashable: Any]) {
        // Forward inline reply to the web app
        let escapedText = text.replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")

        DispatchQueue.main.async {
            let js = """
            window.SparkNative && SparkNative._onNotificationReply &&
            SparkNative._onNotificationReply('\(escapedText)');
            """
            self.activeViewController?.webView.evaluateJavaScript(js)
        }
    }

    // MARK: - Helper

    private var activeViewController: ViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let vc = window.rootViewController as? ViewController else {
            return nil
        }
        return vc
    }

    // MARK: - UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
