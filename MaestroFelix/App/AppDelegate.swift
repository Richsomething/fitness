import UIKit
import UserNotifications

/// Where a tap on a notification asks the app to go.
@MainActor @Observable
final class AppRouter {
    static let shared = AppRouter()
    /// Set by a tap on a reminder; the shell shows Today and clears it.
    var opensToday = false
}

/// How notifications behave: a rest alert stays quiet while the app is open (the phone already buzzes
/// in the hand), reminders show as banners, and a tap opens Today.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        notification.request.identifier == RestAlert.identifier ? [] : [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { AppRouter.shared.opensToday = true }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    // The centre keeps its delegate weakly.
    private let router = NotificationRouter()

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = router
        return true
    }
}
