import Foundation

/// A display-ready reference to a person, unifying sample friends and real
/// `UserProfile`s so the friends/profile UI can render either source.
struct PersonRef: Identifiable, Hashable {
    let id: String              // uid (real) or username (sample)
    let handle: String          // with leading "@"
    let displayName: String
    let photoURL: String?       // real avatar
    let photoSeed: String?      // sample picsum seed
    var mutualAlbums: Int?
    var mutualFriends: Int?
    /// Real-mode uid for friend actions; nil for sample people.
    var uid: String?
}

extension UserProfile {
    var asPersonRef: PersonRef {
        PersonRef(id: id ?? username, handle: handle, displayName: displayName,
                  photoURL: photoURL, photoSeed: nil,
                  mutualAlbums: nil, mutualFriends: nil, uid: id)
    }
}
