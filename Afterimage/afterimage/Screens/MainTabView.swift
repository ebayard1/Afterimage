import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable { case rolls, camera, profile }
    @State private var selectedTab: Tab = .rolls

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("rolls", systemImage: "film.stack.fill") }
                .tag(Tab.rolls)

            CameraTabView()
                .tabItem { Label("camera", systemImage: "camera.fill") }
                .tag(Tab.camera)

            ProfileView()
                .tabItem { Label("profile", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
        .tint(Palette.gold)
        .toolbarBackground(Palette.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onChange(of: selectedTab) { _, _ in
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
