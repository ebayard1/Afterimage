import SwiftUI

struct ContentView: View {
    @State private var auth = AuthService()
    @State private var toast = ToastCenter()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    // Versioned onboarding reset. Bump CURRENT_RESET_VERSION whenever we want
    // every device to play the onboarding from scratch on its next launch.
    // The check fires once per version bump, then never again.
    private static let CURRENT_RESET_VERSION = 1
    @AppStorage("onboardingResetVersion") private var resetVersion = 0

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            if auth.isLoading {
                ProgressView().tint(Palette.gold)
            } else if auth.isSignedIn {
                MainTabView()
                    .environment(auth)
                    .environment(toast)
            } else if !hasSeenOnboarding {
                OnboardingFlow {
                    hasSeenOnboarding = true
                }
            } else {
                SignInView()
                    .environment(auth)
                    .environment(toast)
            }

            ToastOverlay()
                .environment(toast)
        }
        .onAppear { applyOnboardingResetIfNeeded() }
    }

    /// Wipes every onboarding-related flag the first time the app launches
    /// under a new `CURRENT_RESET_VERSION`. Bump that constant whenever you
    /// want all users (or just yourself, since UserDefaults is per-install)
    /// to play onboarding from scratch.
    private func applyOnboardingResetIfNeeded() {
        guard resetVersion < Self.CURRENT_RESET_VERSION else { return }
        let defaults = UserDefaults.standard
        // Onboarding + coach marks
        defaults.removeObject(forKey: "hasSeenOnboarding")
        defaults.removeObject(forKey: "hasSeenFeedCoach")
        defaults.removeObject(forKey: "hasSeenCameraCoach")
        // Bookmarked shots (sample-only mode means these are stale)
        defaults.removeObject(forKey: "afterimage.savedShotIds")
        // Stamp the version so this never fires again until the next bump.
        resetVersion = Self.CURRENT_RESET_VERSION
        // Force the @AppStorage observer to pick up the cleared value.
        hasSeenOnboarding = false
    }
}
