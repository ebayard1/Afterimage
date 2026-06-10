import Foundation

/// MVP: reveal at local 7:00 AM `daysFromNow` days from now.
/// Real per-location sunrise calc can replace this later — the user-facing concept is "morning reveal".
enum SunriseCalculator {
    static func nextSunrise(daysFromNow: Int) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let target = calendar.date(byAdding: .day, value: daysFromNow, to: now) ?? now
        var components = calendar.dateComponents([.year, .month, .day], from: target)
        components.hour = 7
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? target
    }
}
