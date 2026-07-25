import SwiftUI
import FirebaseAuth

// MARK: - SignInView (anti-default rewrite)
//
// Not a SaaS form. The first impression every TestFlight tester will have of
// Afterimage — therefore staged as a darkroom initiation, not a credentials
// dialog.
//
// Cinematic structure (AIDA):
//   1. AmbientFilmLeader (top) — perpetual sprocket motion, projector warming up
//   2. Hero — two-line Bebas Neue promise, sunrise breath behind it
//   3. RitualTriptych — the entire app in three cells: SHOOT . WAIT . REVEAL
//   4. Initiation panel — credentials reframed as "load the canister"
//   5. Footer — quiet Menlo epigraph + version stamp
//
// Banned by the gpt-taste audit and removed:
//   - "welcome back"
//   - "create your account"
//   - "no account? sign up"
//   - centered productivity-app form chrome
//   - narrow text walls (6-line wraps)
//   - invisible button text

struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focused: Field?
    @State private var revealHero = false

    private enum Field { case email, password }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        password.count >= 6
    }

    var body: some View {
        ZStack {
            backdrop
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 8)
                    hero
                        .padding(.top, 24)
                        .padding(.bottom, 36)
                    ritualTriptych
                        .padding(.bottom, 40)
                    initiationPanel
                        .padding(.bottom, 28)
                    quietToggle
                        .padding(.bottom, 14)
                    footerEpigraph
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            VStack {
                AmbientFilmLeader()
                Spacer()
            }
            .ignoresSafeArea(edges: .top)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(Motion.cinematic.delay(0.15)) { revealHero = true }
        }
    }

    // MARK: Backdrop — sunrise breath + grain

    private var backdrop: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            // Slow sunrise wash behind the hero — TimelineView so it never blocks
            // the main thread on re-renders.
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let pulse = (sin(t * (2 * .pi / 6.8)) + 1) / 2  // 6.8s breathing period
                RadialGradient(
                    colors: [
                        Color(red: 0.45, green: 0.20, blue: 0.10).opacity(0.28 + 0.10 * pulse),
                        Color(red: 0.20, green: 0.06, blue: 0.04).opacity(0.18 + 0.08 * pulse),
                        .clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.32),
                    startRadius: 4,
                    endRadius: 360
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Subtle film grain — Canvas, drawn once per frame.
            TimelineView(.animation(minimumInterval: 1.0 / 14.0, paused: false)) { context in
                Canvas { ctx, size in
                    let seed = Int(context.date.timeIntervalSinceReferenceDate * 10)
                    var rng = SplitMix(seed)
                    for _ in 0..<90 {
                        let x = CGFloat(rng.next01()) * size.width
                        let y = CGFloat(rng.next01()) * size.height
                        let r = CGFloat(0.4 + rng.next01() * 1.0)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                            with: .color(.white.opacity(0.030))
                        )
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: Hero — 2-line iron rule

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Tiny brand stamp — Menlo, not the headline.
            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text("A F T E R I M A G E")
                    .font(.custom("Menlo", size: 9)).tracking(4)
                    .foregroundStyle(Palette.gold.opacity(0.85))
                Rectangle().fill(Palette.gold.opacity(0.25)).frame(height: 1)
            }

            // Two-line Bebas Neue promise. Locked to two lines by minimumScaleFactor
            // and a wide container — never wraps to 6 lines.
            VStack(alignment: .leading, spacing: 2) {
                Text("SHOOT BLIND.")
                    .font(.custom("Bebas Neue", size: 56)).tracking(-1)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("WAIT FOR SUNRISE.")
                    .font(.custom("Bebas Neue", size: 56)).tracking(-1)
                    .foregroundStyle(Palette.gold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(revealHero ? 1 : 0)
            .offset(y: revealHero ? 0 : 14)

            // Italic Times New Roman connective tissue — never SaaS chrome.
            Text("a disposable camera, a shared darkroom, and one ritual every morning.")
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(revealHero ? 1 : 0)
        }
    }

    // MARK: RitualTriptych — gapless 3-up bento, the whole app in three cells

    private var ritualTriptych: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ritualCell(
                    number: "01",
                    label: "SHOOT",
                    sub: "no preview. no retakes.",
                    icon: "camera.aperture",
                    tint: Palette.darkRed
                )
                Rectangle().fill(Palette.border).frame(width: 1)
                ritualCell(
                    number: "02",
                    label: "WAIT",
                    sub: "the roll develops in the dark.",
                    icon: "hourglass",
                    tint: Color(red: 0.55, green: 0.42, blue: 0.18)
                )
                Rectangle().fill(Palette.border).frame(width: 1)
                ritualCell(
                    number: "03",
                    label: "REVEAL",
                    sub: "at the next sunrise.",
                    icon: "sunrise.fill",
                    tint: Palette.gold
                )
            }
            .background(Palette.surface)
            .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
        }
    }

    private func ritualCell(number: String, label: String, sub: String,
                            icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(number)
                    .font(.custom("Menlo", size: 9)).tracking(1.5)
                    .foregroundStyle(tint)
                Rectangle().fill(tint.opacity(0.35)).frame(height: 1)
            }
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(tint)
            Text(label)
                .font(.custom("Bebas Neue", size: 18)).tracking(2)
                .foregroundStyle(Palette.textPrimary)
            Text(sub)
                .font(.custom("Times New Roman", size: 11)).italic()
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12).padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Initiation panel — credentials, but framed as loading the canister

    private var initiationPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Plate header line — Menlo, never a heading
            HStack(spacing: 8) {
                Rectangle().fill(Palette.gold.opacity(0.45)).frame(width: 18, height: 1)
                Text(isSigningUp ? "LOAD A FRESH CANISTER" : "RETURN TO THE DARKROOM")
                    .font(.custom("Menlo", size: 9)).tracking(3)
                    .foregroundStyle(Palette.gold)
                Rectangle().fill(Palette.gold.opacity(0.25)).frame(height: 1)
            }

            inputField(
                label: "email",
                placeholder: "you@email.com",
                text: $email,
                isSecure: false,
                field: .email,
                content: .emailAddress
            )

            inputField(
                label: "password",
                placeholder: "at least 6 characters",
                text: $password,
                isSecure: true,
                field: .password,
                content: .password
            )

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(errorMessage)
                        .font(.system(size: 11))
                }
                .foregroundStyle(Palette.red)
            }

            // The CTA — gold pill with perfect contrast. Black text on gold.
            Button(action: submit) {
                ZStack {
                    Capsule().fill(canSubmit ? Palette.gold : Palette.gold.opacity(0.35))
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text(isSigningUp ? "LOAD THE ROLL" : "ENTER THE DARKROOM")
                                .font(.custom("Bebas Neue", size: 17)).tracking(4)
                                .foregroundStyle(.black)
                            ZStack {
                                Circle().fill(.black.opacity(0.20))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.black)
                            }
                            .frame(width: 26, height: 26)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .pressEffect(scale: 0.97, lift: 1)
            .warmShadow(radius: 12, y: 7, opacity: canSubmit ? 0.5 : 0.15)
            .disabled(!canSubmit || isLoading)
            .padding(.top, 6)
            .accessibilityLabel(isSigningUp ? "Load the roll" : "Enter the darkroom")
            .accessibilityHint("Creates your account or signs you in")
        }
        .padding(18)
        .background(
            // Subtle stage backdrop so the panel reads as its own object,
            // distinct from the hero.
            ZStack {
                Palette.surface.opacity(0.55)
                LinearGradient(
                    colors: [Palette.gold.opacity(0.06), .clear],
                    startPoint: .top, endPoint: .bottom
                )
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func inputField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isSecure: Bool,
        field: Field,
        content: UITextContentType
    ) -> some View {
        let active = focused == field
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.custom("Menlo", size: 9)).tracking(2)
                    .foregroundStyle(active ? Palette.gold : Palette.textTertiary)
                Rectangle()
                    .fill(active ? Palette.gold.opacity(0.45) : Palette.border)
                    .frame(height: 1)
            }
            Group {
                if isSecure {
                    SecureField("", text: text, prompt: promptText(placeholder))
                        .focused($focused, equals: field)
                        .textContentType(content)
                } else {
                    TextField("", text: text, prompt: promptText(placeholder))
                        .focused($focused, equals: field)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(content)
                }
            }
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Palette.textPrimary)
            .tint(Palette.gold)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.background.opacity(0.65))
            .overlay(
                Capsule().stroke(
                    active ? Palette.gold : Palette.border,
                    lineWidth: active ? 1.5 : 1
                )
            )
            .clipShape(Capsule())
            .animation(Motion.tap, value: active)
        }
    }

    private func promptText(_ text: String) -> Text {
        Text(text)
            .font(.custom("Times New Roman", size: 14)).italic()
            .foregroundStyle(Palette.textTertiary)
    }

    // MARK: Quiet toggle — italic Times New Roman footnote, not chrome

    private var quietToggle: some View {
        Button {
            withAnimation(Motion.tap) {
                isSigningUp.toggle()
                errorMessage = nil
            }
        } label: {
            HStack(spacing: 6) {
                Text(isSigningUp ? "already have an account?" : "new to afterimage?")
                    .font(.custom("Times New Roman", size: 13)).italic()
                    .foregroundStyle(Palette.textSecondary)
                Text(isSigningUp ? "SIGN IN" : "SIGN UP")
                    .font(.custom("Bebas Neue", size: 14)).tracking(2)
                    .foregroundStyle(Palette.gold)
                    .underline()
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.gold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel(isSigningUp ? "Already have an account? Sign in" : "New here? Sign up")
    }

    // MARK: Footer epigraph — version + ritual signature

    private var footerEpigraph: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.border).frame(height: 1)
            Text("SHOOT . WAIT . REVEAL")
                .font(.custom("Menlo", size: 9)).tracking(2.5)
                .foregroundStyle(Palette.textTertiary)
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    // MARK: Submit

    private func submit() {
        Haptics.soft()
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if isSigningUp {
                    try await auth.signUp(email: email, password: password)
                } else {
                    try await auth.signIn(email: email, password: password)
                }
                Haptics.notify(.success)
            } catch {
                errorMessage = Self.friendlyAuthMessage(for: error)
                Haptics.notify(.error)
            }
            isLoading = false
        }
    }

    /// Firebase's raw messages confuse more than they help — notably
    /// "credential is malformed or has expired", which (with email
    /// enumeration protection on) is just its generic wrong-email-or-password
    /// error. Translate the common codes; fall through for the rest.
    private static func friendlyAuthMessage(for error: Error) -> String {
        switch AuthErrorCode(rawValue: (error as NSError).code) {
        case .invalidCredential, .wrongPassword, .userNotFound:
            return "wrong email or password"
        case .invalidEmail:
            return "that doesn't look like an email address"
        case .emailAlreadyInUse:
            return "that email already has a darkroom — sign in instead"
        case .weakPassword:
            return "password needs at least 6 characters"
        case .networkError:
            return "no connection — try again"
        case .tooManyRequests:
            return "too many attempts — wait a minute and try again"
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - Tiny seeded RNG used by the grain canvas
//
// SplitMix64 — deterministic, single-state PRNG. We seed it from the current
// time bucket so the grain twinkles instead of being static, but it's still
// fast and never blocks the render thread.

private struct SplitMix {
    var state: UInt64
    init(_ seed: Int) {
        // Convert the Int seed to UInt64 first so the gold-ratio constant
        // (which exceeds Int.max on 64-bit platforms) doesn't overflow.
        let s = UInt64(truncatingIfNeeded: seed)
        self.state = s &* 0x9E37_79B9_7F4A_7C15
    }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z &>> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z &>> 31)
    }
    mutating func next01() -> Double {
        Double(next() &>> 11) / Double(UInt64(1) << 53)
    }
}
