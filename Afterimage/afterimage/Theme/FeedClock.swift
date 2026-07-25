import Foundation
import Observation

// MARK: - FeedClock
//
// One coarse wall clock for the whole app, instead of a timer per page.
//
// Rolls and Profile each used to run their own `Timer.publish(every: 30)` into
// a local `@State now`, and Album Detail ran a **one-second** one. Every tick
// invalidated that entire page — and the paged `TabView` keeps all three pages
// mounted at once, so both 30 s timers were always live no matter which tab you
// were looking at, each dragging a full screen of roll cards through a body
// re-evaluation (PERF_DIAGNOSIS §5.1).
//
// What that cadence is actually for is coarse: relative date math, "on this
// day", and the developing → revealed flip. None of it needs sub-minute
// resolution, and none of it needs its own timer. `ContentView` owns one of
// these and injects it; anything wanting the current-ish time reads `now`.
//
// Anything that genuinely needs seconds — the countdown on a developing roll —
// uses a `TimelineView` scoped to the one label that shows it, so the per-second
// redraw costs a `Text` rather than a screen. Do not add a faster clock here.
@Observable
final class FeedClock {
    /// Current wall-clock time, refreshed on the shared cadence below.
    private(set) var now = Date()

    /// 30 s, matching the two page tickers this replaced.
    private static let interval: TimeInterval = 30

    @ObservationIgnored private var timer: Timer?

    init() {
        // `.common` run-loop mode so the tick still lands while a scroll view is
        // tracking — the old `Timer.publish(..., in: .common)` behaviour.
        // The timer is scheduled on `RunLoop.main` below, so the callback is
        // already on the main actor — `assumeIsolated` states that rather than
        // hopping through a `Task`, which would both cost a hop per tick and
        // capture `self` across a concurrency boundary (a hard error in Swift 6).
        let t = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = Date() }
        }
        // A generous tolerance lets the system coalesce this wakeup with others
        // instead of forcing the CPU awake on its own account. Nothing reading
        // `now` cares about a few seconds either way.
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Stops the tick. There is exactly one `FeedClock`, created by
    /// `ContentView` and alive for as long as the app is, so nothing calls this
    /// today — it exists so a future owner with a shorter life can be tidy.
    /// (The timer holds `self` weakly, so a stray tick after teardown is a
    /// no-op regardless.)
    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
