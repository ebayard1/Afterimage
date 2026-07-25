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

    /// Quality every image this app uploads is encoded at.
    ///
    /// 0.85, paired with the 2600 px long-edge cap baked in by
    /// `CameraController.processed` (see `maxUploadPixels` there). Together they
    /// put a shot on Storage at roughly 1–1.5 MB instead of 3–5 MB.
    ///
    /// **Do not drop this to 0.8.** It was tried, and it fails on the slideshow:
    /// captures are cropped to the viewfinder's ~0.581 aspect, so the SHORT edge
    /// (≈ long × 0.581) is what the full-screen layout binds against, and it
    /// must stay ≥ the ~1320 px panel width or the photo is magnified rather
    /// than minified. Ringing that is invisible under a downscale becomes
    /// visible the moment the hero surface is upscaling, and the loss is
    /// permanent — already-uploaded shots can't be re-encoded better.
    nonisolated static let jpegQuality: CGFloat = 0.85

    /// Encode off the main actor. This class is `@MainActor`, so `jpegData` ran
    /// on the main thread — a multi-megapixel encode landing right after the
    /// shutter, while the black-out is fading out and the user may already be
    /// tapping for the next frame.
    nonisolated private static func encodeJPEG(_ image: UIImage) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            image.jpegData(compressionQuality: jpegQuality)
        }.value
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
        guard let data = await Self.encodeJPEG(image) else {
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
        // This roll's film strip may be served by the cached `fetchShotURLs`
        // fallback (it is, for any roll the `onShotCreated` backfill hasn't
        // reached). Evict it so the card you just shot into re-reads instead of
        // showing the pre-shot frames for the rest of the session.
        await AlbumService.invalidateShotURLs(albumId: albumId)
    }

    /// Upload a video shot: the .mov file plus its poster still. `photoURL` on
    /// the resulting Shot holds the poster (so thumbnails never autoplay);
    /// `videoURL` holds the movie, played only when tapped into full screen.
    func uploadVideo(
        fileURL: URL,
        poster: UIImage,
        albumId: String,
        userId: String,
        note: String?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil
    ) async throws {
        // The poster is already capped at 1080×1920 by
        // `CameraController.posterFrame`'s `gen.maximumSize`, so there is
        // nothing to resize here — only the same 0.8 encode.
        guard let posterData = await Self.encodeJPEG(poster) else {
            throw NSError(domain: "ShotService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't encode poster"])
        }
        let shotId = UUID().uuidString
        let posterRef = storage.reference(withPath: "albums/\(albumId)/shots/\(shotId).jpg")
        let videoRef = storage.reference(withPath: "albums/\(albumId)/shots/\(shotId).mov")
        let posterMeta = StorageMetadata(); posterMeta.contentType = "image/jpeg"
        let videoMeta = StorageMetadata(); videoMeta.contentType = "video/quicktime"

        let posterURL: String
        let videoURL: String
        do {
            _ = try await posterRef.putDataAsync(posterData, metadata: posterMeta)
            posterURL = try await posterRef.downloadURL().absoluteString
            _ = try await videoRef.putFileAsync(from: fileURL, metadata: videoMeta)
            videoURL = try await videoRef.downloadURL().absoluteString
        } catch {
            throw NSError(domain: "ShotService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "storage upload failed: \(error.localizedDescription)"
            ])
        }

        let cleanedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shot = Shot(
            id: shotId,
            userId: userId,
            photoURL: posterURL,
            videoURL: videoURL,
            createdAt: Date(),
            note: (cleanedNote?.isEmpty ?? true) ? nil : cleanedNote,
            reactions: nil,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName
        )
        do {
            try await db.collection("albums").document(albumId)
                .collection("shots").document(shotId)
                .setData(from: shot)
        } catch {
            throw NSError(domain: "ShotService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "saving shot failed: \(error.localizedDescription)"
            ])
        }
        // Same as `upload(image:)` — the strip's cached fallback list is now
        // one frame behind.
        await AlbumService.invalidateShotURLs(albumId: albumId)
        // Clean up the temp recording now it's safely uploaded.
        try? FileManager.default.removeItem(at: fileURL)
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
