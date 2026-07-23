import Foundation
import UIKit
import FirebaseFirestore
import FirebaseStorage

/// Owns the signed-in user's profile and resolves other users' profiles for
/// avatars/names across the app.
@Observable
@MainActor
final class UserService {
    /// The signed-in user's profile, or nil if they haven't created one yet.
    var currentProfile: UserProfile?
    /// True until the first snapshot of the current user's profile arrives.
    var isLoadingProfile = false

    /// uid -> profile cache for avatar/name resolution. Observed so views update
    /// as profiles stream in.
    private(set) var cache: [String: UserProfile] = [:]

    @ObservationIgnored private let db = Firestore.firestore()
    @ObservationIgnored private var profileListener: ListenerRegistration?
    @ObservationIgnored private var inFlight: Set<String> = []

    // MARK: - Current user

    func startListening(uid: String) {
        isLoadingProfile = true
        profileListener?.remove()
        profileListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoadingProfile = false
                    let profile = try? snapshot?.data(as: UserProfile.self)
                    self.currentProfile = profile
                    if let profile, let id = profile.id { self.cache[id] = profile }
                }
            }
    }

    func stopListening() {
        profileListener?.remove()
        profileListener = nil
        currentProfile = nil
        cache = [:]
        isLoadingProfile = false
    }

    var hasProfile: Bool { currentProfile != nil }

    // MARK: - Username availability + profile creation

    /// True if the handle (without "@") is free.
    func isUsernameAvailable(_ handle: String) async throws -> Bool {
        let lower = handle.lowercased()
        let doc = try await db.collection("usernames").document(lower).getDocument()
        return !doc.exists
    }

    /// Atomically claims `usernames/{lower}` and creates `users/{uid}`.
    /// Throws if the handle was taken in the meantime.
    func createProfile(uid: String, username rawHandle: String, displayName: String) async throws {
        let handle = rawHandle.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "@", with: "")
        let lower = handle.lowercased()
        let usernameRef = db.collection("usernames").document(lower)
        let userRef = db.collection("users").document(uid)
        let profile = UserProfile(
            id: uid,
            username: handle,
            usernameLower: lower,
            displayName: displayName.isEmpty ? handle : displayName,
            photoURL: nil,
            createdAt: Date(),
            friendIds: [],
            fcmTokens: []
        )

        _ = try await db.runTransaction { txn, errorPointer in
            let snap: DocumentSnapshot
            do { snap = try txn.getDocument(usernameRef) }
            catch let e as NSError { errorPointer?.pointee = e; return nil }
            if snap.exists {
                errorPointer?.pointee = NSError(
                    domain: "UserService", code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "that handle is taken"])
                return nil
            }
            do {
                try txn.setData(from: profile, forDocument: userRef)
                txn.setData(["uid": uid], forDocument: usernameRef)
            } catch let e as NSError { errorPointer?.pointee = e; return nil }
            return nil
        }
    }

    // MARK: - Resolution + search

    /// Returns a cached profile immediately if present, otherwise nil and kicks
    /// off a one-shot fetch that populates `cache` (triggering a view update).
    func profile(for uid: String) -> UserProfile? {
        if let hit = cache[uid] { return hit }
        guard !inFlight.contains(uid) else { return nil }
        inFlight.insert(uid)
        Task { @MainActor in
            defer { inFlight.remove(uid) }
            if let snap = try? await db.collection("users").document(uid).getDocument(),
               let profile = try? snap.data(as: UserProfile.self) {
                cache[uid] = profile
            }
        }
        return nil
    }

    /// Prefix search over `usernameLower` (case-insensitive). Excludes self.
    func search(prefix rawPrefix: String, excluding selfUid: String?) async throws -> [UserProfile] {
        let p = rawPrefix.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "@", with: "").lowercased()
        guard !p.isEmpty else { return [] }
        let snap = try await db.collection("users")
            .order(by: "usernameLower")
            .start(at: [p])
            .end(at: [p + "\u{f8ff}"])
            .limit(to: 20)
            .getDocuments()
        let results = snap.documents.compactMap { try? $0.data(as: UserProfile.self) }
        for r in results where r.id != nil { cache[r.id!] = r }
        return results.filter { $0.id != selfUid }
    }

    // MARK: - Avatar

    /// Uploads a profile photo to `users/{uid}/avatar.jpg`, writes the resulting
    /// URL onto the user's profile, and returns it. The live profile listener
    /// then refreshes `currentProfile.photoURL` everywhere it's shown.
    @discardableResult
    func uploadAvatar(_ image: UIImage, uid: String) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "UserService", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "couldn't encode photo"])
        }
        let ref = Storage.storage().reference(withPath: "users/\(uid)/avatar.jpg")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)
        // The avatar always lives at the same path, so overwriting it returns an
        // identical download URL — which means AsyncImage / URLCache would keep
        // serving the OLD photo. Append a cache-buster so every new upload is a
        // distinct URL and the new photo shows immediately, no restart needed.
        let base = try await ref.downloadURL().absoluteString
        let sep = base.contains("?") ? "&" : "?"
        let url = "\(base)\(sep)cb=\(Int(Date().timeIntervalSince1970))"
        try await db.collection("users").document(uid).updateData(["photoURL": url])
        return url
    }

    // MARK: - Push token

    func upsertFcmToken(_ token: String, uid: String) async {
        try? await db.collection("users").document(uid).updateData([
            "fcmTokens": FieldValue.arrayUnion([token])
        ])
    }
}
