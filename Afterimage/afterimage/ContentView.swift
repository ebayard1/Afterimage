import SwiftUI

struct ContentView: View {
    @State private var auth = AuthService()
    @State private var toast = ToastCenter()
    @State private var users = UserService()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            content

            ToastOverlay()
                .environment(toast)
        }
        .onAppear {
            if let uid = auth.uid { users.startListening(uid: uid); wirePush(uid: uid) }
        }
        // Keep the current user's profile listener in sync with auth.
        .onChange(of: auth.uid) { _, uid in
            if let uid { users.startListening(uid: uid); wirePush(uid: uid) }
            else { users.stopListening() }
        }
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
    }
}
