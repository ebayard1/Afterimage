import Foundation
import FirebaseFirestore

/// Live notifications inbox for the signed-in user (`users/{uid}/notifications`).
@Observable
@MainActor
final class NotificationService {
    var items: [AppNotificationItem] = []

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private let db = Firestore.firestore()
    @ObservationIgnored private var uid: String?

    var unreadCount: Int { items.filter { !$0.read }.count }

    func startListening(uid: String) {
        self.uid = uid
        listener?.remove()
        listener = db.collection("users").document(uid).collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.items = docs.compactMap { try? $0.data(as: AppNotificationItem.self) }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        items = []
        uid = nil
    }

    func markRead(_ id: String) {
        guard let uid else { return }
        Task {
            try? await db.collection("users").document(uid)
                .collection("notifications").document(id)
                .updateData(["read": true])
        }
    }
}
