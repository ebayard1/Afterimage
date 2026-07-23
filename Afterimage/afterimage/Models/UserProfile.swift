import Foundation
import FirebaseFirestore

/// A real signed-in user's public profile (Firestore `users/{uid}`).
///
/// The handle is stored WITHOUT the leading "@" (e.g. "sam_k"); the UI adds the
/// "@" for display. `usernameLower` is the lowercased handle, used both as the
/// key in the `usernames/{handle}` uniqueness collection and for prefix search.
struct UserProfile: Identifiable, Codable, Hashable {
    @DocumentID var id: String?          // firebase uid
    var username: String                 // handle without "@", e.g. "sam_k"
    var usernameLower: String
    var displayName: String
    var photoURL: String?
    var createdAt: Date
    var friendIds: [String] = []
    var fcmTokens: [String] = []

    /// Display handle with the leading "@".
    var handle: String { "@\(username)" }

    /// Initials for the monogram fallback avatar.
    var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? username.prefix(1).uppercased() : s
    }
}
