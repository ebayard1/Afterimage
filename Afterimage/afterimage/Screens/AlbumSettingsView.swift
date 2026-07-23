import SwiftUI

// MARK: - AlbumSettingsView (high-end-visual-design rebuild)
//
// Sample-only mode: rename/leave/delete are demo toasts, not real Firestore
// writes. Visual treatment matches the canonical Editorial Luxury rhythm:
// floating header → hero block → Double-Bezel cluster plates → Menlo footer.

struct AlbumSettingsView: View {
    let album: Album
    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var showDeleteConfirm = false
    @State private var showLeaveConfirm = false
    @State private var albumService = AlbumService()
    let onAlbumGone: () -> Void

    init(album: Album, onAlbumGone: @escaping () -> Void) {
        self.album = album
        self._name = State(initialValue: album.name)
        self.onAlbumGone = onAlbumGone
    }

    private var isCreator: Bool { auth.uid == album.creatorId }

    var body: some View {
        ZStack(alignment: .top) {
            Palette.background.ignoresSafeArea()
            // Continuity sunrise wash
            RadialGradient(
                colors: [Palette.gold.opacity(0.10), .clear],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 6,
                endRadius: 360
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView {
                Color.clear.frame(height: 64)  // room for floating header
                VStack(alignment: .leading, spacing: 0) {
                    heroBlock
                        .padding(.horizontal, 22)
                        .padding(.bottom, 36)
                    if isCreator {
                        renamePlate
                            .padding(.horizontal, 18)
                            .padding(.bottom, 24)
                    }
                    membersPlate
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    dangerPlate
                        .padding(.horizontal, 18)
                        .padding(.bottom, 32)
                    footerLine
                        .padding(.horizontal, 22)
                        .padding(.bottom, 36)
                }
            }
            .scrollIndicators(.hidden)

            VStack {
                floatingHeader
                Spacer()
            }
        }
        .alert("Leave this roll?", isPresented: $showLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) { leave() }
        } message: {
            Text("Your shots stay in the roll. You won't be able to add more.")
        }
        .alert("Delete this roll?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteAlbum() }
        } message: {
            Text("All shots will be removed for everyone. This cannot be undone.")
        }
    }

    // MARK: - Floating header

    private var floatingHeader: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Palette.background.opacity(0.7))
                            .overlay(Circle().stroke(Palette.border.opacity(0.6), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .pressEffect(scale: 0.92, lift: 1)
            .accessibilityLabel("Back")

            Spacer()

            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text("ROLL SETTINGS")
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(Palette.gold)
            }
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            Capsule().fill(Palette.surface.opacity(0.75))
                .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 1))
                .warmShadow(radius: 18, y: 6, opacity: 0.35)
        )
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    // MARK: - Hero block

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle().fill(Palette.gold).frame(width: 5, height: 5)
                Text(album.name.uppercased())
                    .font(.custom("Menlo", size: 10)).tracking(3)
                    .foregroundStyle(Palette.gold)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                Capsule().fill(Palette.gold.opacity(0.10))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
            )

            VStack(alignment: .leading, spacing: -2) {
                Text("ROLL")
                    .font(.custom("Bebas Neue", size: 50)).tracking(-1)
                    .foregroundStyle(Palette.textPrimary)
                Text("CONTROLS.")
                    .font(.custom("Bebas Neue", size: 50)).tracking(-1)
                    .foregroundStyle(Palette.gold)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(album.memberIds.count) member\(album.memberIds.count == 1 ? "" : "s") · the quiet machinery behind this roll.")
                .font(.custom("Times New Roman", size: 14)).italic()
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Rename plate

    private var renamePlate: some View {
        clusterPlate(eyebrow: "NAME", tint: Palette.gold) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    TextField("", text: $name,
                              prompt: Text("roll name")
                        .font(.custom("Times New Roman", size: 14)).italic()
                        .foregroundStyle(Palette.textTertiary))
                        .font(.custom("Bebas Neue", size: 18)).tracking(1)
                        .foregroundStyle(Palette.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button { rename() } label: {
                        Text("SAVE")
                            .font(.custom("Bebas Neue", size: 12)).tracking(3)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(
                                Capsule().fill(canSave ? Palette.gold : Palette.gold.opacity(0.35))
                            )
                    }
                    .buttonStyle(.plain)
                    .pressEffect(scale: 0.94)
                    .disabled(!canSave)
                    .accessibilityLabel("Save roll name")
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
            }
        }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && trimmed != album.name
    }

    // MARK: - Members plate

    private var membersPlate: some View {
        clusterPlate(eyebrow: "MEMBERS", tint: Palette.textSecondary) {
            VStack(spacing: 0) {
                ForEach(Array(album.memberIds.enumerated()), id: \.offset) { idx, uid in
                    memberRow(uid: uid)
                    if idx < album.memberIds.count - 1 {
                        Rectangle().fill(Palette.border.opacity(0.4))
                            .frame(height: 1)
                            .padding(.horizontal, 14)
                    }
                }
            }
        }
    }

    private func memberRow(uid: String) -> some View {
        HStack(spacing: 12) {
            AlbumMemberAvatar(uid: uid, size: 32)
                .overlay(Circle().stroke(Palette.border, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(memberLabel(uid))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                if uid == album.creatorId {
                    Text("loaded the roll")
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                } else if uid == auth.uid {
                    Text("that's you")
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                } else {
                    Text("collaborator")
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            Spacer()
            if uid == album.creatorId {
                Text("CREATOR")
                    .font(.custom("Bebas Neue", size: 9)).tracking(2)
                    .foregroundStyle(Palette.gold)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(
                        Capsule().fill(Palette.gold.opacity(0.10))
                            .overlay(Capsule().stroke(Palette.gold.opacity(0.4), lineWidth: 1))
                    )
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func memberLabel(_ uid: String) -> String {
        if uid == auth.uid { return "you" }
        if let profile = users.profile(for: uid) { return profile.displayName }
        return String(uid.prefix(8)) + "…"
    }

    // MARK: - Danger plate

    private var dangerPlate: some View {
        clusterPlate(eyebrow: "EXITS", tint: Palette.red) {
            VStack(spacing: 0) {
                dangerRow(icon: "rectangle.portrait.and.arrow.right",
                          tint: Palette.red,
                          title: "Leave Roll",
                          sub: "your shots stay — you can't add more") {
                    showLeaveConfirm = true
                }
                if isCreator {
                    Rectangle().fill(Palette.border.opacity(0.4))
                        .frame(height: 1)
                        .padding(.horizontal, 14)
                    dangerRow(icon: "trash.fill",
                              tint: Palette.darkRed,
                              title: "Delete Roll",
                              sub: "all shots gone for everyone, forever") {
                        showDeleteConfirm = true
                    }
                }
            }
        }
    }

    private func dangerRow(icon: String, tint: Color, title: String, sub: String,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(tint.opacity(0.15))
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(tint)
                }
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(tint.opacity(0.4), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(sub)
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint.opacity(0.7))
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .pressEffect(scale: 0.985)
        .accessibilityLabel(title)
        .accessibilityHint(sub)
    }

    // MARK: - Cluster plate (shared Double-Bezel container)

    @ViewBuilder
    private func clusterPlate<Content: View>(
        eyebrow: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 5, height: 5)
                Text(eyebrow)
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(tint)
                Rectangle().fill(tint.opacity(0.2)).frame(height: 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Rectangle().fill(Palette.border.opacity(0.5)).frame(height: 1)
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                )
        )
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.background.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    // MARK: - Footer

    private var footerLine: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.border).frame(height: 1)
            Text("ROLL · \(String(album.id?.prefix(8) ?? "demo"))")
                .font(.custom("Menlo", size: 9)).tracking(2.5)
                .foregroundStyle(Palette.textTertiary)
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    // MARK: - Sample-only demo actions
    //
    // None of these touch Firestore. They show a toast that explains what
    // would happen, then dismiss/clear appropriately. Real beta wiring lives
    // behind a separate code branch.

    private func rename() {
        UISelectionFeedbackGenerator().selectionChanged()
        let newName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, let id = album.id else { return }
        Task {
            do { try await albumService.rename(albumId: id, newName: newName)
                 toast.success("renamed to \"\(newName)\"") }
            catch { toast.error("couldn't rename") }
        }
    }

    private func leave() {
        guard let id = album.id else { return }
        Task {
            do {
                if let uid = auth.uid { try await albumService.leave(albumId: id, userId: uid) }
                toast.show("you left the roll")
                onAlbumGone(); dismiss()
            } catch { toast.error("couldn't leave") }
        }
    }

    private func deleteAlbum() {
        guard let id = album.id else { return }
        Task {
            do { try await albumService.delete(albumId: id)
                 toast.success("roll deleted")
                 onAlbumGone(); dismiss() }
            catch { toast.error("couldn't delete") }
        }
    }
}
