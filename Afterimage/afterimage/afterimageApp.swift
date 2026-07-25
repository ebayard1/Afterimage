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
        sweepTempDirectory()
        // Sweep again whenever the app goes to background — spool files
        // accumulate DURING a session (every cancelled feed-image fetch
        // leaves one), not just across launches.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil
        ) { _ in Self.runTempSweep() }

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

    /// tmp is disposable by definition, and this app leaks into it at scale:
    /// CFNetwork spool files (CFNetworkDownload_*.tmp) left behind by the
    /// constant image fetches the panning feed starts and cancels, plus
    /// camera recordings stranded by failed uploads. Measured on device
    /// 2026-07-25: 18,904 files ≈ 135GB — "why is this the largest app on
    /// my phone." Sweep deletes ANYTHING older than 15 minutes: in-flight
    /// work is always younger (network timeouts are 20s; recordings begin
    /// uploading the moment they end).
    private func sweepTempDirectory() { Self.runTempSweep() }

    fileprivate static func runTempSweep() {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            let tmp = fm.temporaryDirectory
            guard let files = try? fm.contentsOfDirectory(
                at: tmp, includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { return }
            let cutoff = Date().addingTimeInterval(-15 * 60)
            var removed = 0
            for url in files {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                if modified < cutoff {
                    try? fm.removeItem(at: url)
                    removed += 1
                }
            }
            #if DEBUG
            if removed > 0 { print("🧹 tmp sweep removed \(removed) stale files") }
            #endif
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
