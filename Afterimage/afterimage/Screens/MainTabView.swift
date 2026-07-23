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
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(Tab.rolls)

            CameraTabView()
                .tag(Tab.camera)

            ProfileView()
                .tag(Tab.profile)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) { compactBar }
        .onChange(of: selectedTab) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    // MARK: Compact bar — icons only, minimal height, out of the shell's way.

    private var compactBar: some View {
        HStack {
            barButton(.rolls, icon: "film.stack.fill", label: "Rolls")
            barButton(.camera, icon: "camera.fill", label: "Camera")
            barButton(.profile, icon: "person.crop.circle.fill", label: "Profile")
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background {
            Palette.surface
                .overlay(alignment: .top) {
                    Rectangle().fill(Palette.border).frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
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
