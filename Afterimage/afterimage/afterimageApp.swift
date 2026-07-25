import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
struct afterimageApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Handles Firebase init, InjectionIII hot-reload, and (real mode only) APNs/FCM
/// push registration. The FCM token is handed to `PushRegistry` so it can be
/// saved onto the signed-in user's profile.
final class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        sweepStaleRecordings()

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    /// One-time launch sweep: delete camera recordings stranded in tmp by
    /// past failed uploads (each can be up to 200MB — these were what made
    /// the app's storage footprint balloon). Anything older than a day is
    /// definitively garbage; an in-flight upload's file is always younger.
    private func sweepStaleRecordings() {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            let tmp = fm.temporaryDirectory
            guard let files = try? fm.contentsOfDirectory(
                at: tmp, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }
            let cutoff = Date().addingTimeInterval(-24 * 3600)
            for url in files where url.pathExtension.lowercased() == "mov" {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                if modified < cutoff { try? fm.removeItem(at: url) }
            }
        }
    }

    // MARK: MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in PushRegistry.shared.update(fcmToken) }
    }

    // MARK: UNUserNotificationCenterDelegate — show banners in-foreground.

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
