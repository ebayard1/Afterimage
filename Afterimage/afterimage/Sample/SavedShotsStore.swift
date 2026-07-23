import SwiftUI

/// A bookmarked shot, persisted locally on the device.
struct SavedShot: Codable, Identifiable, Hashable {
    let id: String          // the shot's id
    let photoURL: String
    let albumName: String
}

/// Observable, device-local store for shots the user has bookmarked. Persists
/// across launches via UserDefaults (JSON). Stores enough to render the SAVED
/// rail without re-fetching from Firestore.
@Observable
final class SavedShotsStore {
    static let shared = SavedShotsStore()

    private let defaultsKey = "afterimage.savedShots"
    private(set) var saved: [SavedShot]

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([SavedShot].self, from: data) {
            self.saved = decoded
        } else {
            self.saved = []
        }
    }

    func isSaved(_ id: String) -> Bool { saved.contains { $0.id == id } }

    /// Toggle a bookmark. Newest saves go to the front of the rail.
    func toggle(id: String, photoURL: String, albumName: String) {
        if isSaved(id) {
            saved.removeAll { $0.id == id }
        } else {
            saved.insert(SavedShot(id: id, photoURL: photoURL,
                                   albumName: albumName), at: 0)
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
