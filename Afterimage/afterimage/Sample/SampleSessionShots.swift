import Foundation

/// In-memory store of shots taken during the current session for sample albums.
/// Resets on cold launch — the entire app is sample-only, so this is where any
/// camera-shutter ritual the user performs gets remembered until close.
@MainActor
@Observable
final class SampleSessionShots {
    static let shared = SampleSessionShots()
    private(set) var shotsByAlbum: [String: [Shot]] = [:]

    private init() {}

    func add(albumId: String, note: String?, userId: String) {
        let seed = String(UUID().uuidString.prefix(8))
        let cleanedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shot = Shot(
            id: "session-\(UUID().uuidString)",
            userId: userId,
            photoURL: "https://picsum.photos/seed/session-\(seed)/600/800",
            createdAt: Date(),
            note: (cleanedNote?.isEmpty ?? true) ? nil : cleanedNote,
            reactions: nil
        )
        shotsByAlbum[albumId, default: []].append(shot)
    }

    func shots(forAlbumId albumId: String) -> [Shot] {
        shotsByAlbum[albumId] ?? []
    }

    func myShotCount(forAlbumId albumId: String, userId: String) -> Int {
        shots(forAlbumId: albumId).filter { $0.userId == userId }.count
    }
}
