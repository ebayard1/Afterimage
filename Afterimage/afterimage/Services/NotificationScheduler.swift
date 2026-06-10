import Foundation
import UserNotifications

enum NotificationScheduler {
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func scheduleReveal(albumId: String, albumName: String, at revealDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "🌅 \(albumName) is ready"
        content.body = "Your album developed at sunrise. Tap to reveal with the group."
        content.sound = .default

        let interval = max(60, revealDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reveal-\(albumId)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelReveal(albumId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["reveal-\(albumId)"])
    }
}
