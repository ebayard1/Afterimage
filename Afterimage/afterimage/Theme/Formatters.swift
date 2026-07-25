import Foundation

// MARK: - Shared date formatters
//
// `DateFormatter` is one of the most expensive objects in Foundation to build:
// each `init` + `dateFormat` assignment resolves the current locale, calendar
// and time zone and compiles an ICU pattern. Allocating one inside a view body
// or a computed property means paying that on every re-render — and these
// particular strings live on the roll cards, which the feed's ambient clocks
// re-evaluate many times a second (PERF_DIAGNOSIS §5.2).
//
// Hoisting them to `static let` makes construction a one-time cost per process
// and turns each call site into a plain `string(from:)`. The instances are
// MainActor-isolated by the project's default actor isolation and every caller
// is a view body, so no cross-thread sharing is involved.
//
// Formats are verbatim what the call sites used before — a formatter here is a
// cache, never a style change. Anything with a new pattern gets its own
// property rather than mutating one of these in place; a shared formatter whose
// `dateFormat` gets reassigned is the same bug wearing a different hat.
enum Formatters {
    /// "MMM d yyyy" → "JUL 25 2026" once uppercased. The DEVELOPED stamp on a
    /// revealed roll card, and the same stamp on the roll map's callouts.
    static let rollDateStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        return f
    }()

    /// "MMM d, yyyy" → the "REVEALED · JUL 25, 2026" eyebrow above an album's
    /// hero title. Comma'd variant of `rollDateStamp` — deliberately separate.
    static let albumHeroDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    /// "MMM d 'at' h:mm a" → "reveals Jul 26 at 6:04 AM" under a developing
    /// roll's countdown.
    static let revealMoment: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d 'at' h:mm a"
        return f
    }()

    /// "MMM d" → the fallback stamp on a comment older than a week, once the
    /// relative "3d" form stops being useful.
    static let commentDayStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
