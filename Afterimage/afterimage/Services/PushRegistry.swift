import Foundation

/// Bridges the APNs/FCM registration token (delivered to the AppDelegate) to the
/// signed-in user's profile. ContentView sets `onToken` once it knows the uid.
@MainActor
final class PushRegistry {
    static let shared = PushRegistry()
    private init() {}

    private(set) var token: String?
    /// Called whenever a fresh token arrives. ContentView wires this to
    /// `UserService.upsertFcmToken`.
    var onToken: ((String) -> Void)?

    func update(_ token: String) {
        self.token = token
        onToken?(token)
    }
}
