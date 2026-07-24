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

    var body: some View {
        GeometryReader { geo in
            let topInset = geo.safeAreaInsets.top
            TabView(selection: $selectedTab) {
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
            .safeAreaInset(edge: .bottom, spacing: 0) { compactBar }
            // On the camera page the whole screen IS the device — hide the
            // system status bar (clock / battery / signal) so nothing floats
            // over the shell. Rolls and Profile keep it.
            .statusBarHidden(selectedTab == .camera)
            .onChange(of: selectedTab) { _, _ in
                UISelectionFeedbackGenerator().selectionChanged()
            }
        }
    }

    // MARK: Compact bar — icons only, minimal height, out of the shell's way.
    // A floating Liquid Glass capsule rather than an opaque edge-to-edge bar.
    // Pulled DOWN into the home-indicator margin so it clears the (zoomed) shell
    // artwork — the glass then floats over the background, not over the leather.

    private var compactBar: some View {
        // Liquid Glass must live inside a GlassEffectContainer to composite
        // reliably — a bare `.glassEffect` (especially `.interactive()`) can
        // fall back to a flat, opaque pill, which is why the bar read as "no
        // glass." The container also lets the capsule pick up and refract the
        // content that scrolls beneath it.
        GlassEffectContainer(spacing: 0) {
            HStack {
                barButton(.rolls, icon: "film.stack.fill", label: "Rolls")
                barButton(.camera, icon: "camera.fill", label: "Camera")
                barButton(.profile, icon: "person.crop.circle.fill", label: "Profile")
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.horizontal, 64)
        .padding(.bottom, -24)
    }

    private func barButton(_ tab: Tab, icon: String, label: String) -> some View {
        Button {
            withAnimation(Motion.crisp) { selectedTab = tab }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(selectedTab == tab ? Palette.gold : Palette.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}
