import Foundation
import FirebaseFirestore

/// Live activity-rail feed for the signed-in user (`users/{uid}/feed`).
@Observable
@MainActor
final class ActivityService {
    /// The raw snapshot, exactly as stored. Keeps the fields the rail's view
    /// model drops (`albumId`, `actorUid`) for anything that needs to act on an
    /// event rather than just print it.
    var items: [FeedItem] = []

    /// The rail-ready projection of `items`, computed once per snapshot.
    ///
    /// `HomeView` used to map `items` → `[ActivityEvent]` inside a computed
    /// property read from its body, so the whole 40-element array was rebuilt on
    /// every single HomeView body evaluation — and that page re-evaluates
    /// constantly (the shared clock, three Firestore listeners, sheet state)
    /// (PERF_DIAGNOSIS §5.6). The mapping only ever changes when a snapshot
    /// lands, so it belongs here, next to the thing that changes.
    var events: [ActivityEvent] = []

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
                    let decoded = docs.compactMap { try? $0.data(as: FeedItem.self) }
                    self?.items = decoded
                    self?.events = decoded.map { Self.event(from: $0) }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        items = []
        events = []
    }

    /// One feed document as the rail renders it. `actorPhotoSeed` is empty on
    /// purpose: it is the sample-mode picsum fallback, and real events always
    /// carry a real `actorPhotoURL` (or none at all).
    private static func event(from item: FeedItem) -> ActivityEvent {
        ActivityEvent(
            kind: item.eventKind,
            actorUsername: item.actorUsername,
            actorPhotoSeed: "",
            actorPhotoURL: item.actorPhotoURL,
            albumName: item.albumName,
            detail: item.detail,
            happenedAt: item.happenedAt
        )
    }
}
