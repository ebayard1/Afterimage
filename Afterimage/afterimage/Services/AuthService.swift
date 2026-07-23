import Foundation
import FirebaseAuth

@Observable
@MainActor
final class AuthService {
    var user: FirebaseAuth.User?
    var isLoading = true

    @ObservationIgnored private var handle: AuthStateDidChangeListenerHandle?

    init() {
        #if DEBUG
        Self.signOutIfFreshBuild()
        #endif
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                self?.user = firebaseUser
                self?.isLoading = false
            }
        }
    }

    #if DEBUG
    /// DEBUG-only: start each freshly-installed build signed out, so dev runs
    /// always land on the sign-in screen (handy for testing onboarding / account
    /// creation). Firebase Auth persists its session in the keychain, which
    /// survives reinstalls, so we key off the app executable's modification date
    /// — it changes on every build — and sign out exactly once per new build.
    /// Guarded by DEBUG so TestFlight / App Store builds are never affected.
    private static func signOutIfFreshBuild() {
        guard let exe = Bundle.main.executableURL,
              let mod = (try? exe.resourceValues(forKeys: [.contentModificationDateKey]))?
                  .contentModificationDate
        else { return }
        let key = "debug.lastBuildSignOutStamp"
        let stamp = String(mod.timeIntervalSince1970)
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: key) != stamp else { return }
        try? Auth.auth().signOut()
        defaults.set(stamp, forKey: key)
    }
    #endif

    var isSignedIn: Bool { user != nil }
    var uid: String? { user?.uid }
    var email: String? { user?.email }

    func signUp(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
