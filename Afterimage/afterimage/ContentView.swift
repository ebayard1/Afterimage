import SwiftUI

struct ContentView: View {
    @State private var auth = AuthService()
    @State private var toast = ToastCenter()
    @State private var users = UserService()
    // Every listener-bearing service lives HERE, not in a screen. The paged
    // TabView keeps Rolls, Camera and Profile mounted simultaneously, so a
    // per-view `@State` service is never torn down and its snapshot listener
    // is simply duplicated once per page: this was three identical album
    // queries and two notification queries running at all times, with every
    // album document decoded three times per snapshot. One instance each,
    // injected through the environment, started and stopped from `auth.uid`.
    @State private var albums = AlbumService()
    @State private var notifs = NotificationService()
    @State private var activity = ActivityService()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            content

            ToastOverlay()
                .environment(toast)
        }
        .onAppear {
            if let uid = auth.uid { startServices(uid: uid) }
        }
        // Keep every user-scoped listener in sync with auth.
        .onChange(of: auth.uid) { _, uid in
            if let uid { startServices(uid: uid) }
            else { stopServices() }
        }
    }

    /// Attaches every user-scoped Firestore listener exactly once. Each
    /// `startListening` is idempotent (it removes its previous registration
    /// first), so calling this again for the same uid is safe.
    private func startServices(uid: String) {
        users.startListening(uid: uid)
        albums.startListening(userId: uid)
        notifs.startListening(uid: uid)
        activity.startListening(uid: uid)
        wirePush(uid: uid)
    }

    private func stopServices() {
        users.stopListening()
        albums.stopListening()
        notifs.stopListening()
        activity.stopListening()
    }

    /// Save the FCM push token onto the signed-in user's profile.
    private func wirePush(uid: String) {
        PushRegistry.shared.onToken = { token in
            Task { await users.upsertFcmToken(token, uid: uid) }
        }
        if let token = PushRegistry.shared.token {
            Task { await users.upsertFcmToken(token, uid: uid) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if auth.isLoading {
            ProgressView().tint(Palette.gold)
        } else if auth.isSignedIn {
            if users.isLoadingProfile {
                ProgressView().tint(Palette.gold)
            } else if users.hasProfile {
                mainApp
            } else {
                ProfileSetupView()
                    .environment(auth)
                    .environment(users)
                    .environment(toast)
            }
        } else if !hasSeenOnboarding {
            OnboardingFlow {
                hasSeenOnboarding = true
            }
        } else {
            SignInView()
                .environment(auth)
                .environment(toast)
        }
    }

    private var mainApp: some View {
        MainTabView()
            .environment(auth)
            .environment(toast)
            .environment(users)
            .environment(albums)
            .environment(notifs)
            .environment(activity)
    }
}
