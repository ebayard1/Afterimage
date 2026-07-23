import Foundation
import FirebaseFirestore

/// Friend requests + connections for the signed-in user.
///
/// Requests live in the top-level `friendRequests` collection. Accepting flips
/// `status` to "accepted"; the `onFriendRequestUpdated` Cloud Function then adds
/// each user to the other's `friendIds`. The accepted friends themselves are
/// read off the current user's `UserProfile.friendIds` and resolved via
/// `UserService`, so this service focuses on incoming requests + actions.
@Observable
@MainActor
final class FriendService {
    var incoming: [FriendRequestModel] = []

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private let db = Firestore.firestore()

    func startListening(uid: String) {
        listener?.remove()
        listener = db.collection("friendRequests")
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self?.incoming = docs.compactMap { try? $0.data(as: FriendRequestModel.self) }
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        incoming = []
    }

    /// Sends a pending request, unless one already exists in either direction.
    func sendRequest(from fromUid: String, to toUid: String) async throws {
        guard fromUid != toUid else { return }
        let existing = try await db.collection("friendRequests")
            .whereField("fromUid", in: [fromUid, toUid])
            .getDocuments()
        let dupe = existing.documents.contains { doc in
            let d = doc.data()
            let a = d["fromUid"] as? String, b = d["toUid"] as? String
            return (a == fromUid && b == toUid) || (a == toUid && b == fromUid)
        }
        if dupe { return }
        let req = FriendRequestModel(id: nil, fromUid: fromUid, toUid: toUid,
                                     status: "pending", createdAt: Date())
        _ = try db.collection("friendRequests").addDocument(from: req)
    }

    func accept(_ request: FriendRequestModel) async throws {
        guard let id = request.id else { return }
        try await db.collection("friendRequests").document(id)
            .updateData(["status": "accepted"])
    }

    func decline(_ request: FriendRequestModel) async throws {
        guard let id = request.id else { return }
        try await db.collection("friendRequests").document(id)
            .updateData(["status": "declined"])
    }
}
