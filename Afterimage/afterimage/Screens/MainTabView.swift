import SwiftUI

// MARK: - MainTabView
//
// The three main pages (Rolls · Camera · Profile) in a PAGED TabView, so you
// can swipe horizontally between them as well as tap. The system tab bar is
// replaced by a compact custom bar — icons only, ~40pt tall — inset via
// `safeAreaInset` so every page (critically the camera, whose shell artwork
// needs every point of height) lays out inside the space above it.

struct MainTabView: View {
    enum Tab: Int, Hashable, CaseIterable { case rolls, camera, profile }
    @State private var selectedTab: Tab = .rolls
    // A paged TabView mounts ALL three pages at once and never removes the
    // offscreen ones, so the camera page's `onDisappear` never fires. Without
    // an explicit signal the 1080p capture session would keep running while
    // you browse the feed — the single largest source of device heat in the
    // app. `isActive` is that signal: the camera only runs when it is the
    // selected page AND the app is foregrounded.
    //
    // The same mounting behaviour keeps every page's ambient `TimelineView`
    // clocks ticking on pages you aren't looking at, so each page is also
    // handed `ambientMotionPaused` on exactly the same condition. See
    // `AmbientMotion.swift`.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            // The camera shell is width-fit and top-anchored, so its bottom
            // edge lands at width × (1740/904). Size the tab bar to fill the
            // whole zone from the shell's bottom edge to the home-indicator
            // area — the menu "touches" the camera on every device width.
            let fullHeight = geo.size.height + topInset + geo.safeAreaInsets.bottom
            let shellBottom = geo.size.width * (1740.0 / 904.0)
            let barHeight = max(56, fullHeight - shellBottom - geo.safeAreaInsets.bottom)
            TabView(selection: $selectedTab) {
                HomeView()
                    .safeAreaPadding(.top, topInset)
                    .environment(\.ambientMotionPaused,
                                 selectedTab != .rolls || scenePhase != .active)
                    .tag(Tab.rolls)

                CameraTabView(isActive: selectedTab == .camera && scenePhase == .active)
                    // Gates the counter badge's warmthFlicker and the
                    // FlashReadyLED, which otherwise pulse behind the feed.
                    .environment(\.ambientMotionPaused,
                                 selectedTab != .camera || scenePhase != .active)
                    .tag(Tab.camera)

                ProfileView()
                    .safeAreaPadding(.top, topInset)
                    .environment(\.ambientMotionPaused,
                                 selectedTab != .profile || scenePhase != .active)
                    .tag(Tab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // The pager itself runs to the very top of the screen so the camera
            // shell can touch the physical top edge — ignoring the safe area on
            // a page INSIDE the pager doesn't extend it. Rolls and Profile get
            // the inset handed back via safeAreaPadding above, so they lay out
            // exactly as before; only the camera actually goes under the island.
            .ignoresSafeArea(edges: .top)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .safeAreaInset(edge: .bottom, spacing: 0) { compactBar(height: barHeight) }
            // On the camera page the whole screen IS the device — hide the
            // system status bar (clock / battery / signal) so nothing floats
            // over the shell. Rolls and Profile keep it.
            .statusBarHidden(selectedTab == .camera)
            // Measure the window height ONCE, here, and publish it. Scroll-
            // position effects downstream (the sealed-negative reveal) need it
            // to normalize a card's midY; measuring per card is the thing that
            // broke the strip before. See `ScrollGeometry.swift`.
            .environment(\.viewportHeight, fullHeight)
            .onChange(of: selectedTab) { _, _ in
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    // MARK: Compact bar — icons only, minimal height, out of the shell's way.
    // A floating Liquid Glass capsule rather than an opaque edge-to-edge bar.
    // Pulled DOWN into the home-indicator margin so it clears the (zoomed) shell
    // artwork — the glass then floats over the background, not over the leather.

    private func compactBar(height: CGFloat) -> some View {
        // Bare floating icons — no glass, no pill. Over the app's near-black
        // surfaces the glass capsule just read as a flat grey rectangle, so
        // the bar is now only the three icons. The height is computed by the
        // caller so the bar's top edge meets the camera shell's bottom edge.
        HStack {
            barButton(.rolls, icon: "film.stack.fill", label: "Rolls")
            barButton(.camera, icon: "camera.fill", label: "Camera")
            barButton(.profile, icon: "person.crop.circle.fill", label: "Profile")
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 64)
    }

    private func barButton(_ tab: Tab, icon: String, label: String) -> some View {
        Button {
            withAnimation(Motion.crisp) { selectedTab = tab }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(selectedTab == tab ? Palette.gold : Palette.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}
