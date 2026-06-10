import Foundation

/// Sample data injected throughout the app so it feels populated without a friend list.
/// Photos come from picsum.photos with seeded URLs so they're stable.
enum SampleData {
    static let samplePrefix = "sample-"

    // MARK: - Friends & users

    struct SampleFriend: Identifiable, Hashable {
        var id: String { username }
        let username: String        // e.g. "@sam_k"
        let displayName: String     // "Sam Kim"
        let mutualAlbums: Int
        let mutualFriends: Int
        let photoSeed: String
    }

    static let friends: [SampleFriend] = [
        .init(username: "@sam_k",   displayName: "Sam Kim",      mutualAlbums: 3, mutualFriends: 7, photoSeed: "sam"),
        .init(username: "@leo",     displayName: "Leo Park",     mutualAlbums: 4, mutualFriends: 9, photoSeed: "leo"),
        .init(username: "@maya",    displayName: "Maya Sato",    mutualAlbums: 5, mutualFriends: 8, photoSeed: "maya"),
        .init(username: "@jake",    displayName: "Jake Riley",   mutualAlbums: 2, mutualFriends: 5, photoSeed: "jake"),
        .init(username: "@kim",     displayName: "Kim Tran",     mutualAlbums: 1, mutualFriends: 4, photoSeed: "kim"),
        .init(username: "@riley",   displayName: "Riley Wu",     mutualAlbums: 1, mutualFriends: 3, photoSeed: "riley"),
        .init(username: "@nora",    displayName: "Nora Hale",    mutualAlbums: 2, mutualFriends: 6, photoSeed: "nora"),
        .init(username: "@ben",     displayName: "Ben Cole",     mutualAlbums: 3, mutualFriends: 4, photoSeed: "ben"),
        .init(username: "@maddie",  displayName: "Maddie Frost", mutualAlbums: 5, mutualFriends: 10, photoSeed: "maddie"),
        .init(username: "@tyler",   displayName: "Tyler Vance",  mutualAlbums: 4, mutualFriends: 8, photoSeed: "tyler"),
        .init(username: "@soph",    displayName: "Soph Reyes",   mutualAlbums: 4, mutualFriends: 9, photoSeed: "soph"),
    ]

    struct FriendRequest: Identifiable, Hashable {
        var id: String { username }
        let username: String
        let displayName: String
        let mutualNote: String
        let photoSeed: String
    }

    static let friendRequests: [FriendRequest] = [
        .init(username: "@alex_chen", displayName: "Alex Chen",  mutualNote: "3 mutual friends", photoSeed: "alex"),
        .init(username: "@bella_r",   displayName: "Bella R.",   mutualNote: "1 mutual album",  photoSeed: "bella"),
    ]

    // MARK: - Notifications

    enum NotificationKind { case revealReady, countdown, invite, friendRequest, reaction }

    struct AppNotification: Identifiable, Hashable {
        let id: String
        let kind: NotificationKind
        let title: String
        let subtitle: String
        let timeAgo: String
        let icon: String
    }

    static let notifications: [AppNotification] = [
        .init(id: "n1", kind: .revealReady,   title: "Sam's Birthday is ready!",   subtitle: "14 shots · 4 people · reveals first (most present)", timeAgo: "now", icon: "film.fill"),
        .init(id: "n2", kind: .countdown,     title: "Road Trip develops in 2h",   subtitle: "Last chance to add shots.",                          timeAgo: "2h",  icon: "clock.fill"),
        .init(id: "n3", kind: .invite,        title: "@leo invited you to 'Camping'", subtitle: "24 shots · 2 day window",                         timeAgo: "5h",  icon: "rectangle.stack.fill"),
        .init(id: "n4", kind: .reaction,      title: "@maya reacted ❤️ on your shot", subtitle: "From 'NYE 2025'",                                  timeAgo: "1d",  icon: "heart.fill"),
        .init(id: "n5", kind: .revealReady,   title: "NYE 2025 is ready!",         subtitle: "24 shots developed.",                                timeAgo: "3d",  icon: "film.fill"),
        .init(id: "n6", kind: .countdown,     title: "Beach Day develops tomorrow", subtitle: "12h until sunrise.",                                timeAgo: "4d",  icon: "clock.fill"),
    ]

    // MARK: - Albums

    /// Build a sample album with sample shots.
    /// `daysFromNow` < 0 means already revealed in the past.
    private static func makeAlbum(
        id: String, name: String, durationDays: Int, daysFromNow: Int,
        members: [String], shotSeeds: [(seed: String, by: String, note: String?, reactions: [String: Int]?)]
    ) -> Album {
        let calendar = Calendar.current
        let now = Date()
        let revealAt = calendar.date(byAdding: .hour, value: daysFromNow * 24, to: now) ?? now
        let createdAt = calendar.date(byAdding: .day, value: -durationDays + daysFromNow, to: now) ?? now
        let cover = shotSeeds.first.map { url(forSeed: $0.seed) }
        return Album(
            id: id,
            name: name,
            creatorId: members.first ?? "me",
            memberIds: members,
            createdAt: createdAt,
            revealAt: revealAt,
            durationDays: durationDays,
            coverPhotoURL: cover
        )
    }

    static func url(forSeed seed: String) -> String {
        "https://picsum.photos/seed/\(seed)/600/800"
    }

    /// Stable sample albums; the creator/member IDs are placeholders since they're not used to filter.
    static var albums: [Album] {
        [
            makeAlbum(
                id: "\(samplePrefix)sams-bday",
                name: "Sam's Birthday",
                durationDays: 2,
                daysFromNow: -1,                        // revealed yesterday
                members: ["me", "sam-uid", "leo-uid", "maya-uid"],
                shotSeeds: [
                    ("sams-bday-01", "sam-uid", "rooftop moment 🌙", ["❤️": 4, "🔥": 2]),
                    ("sams-bday-02", "leo-uid", nil, ["❤️": 2]),
                    ("sams-bday-03", "maya-uid", "the cake destruction", ["😂": 5, "🔥": 1]),
                    ("sams-bday-04", "me",       nil, ["❤️": 1]),
                    ("sams-bday-05", "sam-uid",  "the toast", ["👏": 3]),
                    ("sams-bday-06", "leo-uid",  nil, nil),
                    ("sams-bday-07", "maya-uid", "blurry but worth it", ["😂": 2]),
                    ("sams-bday-08", "me",       "happy 25 @sam", ["❤️": 6]),
                    ("sams-bday-09", "sam-uid",  nil, nil),
                    ("sams-bday-10", "leo-uid",  "after-party", ["🔥": 4]),
                    ("sams-bday-11", "maya-uid", nil, ["❤️": 1]),
                    ("sams-bday-12", "me",       nil, nil),
                    ("sams-bday-13", "sam-uid",  "the last one", ["😢": 2, "❤️": 3]),
                    ("sams-bday-14", "leo-uid",  nil, nil),
                ]
            ),
            makeAlbum(
                id: "\(samplePrefix)road-trip",
                name: "Road Trip",
                durationDays: 5,
                daysFromNow: 2,                         // developing, 2 days left
                members: ["me", "jake-uid", "kim-uid"],
                shotSeeds: [
                    ("road-trip-01", "me", "first stop", nil),
                    ("road-trip-02", "jake-uid", nil, nil),
                    ("road-trip-03", "kim-uid", "the diner", nil),
                    ("road-trip-04", "me", nil, nil),
                    ("road-trip-05", "jake-uid", "sunset over the dunes", nil),
                    ("road-trip-06", "kim-uid", nil, nil),
                ]
            ),
            makeAlbum(
                id: "\(samplePrefix)nye-2025",
                name: "NYE 2025",
                durationDays: 1,
                daysFromNow: -180,                      // long past
                members: ["me", "sam-uid", "leo-uid", "maya-uid", "ben-uid"],
                shotSeeds: (1...24).map { i in
                    ("nye-\(i)", ["me","sam-uid","leo-uid","maya-uid","ben-uid"].randomElement()!,
                     [nil, "before midnight", "kiss at midnight", nil, "the after"].randomElement() ?? nil,
                     i % 3 == 0 ? ["❤️": Int.random(in: 1...5)] : nil)
                }
            ),
            makeAlbum(
                id: "\(samplePrefix)beach-day",
                name: "Beach Day",
                durationDays: 1,
                daysFromNow: 0,                         // reveals later today
                members: ["me", "nora-uid", "ben-uid"],
                shotSeeds: [
                    ("beach-01", "nora-uid", nil, nil),
                    ("beach-02", "me", "tide coming in", nil),
                    ("beach-03", "ben-uid", nil, nil),
                ]
            ),
            makeAlbum(
                id: "\(samplePrefix)festival",
                name: "Festival",
                durationDays: 2,
                daysFromNow: -30,
                members: ["me", "riley-uid", "kim-uid", "jake-uid"],
                shotSeeds: (1...18).map { i in
                    ("festival-\(i)", ["me","riley-uid","kim-uid","jake-uid"].randomElement()!,
                     [nil, "main stage", "ferris wheel", nil].randomElement() ?? nil,
                     i % 4 == 0 ? ["🔥": Int.random(in: 2...8)] : nil)
                }
            ),
            makeAlbum(
                id: "\(samplePrefix)concert",
                name: "Concert",
                durationDays: 1,
                daysFromNow: 1,                         // tomorrow
                members: ["me", "leo-uid"],
                shotSeeds: [
                    ("concert-01", "leo-uid", nil, nil),
                    ("concert-02", "me", "front row", nil),
                ]
            ),
            makeAlbum(
                id: "\(samplePrefix)spring-escape",
                name: "Spring Escape",
                durationDays: 2,
                daysFromNow: -3,
                members: ["me", "maddie-uid", "tyler-uid", "jake-uid", "soph-uid"],
                shotSeeds: (1...9).map { i in
                    ("spring-\(i)", ["me","maddie-uid","tyler-uid","jake-uid","soph-uid"][i % 5],
                     [nil, "magic hour", "the lake", nil, "lights", nil, "balloons", nil, "those views"][i % 9],
                     nil)
                }
            ),
        ]
    }

    /// Shots for a given sample album id.
    static func shots(forAlbumId albumId: String) -> [Shot] {
        guard let album = albums.first(where: { $0.id == albumId }) else { return [] }
        // Re-derive shot seeds by name (the makeAlbum metadata stays here).
        let seeds = shotSeeds(forAlbumName: album.name)
        return seeds.enumerated().map { (i, s) in
            Shot(
                id: "\(albumId)-shot-\(i)",
                userId: s.by,
                photoURL: url(forSeed: s.seed),
                createdAt: Calendar.current.date(byAdding: .minute, value: -i * 7, to: Date()) ?? Date(),
                note: s.note,
                reactions: s.reactions?.mapValues { count in (0..<count).map { "sample-user-\($0)" } }
            )
        }
    }

    private struct ShotSeed { let seed: String; let by: String; let note: String?; let reactions: [String: Int]? }

    private static func shotSeeds(forAlbumName name: String) -> [(seed: String, by: String, note: String?, reactions: [String: Int]?)] {
        switch name {
        case "Sam's Birthday":
            return [
                ("sams-bday-01", "sam-uid", "rooftop moment 🌙", ["❤️": 4, "🔥": 2]),
                ("sams-bday-02", "leo-uid", nil, ["❤️": 2]),
                ("sams-bday-03", "maya-uid", "the cake destruction", ["😂": 5, "🔥": 1]),
                ("sams-bday-04", "me", nil, ["❤️": 1]),
                ("sams-bday-05", "sam-uid", "the toast", ["👏": 3]),
                ("sams-bday-06", "leo-uid", nil, nil),
                ("sams-bday-07", "maya-uid", "blurry but worth it", ["😂": 2]),
                ("sams-bday-08", "me", "happy 25 @sam", ["❤️": 6]),
                ("sams-bday-09", "sam-uid", nil, nil),
                ("sams-bday-10", "leo-uid", "after-party", ["🔥": 4]),
                ("sams-bday-11", "maya-uid", nil, ["❤️": 1]),
                ("sams-bday-12", "me", nil, nil),
                ("sams-bday-13", "sam-uid", "the last one", ["😢": 2, "❤️": 3]),
                ("sams-bday-14", "leo-uid", nil, nil),
            ]
        case "Road Trip":
            return [
                ("road-trip-01", "me", "first stop", nil),
                ("road-trip-02", "jake-uid", nil, nil),
                ("road-trip-03", "kim-uid", "the diner", nil),
                ("road-trip-04", "me", nil, nil),
                ("road-trip-05", "jake-uid", "sunset over the dunes", nil),
                ("road-trip-06", "kim-uid", nil, nil),
            ]
        case "NYE 2025":
            return (1...24).map { i in
                ("nye-\(i)", ["me","sam-uid","leo-uid","maya-uid","ben-uid"][i % 5],
                 [nil, "before midnight", "kiss at midnight", nil, "the after"][i % 5],
                 i % 3 == 0 ? ["❤️": (i % 5) + 1] : nil)
            }
        case "Beach Day":
            return [
                ("beach-01", "nora-uid", nil, nil),
                ("beach-02", "me", "tide coming in", nil),
                ("beach-03", "ben-uid", nil, nil),
            ]
        case "Festival":
            return (1...18).map { i in
                ("festival-\(i)", ["me","riley-uid","kim-uid","jake-uid"][i % 4],
                 [nil, "main stage", "ferris wheel", nil][i % 4],
                 i % 4 == 0 ? ["🔥": (i % 7) + 2] : nil)
            }
        case "Concert":
            return [
                ("concert-01", "leo-uid", nil, nil),
                ("concert-02", "me", "front row", nil),
            ]
        case "Spring Escape":
            return (1...9).map { i in
                ("spring-\(i)", ["me","maddie-uid","tyler-uid","jake-uid","soph-uid"][i % 5],
                 [nil, "magic hour", "the lake", nil, "lights", nil, "balloons", nil, "those views"][i % 9],
                 nil)
            }
        default: return []
        }
    }
}

extension Album {
    var isSample: Bool { id?.hasPrefix(SampleData.samplePrefix) ?? false }
}

extension SampleData {
    /// Where a sample roll was shot — surfaces as a small chip on the album card.
    static func location(forAlbumId id: String) -> String? {
        switch id {
        case "\(samplePrefix)sams-bday":      return "Brooklyn, NY"
        case "\(samplePrefix)road-trip":      return "Big Sur, CA"
        case "\(samplePrefix)nye-2025":       return "Chicago, IL"
        case "\(samplePrefix)beach-day":      return "Rockaway Beach, NY"
        case "\(samplePrefix)festival":       return "Austin, TX"
        case "\(samplePrefix)concert":        return "Madison Square Garden"
        case "\(samplePrefix)spring-escape":  return "Sedona, AZ"
        default: return nil
        }
    }

    /// Shots from other people's rolls where you appear — sample curation.
    /// Used by the Profile "You appear in" rail.
    static var youAppearInShots: [(albumName: String, shot: Shot)] {
        var out: [(String, Shot)] = []
        for albumId in [
            "\(samplePrefix)sams-bday", "\(samplePrefix)nye-2025",
            "\(samplePrefix)festival", "\(samplePrefix)spring-escape"
        ] {
            let s = shots(forAlbumId: albumId)
            let picks = s.filter { $0.userId != "me" }.prefix(2)
            let name = albums.first(where: { $0.id == albumId })?.name ?? ""
            for shot in picks { out.append((name, shot)) }
        }
        return out
    }

    /// Translates an album memberId like "sam-uid" into a picsum seed ("sam")
    /// so we can pull a stable avatar image. Returns nil for "me" or unknown UIDs.
    static func avatarSeed(forMemberId uid: String) -> String? {
        if uid == "me" { return nil }
        let stripped = uid.replacingOccurrences(of: "-uid", with: "")
        // Only return seeds we know correspond to sample friends.
        if friends.contains(where: { $0.photoSeed == stripped }) {
            return stripped
        }
        return nil
    }

    /// Resolves a memberId back to a SampleFriend when possible.
    static func friend(forMemberId uid: String) -> SampleFriend? {
        let stripped = uid.replacingOccurrences(of: "-uid", with: "")
        return friends.first(where: { $0.photoSeed == stripped })
    }

    /// Resolves a username (e.g. "@sam_k") to a SampleFriend.
    static func friend(byUsername username: String) -> SampleFriend? {
        friends.first(where: { $0.username == username })
    }

    /// Used when a real (user-created) album has zero shots yet — populates the
    /// detail view with deterministic placeholder shots so the album doesn't feel empty.
    static func demoShots(forAlbumId albumId: String, count: Int = 9) -> [Shot] {
        let seed = String(albumId.prefix(8))
        let notes: [String?] = ["the golden hour", nil, "best of the night", nil, "blurry but real", nil, "the candid", nil, "1am energy"]
        let reactions: [[String: Int]?] = [["❤️": 3], nil, ["🔥": 2, "❤️": 1], nil, ["😂": 4], nil, ["❤️": 5], nil, ["👏": 2]]
        return (0..<count).map { i in
            Shot(
                id: "demo-\(albumId)-\(i)",
                userId: ["me", "sample-friend-1", "sample-friend-2", "sample-friend-3"][i % 4],
                photoURL: url(forSeed: "\(seed)-demo-\(i)"),
                createdAt: Calendar.current.date(byAdding: .minute, value: -i * 12, to: Date()) ?? Date(),
                note: notes[i % notes.count],
                reactions: reactions[i % reactions.count]?.mapValues { c in (0..<c).map { "u-\($0)" } }
            )
        }
    }

    /// Canned comment threads per sample album. Stable so the UI looks alive
    /// even before any user types anything.
    static func comments(forAlbumId albumId: String) -> [Comment] {
        let shots = shots(forAlbumId: albumId)
        // Reference some shots by id so tapping the comment can jump to that frame.
        func shotId(_ idx: Int) -> String? {
            guard idx >= 0 && idx < shots.count else { return nil }
            return shots[idx].id
        }
        let now = Date()
        func when(_ minsAgo: Int) -> Date { now.addingTimeInterval(TimeInterval(-minsAgo * 60)) }

        switch albumId {
        case "\(samplePrefix)sams-bday":
            return [
                Comment(id: "c1", userId: "sam-uid", username: "@sam_k",
                        text: "okay how did everyone shoot SO well in the dark",
                        createdAt: when(38), referencedShotId: nil),
                Comment(id: "c2", userId: "leo-uid", username: "@leo",
                        text: "this one is unreal, @maya you NAILED it",
                        createdAt: when(32), referencedShotId: shotId(0)),
                Comment(id: "c3", userId: "maya-uid", username: "@maya",
                        text: "i can't stop laughing at the cake one",
                        createdAt: when(28), referencedShotId: shotId(2)),
                Comment(id: "c4", userId: "nora-uid", username: "@nora",
                        text: "wait i need to be invited next time",
                        createdAt: when(20), referencedShotId: nil),
                Comment(id: "c5", userId: "me", username: "@you",
                        text: "the toast moment still gets me every time",
                        createdAt: when(8), referencedShotId: shotId(4)),
                Comment(id: "c6", userId: "sam-uid", username: "@sam_k",
                        text: "best birthday i've had. period.",
                        createdAt: when(4), referencedShotId: nil),
            ]
        case "\(samplePrefix)nye-2025":
            return [
                Comment(id: "n1", userId: "ben-uid", username: "@ben",
                        text: "the midnight one is so good",
                        createdAt: when(720), referencedShotId: shotId(11)),
                Comment(id: "n2", userId: "leo-uid", username: "@leo",
                        text: "we have to do this every year",
                        createdAt: when(600), referencedShotId: nil),
                Comment(id: "n3", userId: "maya-uid", username: "@maya",
                        text: "lol my hair",
                        createdAt: when(420), referencedShotId: shotId(7)),
                Comment(id: "n4", userId: "me", username: "@you",
                        text: "blurry but iconic",
                        createdAt: when(200), referencedShotId: shotId(3)),
                Comment(id: "n5", userId: "sam-uid", username: "@sam_k",
                        text: "calling it now: most-replayed album of 2026",
                        createdAt: when(60), referencedShotId: nil),
            ]
        case "\(samplePrefix)spring-escape":
            let maddie = Comment(id: "se1", userId: "maddie-uid", username: "@maddie",
                                 text: "this weekend was so special 🤍",
                                 createdAt: when(2), referencedShotId: nil,
                                 parentId: nil, likedBy: Array(repeating: "u", count: 12))
            let tyler  = Comment(id: "se2", userId: "tyler-uid", username: "@tyler",
                                 text: "those views 😍",
                                 createdAt: when(1), referencedShotId: shotId(2),
                                 parentId: "se1", likedBy: ["u1", "u2"])
            let maddie2 = Comment(id: "se3", userId: "maddie-uid", username: "@maddie",
                                  text: "@tyler right?! already planning the next one",
                                  createdAt: when(1), referencedShotId: nil,
                                  parentId: "se1", likedBy: ["u1"])
            let jake   = Comment(id: "se4", userId: "jake-uid", username: "@jake",
                                 text: "can't believe we made it to that lake before sunset. magic hour hit different",
                                 createdAt: when(0), referencedShotId: shotId(1),
                                 parentId: nil, likedBy: Array(repeating: "u", count: 7))
            let soph   = Comment(id: "se5", userId: "soph-uid", username: "@soph",
                                 text: "the best kind of day with the best people ❤️",
                                 createdAt: now.addingTimeInterval(-30),
                                 referencedShotId: nil, parentId: nil,
                                 likedBy: ["u1", "u2", "u3"])
            return [maddie, tyler, maddie2, jake, soph]
        case "\(samplePrefix)festival":
            return [
                Comment(id: "f1", userId: "riley-uid", username: "@riley",
                        text: "main stage shot >>>",
                        createdAt: when(900), referencedShotId: shotId(2)),
                Comment(id: "f2", userId: "jake-uid", username: "@jake",
                        text: "still mad we didn't get a ferris wheel one",
                        createdAt: when(800), referencedShotId: nil),
                Comment(id: "f3", userId: "kim-uid", username: "@kim",
                        text: "@jake there literally is one????",
                        createdAt: when(780), referencedShotId: shotId(6)),
                Comment(id: "f4", userId: "me", username: "@you",
                        text: "this album feels like a movie",
                        createdAt: when(120), referencedShotId: nil),
            ]
        default:
            return []
        }
    }

    /// Sample face tags layered on top of photos in the viewer. Stable per shot id.
    struct FaceTag: Identifiable, Hashable {
        let id = UUID()
        let username: String
        let x: CGFloat       // 0..1 normalized
        let y: CGFloat       // 0..1
        let width: CGFloat   // 0..1
        let height: CGFloat  // 0..1
    }

    static func faceTags(forShotId shotId: String) -> [FaceTag] {
        // Deterministic by hash, but only for some shots.
        let h = abs(shotId.hashValue)
        guard h % 3 == 0 else { return [] }
        let pool = ["@sam", "@leo", "@maya", "@jake", "@kim", "@riley", "@nora", "@ben"]
        let count = (h % 2) + 1
        return (0..<count).map { i in
            let seed = h &+ i &* 17
            let x = CGFloat((seed % 60) + 15) / 100.0       // 0.15..0.75
            let y = CGFloat(((seed / 60) % 50) + 20) / 100.0 // 0.20..0.70
            return FaceTag(
                username: pool[(seed / 7) % pool.count],
                x: x, y: y,
                width: 0.22, height: 0.30
            )
        }
    }
}
