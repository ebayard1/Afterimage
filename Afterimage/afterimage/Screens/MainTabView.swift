import SwiftUI

// MARK: - MainTabView
//
// The three main pages (Rolls · Camera · Profile) in a PAGED TabView, so you
// can swipe horizontally between them as well as tap. The system tab bar is
// replaced by a compact custom bar — icons only, ~40pt tall — inset via
// `safeAreaInset` so every page (critically the camera, whose shell artwork
// needs every point of height) lays out inside the space above it.

/// App-wide tab selection, injected into the environment so any screen can
/// send the user to another tab (e.g. an album's OPEN CAMERA button switches
/// to the one real camera page instead of presenting its own copy).
@Observable
final class TabRouter {
    var selected: MainTabView.Tab = .rolls
}

struct MainTabView: View {
    enum Tab: Int, Hashable, CaseIterable { case rolls, camera, profile }
    @State private var router = TabRouter()

    var body: some View {
        @Bindable var router = router
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            // The camera shell is width-fit and top-anchored, so its bottom
            // edge lands at width × (1740/904). Size the tab bar to fill the
            // whole zone from the shell's bottom edge to the home-indicator
            // area — the menu "touches" the camera on every device width.
            let fullHeight = geo.size.height + topInset + geo.safeAreaInsets.bottom
            let shellBottom = geo.size.width * (1740.0 / 904.0)
            let barHeight = max(56, fullHeight - shellBottom - geo.safeAreaInsets.bottom)
            TabView(selection: $router.selected) {
                HomeView()
                    .safeAreaPadding(.top, topInset)
                    .tag(Tab.rolls)

                CameraTabView()
                    .tag(Tab.camera)

                ProfileView()
                    .safeAreaPadding(.top, topInset)
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
            .statusBarHidden(router.selected == .camera)
            .onChange(of: router.selected) { _, _ in
                UISelectionFeedbackGenerator().selectionChanged()
            }
            .environment(router)
        }
    }

    // MARK: Compact bar — icons only, minimal height, out of the shell's way.
    // A floating Liquid Glass capsule rather than an opaque edge-to-edge bar.
    // Pulled DOWN into the home-indicator margin so it clears the (zoomed) shell
    // artwork — the glass then floats over the background, not over the leather.

    private func compactBar(height: CGFloat) -> some View {
        // Liquid Glass capsule (back by request): the three icons ride inside
        // a floating glass pill, vertically centred in the zone between the
        // camera shell's bottom edge and the home indicator.
        HStack {
            barButton(.rolls, icon: "film.stack.fill", label: "Rolls")
            barButton(.camera, icon: "camera.fill", label: "Camera")
            barButton(.profile, icon: "person.crop.circle.fill", label: "Profile")
        }
        .frame(height: 52)
        .padding(.horizontal, 22)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 56)
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    private func barButton(_ tab: Tab, icon: String, label: String) -> some View {
        Button {
            withAnimation(Motion.crisp) { router.selected = tab }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(router.selected == tab ? Palette.gold : Palette.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(router.selected == tab ? .isSelected : [])
    }
}
