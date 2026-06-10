import Foundation
import UIKit
import FirebaseFirestore
import FirebaseStorage

@Observable
@MainActor
final class ShotService {
    var shots: [Shot] = []
    var myShotCount = 0

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private let db = Firestore.firestore()
    @ObservationIgnored private let storage = Storage.storage()

    func startListening(albumId: String, currentUserId: String) {
        listener?.remove()
        listener = db.collection("albums").document(albumId).collection("shots")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    let parsed = docs.compactMap { try? $0.data(as: Shot.self) }
                    self?.shots = parsed
                    self?.myShotCount = parsed.filter { $0.userId == currentUserId }.count
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        shots = []
        myShotCount = 0
    }

    func upload(image: UIImage, albumId: String, userId: String, note: String?) async throws {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(
                domain: "ShotService", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't encode image"]
            )
        }

        let shotId = UUID().uuidString
        let path = "albums/\(albumId)/shots/\(shotId).jpg"
        let ref = storage.reference(withPath: path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let downloadURL = try await ref.downloadURL()
        let urlString = downloadURL.absoluteString

        let cleanedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shot = Shot(
            id: shotId,
            userId: userId,
            photoURL: urlString,
            createdAt: Date(),
            note: (cleanedNote?.isEmpty ?? true) ? nil : cleanedNote,
            reactions: nil
        )
        try db.collection("albums").document(albumId)
            .collection("shots").document(shotId)
            .setData(from: shot)

        // First shot becomes the album cover (best-effort, ignore errors)
        let albumRef = db.collection("albums").document(albumId)
        if let snap = try? await albumRef.getDocument(),
           let existing = snap.data()?["coverPhotoURL"] as? String,
           !existing.isEmpty { /* cover already set */ } else {
            try? await albumRef.updateData(["coverPhotoURL": urlString])
        }
    }

    func toggleReaction(shotId: String, albumId: String, userId: String, emoji: String) async throws {
        let ref = db.collection("albums").document(albumId)
            .collection("shots").document(shotId)
        let snap = try await ref.getDocument()
        let shot = try snap.data(as: Shot.self)
        var reactions = shot.reactions ?? [:]
        var users = reactions[emoji] ?? []
        if users.contains(userId) {
            users.removeAll { $0 == userId }
        } else {
            users.append(userId)
        }
        if users.isEmpty {
            reactions[emoji] = nil
        } else {
            reactions[emoji] = users
        }
        try await ref.updateData(["reactions": reactions])
    }
}
