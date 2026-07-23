import SwiftUI

/// Shown once, after a real account is created, to claim a unique handle and a
/// display name. Writes `users/{uid}` + `usernames/{handle}` via `UserService`.
/// Only reached in real mode (sample mode bypasses auth entirely).
struct ProfileSetupView: View {
    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users
    @Environment(ToastCenter.self) private var toast

    @State private var handle = ""
    @State private var displayName = ""
    @State private var checking = false
    @State private var available: Bool?
    @State private var saving = false
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    private enum Field { case handle, name }

    private var cleanedHandle: String {
        handle.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "@", with: "").lowercased()
    }
    private var handleValid: Bool {
        let h = cleanedHandle
        return h.count >= 3 && h.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    private var canSubmit: Bool {
        handleValid && available == true && !displayName.trimmingCharacters(in: .whitespaces).isEmpty && !saving
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    handleField
                    nameField
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12)).foregroundStyle(Palette.red)
                    }
                    submitButton
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
            .scrollIndicators(.hidden)

            startOverButton
        }
        .preferredColorScheme(.dark)
    }

    /// The only way out of account setup — there's no profile to go "back" to,
    /// so the escape is to sign out and return to the sign-in screen.
    private var startOverButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            try? auth.signOut()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("SIGN OUT")
                    .font(.custom("Bebas Neue", size: 12)).tracking(2)
            }
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(
                Capsule().fill(Palette.surface.opacity(0.7))
                    .overlay(Capsule().stroke(Palette.border, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .pressEffect()
        .padding(.horizontal, 16).padding(.top, 12)
        .accessibilityLabel("Sign out and start over")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Rectangle().fill(Palette.gold.opacity(0.45)).frame(width: 18, height: 1)
                Text("CLAIM YOUR HANDLE")
                    .font(.custom("Menlo", size: 9)).tracking(3)
                    .foregroundStyle(Palette.gold)
            }
            Text("WHO ARE YOU\nIN THE DARKROOM?")
                .font(.custom("Bebas Neue", size: 40)).tracking(-1)
                .foregroundStyle(Palette.textPrimary)
            Text("your handle is how friends find you and how your shots are signed.")
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var handleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("HANDLE")
                    .font(.custom("Menlo", size: 9)).tracking(2)
                    .foregroundStyle(focused == .handle ? Palette.gold : Palette.textTertiary)
                Spacer()
                availabilityHint
            }
            HStack(spacing: 4) {
                Text("@").foregroundStyle(Palette.textTertiary)
                TextField("", text: $handle, prompt: promptText("your_handle"))
                    .focused($focused, equals: .handle)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Palette.textPrimary)
                    .onChange(of: handle) { _, _ in scheduleAvailabilityCheck() }
            }
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Palette.surface)
            .overlay(Capsule().stroke(focused == .handle ? Palette.gold : Palette.border, lineWidth: 1))
            .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var availabilityHint: some View {
        if checking {
            Text("checking…").font(.custom("Menlo", size: 9)).foregroundStyle(Palette.textTertiary)
        } else if !handleValid && !cleanedHandle.isEmpty {
            Text("3+ letters, numbers, _").font(.custom("Menlo", size: 9)).foregroundStyle(Palette.textTertiary)
        } else if available == true {
            Text("available").font(.custom("Menlo", size: 9)).foregroundStyle(Palette.gold)
        } else if available == false {
            Text("taken").font(.custom("Menlo", size: 9)).foregroundStyle(Palette.red)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DISPLAY NAME")
                .font(.custom("Menlo", size: 9)).tracking(2)
                .foregroundStyle(focused == .name ? Palette.gold : Palette.textTertiary)
            TextField("", text: $displayName, prompt: promptText("Sam Kim"))
                .focused($focused, equals: .name)
                .foregroundStyle(Palette.textPrimary)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Palette.surface)
                .overlay(Capsule().stroke(focused == .name ? Palette.gold : Palette.border, lineWidth: 1))
                .clipShape(Capsule())
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            ZStack {
                Capsule().fill(canSubmit ? Palette.gold : Palette.gold.opacity(0.35))
                if saving {
                    ProgressView().tint(.black)
                } else {
                    Text("ENTER")
                        .font(.custom("Bebas Neue", size: 17)).tracking(4)
                        .foregroundStyle(.black)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 52)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    private func promptText(_ s: String) -> Text {
        Text(s).font(.custom("Times New Roman", size: 14)).italic().foregroundStyle(Palette.textTertiary)
    }

    // Debounced availability check.
    @State private var checkTask: Task<Void, Never>?
    private func scheduleAvailabilityCheck() {
        available = nil
        checkTask?.cancel()
        guard handleValid else { return }
        let h = cleanedHandle
        checking = true
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            if Task.isCancelled { return }
            let ok = (try? await users.isUsernameAvailable(h)) ?? false
            if Task.isCancelled { return }
            await MainActor.run {
                checking = false
                available = ok
            }
        }
    }

    private func submit() {
        guard let uid = auth.uid else { return }
        saving = true
        errorMessage = nil
        Task {
            do {
                try await users.createProfile(uid: uid, username: cleanedHandle,
                                              displayName: displayName)
                users.startListening(uid: uid)
                toast.success("welcome to the darkroom")
            } catch {
                errorMessage = error.localizedDescription
            }
            saving = false
        }
    }
}
