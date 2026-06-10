import SwiftUI

struct GalleryEntry: Identifiable {
    let id = UUID()
    let title: String
    let note: String
    let content: () -> AnyView
}

struct GallerySection: Identifiable {
    let id = UUID()
    let title: String
    let entries: [GalleryEntry]
}

enum GalleryCatalog {
    static let sections: [GallerySection] = [
        GallerySection(title: "Onboarding", entries: [
            .init(title: "01 Welcome", note: "Film-frame border wraps brand logo. Gold-on-black.", content: { AnyView(WelcomeDesign()) }),
            .init(title: "02 How It Works", note: "Shoot → set window → reveal. Film roll counter intro.", content: { AnyView(HowItWorksDesign()) }),
            .init(title: "03 Create Account", note: "Email + Apple/Google SSO.", content: { AnyView(EmailSignupDesign()) }),
            .init(title: "04 Verify Email", note: "6-digit code with inline keypad.", content: { AnyView(EmailVerifyDesign()) }),
            .init(title: "05 Set Up Profile", note: "Avatar, display name, @username with availability check.", content: { AnyView(ProfileSetupDesign()) }),
            .init(title: "06 Find Friends", note: "Contacts toggle + friends found on afterimage.", content: { AnyView(FindFriendsDesign()) }),
            .init(title: "07 Permissions", note: "Face ID framed as friend-tagging superpower.", content: { AnyView(PermissionsDesign()) }),
        ]),
        GallerySection(title: "Returning Auth", entries: [
            .init(title: "Forgot Password — Enter Email", note: "Clean email field, sends reset link.", content: { AnyView(ForgotPasswordEnterDesign()) }),
            .init(title: "Forgot Password — Link Sent", note: "Confirmation. Resend option.", content: { AnyView(ForgotPasswordSentDesign()) }),
            .init(title: "Forgot Password — New Password", note: "Password fields + strength indicator.", content: { AnyView(ForgotPasswordNewDesign()) }),
        ]),
        GallerySection(title: "Album Flow", entries: [
            .init(title: "Invite Friends", note: "Search + suggested + A–Z, chips for added.", content: { AnyView(InviteFriendsDesign()) }),
            .init(title: "Creator QR", note: "Shareable QR shown after setup.", content: { AnyView(CreatorQRDesign()) }),
            .init(title: "Ready to Shoot", note: "Album summary + load film CTA.", content: { AnyView(ReadyToShootDesign()) }),
            .init(title: "Gather to Reveal", note: "QR check-in gate for ½ quorum.", content: { AnyView(PresenceCheckDesign()) }),
            .init(title: "Invite Deep Link", note: "Full-screen invite card from push notif.", content: { AnyView(InviteDeepLinkDesign()) }),
        ]),
        GallerySection(title: "Reveal & Recap", entries: [
            .init(title: "Reveal — Developing", note: "30% red ripples, do-not-close copy.", content: { AnyView(RevealStageDesign(stage: 1)) }),
            .init(title: "Reveal — Almost Ready", note: "75%, images surfacing.", content: { AnyView(RevealStageDesign(stage: 2)) }),
            .init(title: "Reveal — Ready", note: "Gold palette, open album CTA.", content: { AnyView(RevealStageDesign(stage: 3)) }),
            .init(title: "Recap Playback", note: "Video, reactions bar, participant pills.", content: { AnyView(RecapDesign()) }),
            .init(title: "Timeline Reactions", note: "Reaction clusters on scrub bar.", content: { AnyView(RecapTimelineDesign()) }),
            .init(title: "Share Recap", note: "Instagram, iMessage, etc.", content: { AnyView(ShareRecapDesign()) }),
        ]),
        GallerySection(title: "Social", entries: [
            .init(title: "Notifications", note: "Friend requests pinned + reveal/countdown rows.", content: { AnyView(NotificationsDesign()) }),
            .init(title: "Friends List", note: "Pending pinned in gold + your friends.", content: { AnyView(FriendsListDesign()) }),
            .init(title: "Other Profile", note: "Follow + msg + their public dispos.", content: { AnyView(OtherProfileDesign()) }),
            .init(title: "Block / Report", note: "6 report categories + final block CTA.", content: { AnyView(BlockReportDesign()) }),
            .init(title: "Settings (Full)", note: "Account, privacy toggles, notifications, danger.", content: { AnyView(SettingsFullDesign()) }),
        ]),
        GallerySection(title: "Detail + Viewer", entries: [
            .init(title: "Shot Viewer (Face Tag)", note: "Full screen + face tag overlay + reactions.", content: { AnyView(ShotViewerDesign()) }),
            .init(title: "Photo Swipe Viewer", note: "Full screen + page dots + Kodak border.", content: { AnyView(PhotoSwipeDesign()) }),
            .init(title: "Pinch to Zoom", note: "Two-finger zoom, 1.8x indicator.", content: { AnyView(PinchZoomDesign()) }),
        ]),
        GallerySection(title: "Coach Marks", entries: [
            .init(title: "Coach — Camera", note: "First-time shutter highlight.", content: { AnyView(CoachCameraDesign()) }),
            .init(title: "Coach — Feed", note: "First-time developing rail highlight.", content: { AnyView(CoachFeedDesign()) }),
        ]),
        GallerySection(title: "States", entries: [
            .init(title: "Empty Feed", note: "New user, no albums.", content: { AnyView(EmptyFeedDesign()) }),
            .init(title: "No Friends Yet", note: "Find from contacts / share link.", content: { AnyView(NoFriendsDesign()) }),
            .init(title: "Upload Failed", note: "Saved locally, will retry.", content: { AnyView(UploadFailedDesign()) }),
            .init(title: "Offline", note: "No connection. Retry button.", content: { AnyView(OfflineDesign()) }),
            .init(title: "Camera Denied", note: "Open Settings to allow camera.", content: { AnyView(CameraDeniedDesign()) }),
            .init(title: "You Left The Album", note: "Shots stay in recap.", content: { AnyView(LeftAlbumDesign()) }),
            .init(title: "Removed By Creator", note: "Shots excluded, won't see recap.", content: { AnyView(RemovedDesign()) }),
            .init(title: "Album Full (24/24)", note: "Roll complete, develop window remaining.", content: { AnyView(AlbumFullDesign()) }),
            .init(title: "Empty In-Progress Album", note: "Blank film roll, 'be the first'.", content: { AnyView(EmptyInProgressDesign()) }),
            .init(title: "Film Canister (Empty)", note: "Loaded fresh roll empty state.", content: { AnyView(FilmCanisterDesign()) }),
        ]),
        GallerySection(title: "Disposable Camera Details", entries: [
            .init(title: "Contact Sheet", note: "Kodak orange border, frame numbers, C-41 strip.", content: { AnyView(ContactSheetDesign()) }),
            .init(title: "Chemical Trays", note: "Developer → Stop Bath → Fixer.", content: { AnyView(ChemicalTraysDesign()) }),
            .init(title: "Flash Charge LED", note: "Upload state with charging indicator.", content: { AnyView(FlashChargeDesign()) }),
            .init(title: "Film Advance Wheel", note: "Camera with serrated wheel + red counter.", content: { AnyView(FilmAdvanceDesign()) }),
            .init(title: "Negative Strip Recap", note: "Horizontal negative strip viewer.", content: { AnyView(NegativeStripDesign()) }),
        ]),
        GallerySection(title: "Lock Screen + Widgets", entries: [
            .init(title: "Live Activity",  note: "Dynamic Island + lock-screen card · countdown to reveal.", content: { AnyView(LiveActivityPreviewDesign()) }),
            .init(title: "Home Widget",    note: "Medium + small widget layouts for in-progress rolls.",     content: { AnyView(HomeWidgetPreviewDesign()) }),
        ]),
        GallerySection(title: "Essentials", entries: [
            .init(title: "Lock Screen Push", note: "🌅 sunrise reveal notification.", content: { AnyView(LockPushDesign()) }),
            .init(title: "Terms & Privacy", note: "Plain-language summary + checkboxes.", content: { AnyView(TermsDesign()) }),
            .init(title: "Age Gate", note: "DOB picker, under-13 lockout.", content: { AnyView(AgeGateDesign()) }),
            .init(title: "Pull to Refresh", note: "'Winding film' loading state.", content: { AnyView(PullRefreshDesign()) }),
            .init(title: "Location Permission", note: "Sun illustration + 'why' copy.", content: { AnyView(LocationPermissionDesign()) }),
            .init(title: "Storage Permission", note: "Save to camera roll toggles.", content: { AnyView(StoragePermissionDesign()) }),
        ]),
    ]

    static var totalCount: Int { sections.reduce(0) { $0 + $1.entries.count } }
}

struct DesignGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var presented: GalleryEntry?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(GalleryCatalog.sections) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title.uppercased())
                                    .font(.system(size: 11, weight: .medium))
                                    .tracking(2)
                                    .foregroundStyle(Palette.gold)
                                ForEach(section.entries) { entry in
                                    Button { presented = entry } label: {
                                        entryRow(entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        Text("\(GalleryCatalog.totalCount) designs · all sample data · ports of the original wireframes")
                            .font(.system(size: 10)).italic()
                            .foregroundStyle(Palette.textTertiary)
                            .padding(.top, 12)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("design gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
                }
            }
        }
        .fullScreenCover(item: $presented) { entry in
            DesignPresenter(entry: entry)
        }
    }

    private func entryRow(_ entry: GalleryEntry) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Palette.surface)
                .frame(width: 44, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1)
                )
                .overlay(Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textTertiary))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Text(entry.note)
                    .font(.system(size: 10)).italic()
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(10)
        .background(Palette.surface.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
        .cornerRadius(6)
    }
}

struct DesignPresenter: View {
    let entry: GalleryEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            entry.content()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .padding(.top, 8)
            .padding(.leading, 12)
        }
        .preferredColorScheme(.dark)
    }
}
