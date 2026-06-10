import Foundation
import FirebaseAuth

@Observable
@MainActor
final class AuthService {
    var user: FirebaseAuth.User?
    var isLoading = true

    @ObservationIgnored private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                self?.user = firebaseUser
                self?.isLoading = false
            }
        }
    }

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
