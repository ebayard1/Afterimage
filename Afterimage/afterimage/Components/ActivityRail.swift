import SwiftUI

/// Horizontal "newsstand ticker" of friend activity that sits between the
/// Rolls feed header and the developing section. Driven by the live activity
/// feed passed in as `events`.
struct ActivityRail: View {
    let events: [ActivityEvent]
    var onTapEvent: (ActivityEvent) -> Void = { _ in }

    /// Newsstand-ticker pan speed, points per second. Slow — a drift, not a scroll.
    private let panSpeed: Double = 22
    /// Measured width of one full row of chips (single copy).
    @State private var rowWidth: CGFloat = 0
    /// Measured width of the rail itself.
    @State private var containerWidth: CGFloat = 0

    @Environment(\.ambientMotionPaused) private var ambientPaused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            wire
        }
        .padding(.vertical, 10)
        .background(Palette.surface.opacity(0.4))
        .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { containerWidth = g.size.width }
                    .onChange(of: g.size.width) { _, w in containerWidth = w }
            }
        )
    }

    /// The ticker itself. When the chips overflow the rail it pans slowly and
    /// continuously (looping seamlessly via a doubled row); when they fit, it
    /// just sits still. The pan phase is derived from the wall clock, so data
    /// refreshes never make it jump — chips keep drifting from wherever they are.
    ///
    /// Two nested clocks, deliberately: a one-per-minute clock that owns the
    /// *content*, and a 24 Hz clock inside it that owns only the *offset*.
    @ViewBuilder
    private var wire: some View {
        // Minute clock. Chips print live relative timestamps ("2m") computed
        // against `now`, and nothing else re-evaluates them: making `ChipRows`
        // Equatable is what stopped the 24 Hz clock from re-diffing the avatar
        // trees, and it also stopped the stamps from ever advancing — a chip
        // reading "2m" would still read "2m" an hour later, on the one element
        // that exists to prove the app is live. So the bucket is driven from
        // here instead of from `wire`'s enclosing body.
        //
        // The cost is one wakeup a minute. It stays gated on `ambientPaused` —
        // a rail nobody can see does not need fresh timestamps, and it re-reads
        // the wall clock on resume, so it cannot drift.
        //
        // Deliberately NOT OR'd with `accessibilityReduceMotion`, unlike the pan
        // clock nested below — this clock carries information, not decoration.
        // Reduce Motion should stop the chips from sliding; it should not freeze
        // what they say, or a chip would still read "2m" an hour later on the
        // one element whose entire job is to show the app is live. Same
        // reasoning as `DevelopingCountdown` in `AlbumDetailView`.
        //
        // It does NOT reintroduce per-tick chip work — the 24 Hz clock is
        // nested *inside* this one, so `ChipRows` is still constructed at most
        // once a minute and still diffed by `==`. `TimelineView` is
        // layout-transparent, so wrapping both branches changes no geometry.
        TimelineView(.animation(minimumInterval: 60,
                                paused: ambientPaused)) { minuteCtx in
            let minuteBucket = Int(minuteCtx.date.timeIntervalSinceReferenceDate / 60)

            if rowWidth > containerWidth, containerWidth > 0 {
                // The chip rows are built ONCE, OUTSIDE the pan clock. Each chip
                // owns an AsyncImage, so re-evaluating the doubled row per tick
                // meant re-diffing two full avatar trees 30×/sec for an
                // animation that only ever changes an x-offset. `EquatableView`
                // compares the event list plus the minute bucket and returns the
                // same rendered subtree, so a pan tick applies a transform and
                // nothing else.
                let rows = ChipRows(
                    events: events,
                    doubled: true,
                    minuteBucket: minuteBucket,
                    onTap: onTapEvent,
                    onRowWidth: { rowWidth = $0 }
                )
                .equatable()

                // 24 Hz: the drift is 22 pt/sec, so a tick moves it just under a
                // point — below the visible step for a continuous pan, and a fifth
                // fewer wakeups than the 30 Hz this ran at. Paused when the Rolls
                // page isn't the one on screen, or when the rail has scrolled off.
                TimelineView(.animation(minimumInterval: 1.0 / 24.0,
                                        paused: ambientPaused || reduceMotion)) { ctx in
                    let span = rowWidth + 8
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let offset = -CGFloat((t * panSpeed).truncatingRemainder(dividingBy: Double(span)))
                    rows.offset(x: offset)
                }
                .frame(width: max(containerWidth, 1), alignment: .leading)
                .clipped()
            } else {
                ChipRows(
                    events: events,
                    doubled: false,
                    minuteBucket: minuteBucket,
                    onTap: onTapEvent,
                    onRowWidth: { rowWidth = $0 }
                )
                .equatable()
                .padding(.horizontal, 16)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            PulsingDot(color: Palette.gold, size: 5)
            Text("ON THE WIRE")
                .font(.custom("Bebas Neue", size: 11)).tracking(4)
                .foregroundStyle(Palette.gold)
            Text("·  live")
                .font(.custom("Times New Roman", size: 11)).italic()
                .foregroundStyle(Palette.textTertiary)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - ChipRows
    //
    // The marquee's content, split out of the `TimelineView` closure and made
    // `Equatable` so the clock can no longer force it to re-evaluate. Its
    // stored state is only the data the chips render from; the two closures
    // are intentionally excluded from `==` (they are stable for the lifetime
    // of the rail — HomeView passes the default no-op tap handler and a
    // `@State` writer whose storage identity never changes).
    private struct ChipRows: View, Equatable {
        let events: [ActivityEvent]
        /// Marquee mode draws the row twice so the loop is seamless: the pan
        /// wraps at `rowWidth + 8` with the second copy already in place.
        let doubled: Bool
        /// Coarse wall-clock bucket, ticked once a minute by the outer clock in
        /// `wire`. `ActivityEvent.relativeTime` is computed against `now`, so
        /// equality has to change on a timer or the "2m" stamps freeze — this
        /// is the only thing that advances them now that the pan clock can't.
        let minuteBucket: Int
        let onTap: (ActivityEvent) -> Void
        /// Reports the width of ONE row so the rail can compute the loop span.
        let onRowWidth: (CGFloat) -> Void

        // Compares the events by value rather than by `id`: `id` is a computed
        // string interpolation, and building it per event per tick would cost
        // more than the diff it saves. The stored properties it interpolates
        // are exactly what the synthesized `==` compares.
        static func == (a: ChipRows, b: ChipRows) -> Bool {
            a.doubled == b.doubled
                && a.minuteBucket == b.minuteBucket
                && a.events == b.events
        }

        @ViewBuilder
        var body: some View {
            if doubled {
                HStack(spacing: 8) {
                    row(measured: true)
                    row(measured: false)
                }
            } else {
                // Bare single row — no wrapper, so the non-overflowing layout
                // is byte-for-byte what it was before the split.
                row(measured: true)
            }
        }

        /// One row of chips. `measured: true` reports its width for the marquee math.
        private func row(measured: Bool) -> some View {
            HStack(spacing: 8) {
                ForEach(events) { ev in
                    chip(ev)
                }
            }
            .background(
                Group {
                    if measured {
                        GeometryReader { g in
                            Color.clear
                                .onAppear { onRowWidth(g.size.width) }
                                .onChange(of: g.size.width) { _, w in onRowWidth(w) }
                        }
                    }
                }
            )
        }

        /// Prefer a real avatar URL; fall back to the picsum seed for sample mode.
        private func avatarURL(_ ev: ActivityEvent) -> URL? {
            if let urlStr = ev.actorPhotoURL, !urlStr.isEmpty { return URL(string: urlStr) }
            return URL(string: "https://picsum.photos/seed/\(ev.actorPhotoSeed)/80/80")
        }

        private func chip(_ ev: ActivityEvent) -> some View {
            Button { onTap(ev) } label: {
                HStack(spacing: 9) {
                    AsyncImage(url: avatarURL(ev)) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: ShimmerPlaceholder()
                        }
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Palette.border, lineWidth: 1))
                    .overlay(
                        Image(systemName: ev.iconName)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 12, height: 12)
                            .background(Palette.gold)
                            .clipShape(Circle())
                            .offset(x: 10, y: 10)
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(ev.actorUsername)
                                .font(.custom("Bebas Neue", size: 11)).tracking(1)
                                .foregroundStyle(Palette.gold)
                            Text(ev.headline)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                        }
                        HStack(spacing: 4) {
                            if let albumName = ev.albumName {
                                Text(albumName.uppercased())
                                    .font(.custom("Bebas Neue", size: 10)).tracking(1.5)
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(1)
                            }
                            if let detail = ev.detail {
                                Text("· \(detail)")
                                    .font(.custom("Times New Roman", size: 10)).italic()
                                    .foregroundStyle(Palette.textTertiary)
                                    .lineLimit(1)
                            }
                            Text("· \(ev.relativeTime)")
                                .font(.custom("Menlo", size: 9)).tracking(0.5)
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Palette.surface)
                .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .pressEffect()
            .accessibilityLabel("\(ev.actorUsername) \(ev.headline) \(ev.albumName ?? "")")
        }
    }
}
