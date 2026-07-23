import Foundation
import FirebaseFirestore

/// Live activity-rail feed for the signed-in user (`users/{uid}/feed`).
@Observable
@MainActor
final class ActivityService {
    var items: [FeedItem] = []

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private let db = Firestore.firestore()

    func startListening(uid: String) {
        listener?.remove()
        listener = db.collection("users").document(uid).collection("feed")
            .order(by: "happenedAt", descending: true)
            .limit(to: 40)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.items = docs.compactMap { try? $0.data(as: FeedItem.self) }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        items = []
    }
}
