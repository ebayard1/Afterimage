import SwiftUI
import Combine

/// Observable @AppStorage-backed store for shots the user has bookmarked.
/// Sample-only mode — persists across launches via UserDefaults but is purely
/// local. Each shot is identified by its stable `id` (or the sample shot id).
@Observable
final class SavedShotsStore {
    static let shared = SavedShotsStore()

    private let defaultsKey = "afterimage.savedShotIds"
    private(set) var savedShotIds: Set<String>

    private init() {
        let raw = UserDefaults.standard.array(forKey: defaultsKey) as? [String] ?? []
        self.savedShotIds = Set(raw)
    }

    func isSaved(_ id: String) -> Bool { savedShotIds.contains(id) }

    func toggle(_ id: String) {
        if savedShotIds.contains(id) {
            savedShotIds.remove(id)
        } else {
            savedShotIds.insert(id)
        }
        persist()
    }

    func save(_ id: String) {
        savedShotIds.insert(id)
        persist()
    }

    func unsave(_ id: String) {
        savedShotIds.remove(id)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(savedShotIds), forKey: defaultsKey)
    }
}
