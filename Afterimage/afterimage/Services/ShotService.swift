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

    func upload(
        image: UIImage,
        albumId: String,
        userId: String,
        note: String?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil
    ) async throws {
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
        // Tag which stage failed so the camera can show a precise message
        // instead of a generic "upload failed".
        let urlString: String
        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
            let downloadURL = try await ref.downloadURL()
            urlString = downloadURL.absoluteString
        } catch {
            throw NSError(domain: "ShotService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "storage upload failed: \(error.localizedDescription)"
            ])
        }

        let cleanedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shot = Shot(
            id: shotId,
            userId: userId,
            photoURL: urlString,
            createdAt: Date(),
            note: (cleanedNote?.isEmpty ?? true) ? nil : cleanedNote,
            reactions: nil,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        )
        // Write ONLY the shot. The `onShotCreated` Cloud Function owns the
        // album's denormalized fields (previewURLs, shotCount, coverPhotoURL)
        // and copies the first located shot's place onto the album — keeping
        // those writes server-side so the security rules can stay strict.
        do {
            try await db.collection("albums").document(albumId)
                .collection("shots").document(shotId)
                .setData(from: shot)
        } catch {
            throw NSError(domain: "ShotService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "saving shot failed: \(error.localizedDescription)"
            ])
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
