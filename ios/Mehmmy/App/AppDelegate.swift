import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@MainActor
enum Backend {
    static var shared: FirebaseBackend?
    static var state: AppState?
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        guard FirebaseApp.app() != nil else { return true }
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized { await MainActor.run { application.registerForRemoteNotifications() } }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in Backend.shared?.saveToken(fcmToken) }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let crewID = info["crewId"] as? String
        let screen = info["screen"] as? String
        await MainActor.run {
            guard let state = Backend.state else { return }
            if let crewID, state.crews.contains(where: { $0.id == crewID }) { state.currentCrewID = crewID }
            if let screen, let tab = Tab(rawValue: screen) { state.tab = tab }
        }
    }
}
