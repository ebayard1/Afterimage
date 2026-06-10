import SwiftUI

struct CreateAlbumView: View {
    enum Step: Int, CaseIterable { case configure, invite, share, ready }

    @Environment(AuthService.self) private var auth
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    @State private var albumService = AlbumService()

    // Form state
    @State private var step: Step = .configure
    @State private var name = ""
    @State private var durationDays = 2
    @State private var requirePresence = false
    @State private var invited: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdAlbumId: String?
    @State private var filmStock: FilmStock? = nil
    @State private var soundtrack: Soundtrack? = nil
    @State private var showFilmStockPicker = false
    @State private var showSoundtrackPicker = false

    private let durationOptions: [(label: String, days: Int, shots: Int)] = [
        ("1 DAY", 1, 12),
        ("2 DAYS", 2, 24),
        ("5 DAYS", 5, 48),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    progressBar
                    Group {
                        switch step {
                        case .configure: configureView
                        case .invite:    inviteView
                        case .share:     shareView
                        case .ready:     readyView
                        }
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .configure ? "Cancel" : "Back") {
                        if step == .configure { dismiss() }
                        else { goBack() }
                    }
                    .foregroundStyle(Palette.textTertiary)
                }
                if step == .ready {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .foregroundStyle(Palette.gold)
                    }
                }
            }
        }
    }

    private var navTitle: String {
        switch step {
        case .configure: return "new album · 1 of 4"
        case .invite:    return "invite · 2 of 4"
        case .share:     return "share QR · 3 of 4"
        case .ready:     return "ready · 4 of 4"
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.border)
                Rectangle().fill(Palette.gold)
                    .frame(width: geo.size.width * CGFloat(step.rawValue + 1) / CGFloat(Step.allCases.count))
            }
        }
        .frame(height: 3)
    }

    // MARK: - Step 1: Configure

    private var configureView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("configure album")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.gold)

                Text("album name")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                TextField("e.g. Sam's Birthday", text: $name)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Palette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.gold, lineWidth: 1.5))
                    .cornerRadius(6)

                Text("developing window")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
                HStack(spacing: 8) {
                    ForEach(durationOptions, id: \.days) { opt in
                        durationCard(opt)
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "sunrise.fill").foregroundStyle(Palette.gold).font(.system(size: 11))
                    Text("reveals at sunrise · in \(durationDays) day\(durationDays == 1 ? "" : "s")")
                        .font(.system(size: 11)).italic()
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.vertical, 6).padding(.horizontal, 10)
                .background(Palette.surface)
                .cornerRadius(4)

                presenceToggle
                    .padding(.top, 4)

                filmStockRow
                soundtrackRow

                if let errorMessage {
                    Text(errorMessage).font(.system(size: 11)).foregroundStyle(Palette.red)
                }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            nextButton(label: "NEXT: INVITE →", enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty) {
                withAnimation { step = .invite }
            }
        }
        .sheet(isPresented: $showFilmStockPicker) {
            FilmStockPickerSheet(selection: $filmStock)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSoundtrackPicker) {
            SoundtrackPickerSheet(selection: $soundtrack)
                .presentationDetents([.medium, .large])
        }
    }

    private var filmStockRow: some View {
        Button { showFilmStockPicker = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Rectangle().fill(filmStock?.accent ?? Palette.surface)
                    Image(systemName: "camera.filters")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(filmStock == nil ? Palette.textTertiary :
                                         (filmStock?.isMonochrome == true ? .black : .white))
                }
                .frame(width: 36, height: 36)
                .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text("film stock")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    Text(filmStock?.displayName ?? "no grade — native colors")
                        .font(.system(size: 11)).italic()
                        .foregroundStyle(filmStock == nil ? Palette.textTertiary : Palette.gold)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(12)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(filmStock != nil ? Palette.gold.opacity(0.4) : Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("Film stock: \(filmStock?.displayName ?? "none")")
    }

    private var soundtrackRow: some View {
        Button { showSoundtrackPicker = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    LinearGradient(
                        colors: [Palette.gold.opacity(0.3), Palette.darkRed.opacity(0.2)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(soundtrack == nil ? Palette.textTertiary : Palette.gold)
                }
                .frame(width: 36, height: 36)
                .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text("soundtrack")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    if let s = soundtrack {
                        Text("\(s.title) · \(s.artist)")
                            .font(.system(size: 11)).italic()
                            .foregroundStyle(Palette.gold)
                            .lineLimit(1)
                    } else {
                        Text("no song attached")
                            .font(.system(size: 11)).italic()
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
            }
            .padding(12)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(soundtrack != nil ? Palette.gold.opacity(0.4) : Palette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("Soundtrack: \(soundtrack?.title ?? "none")")
    }

    private func durationCard(_ opt: (label: String, days: Int, shots: Int)) -> some View {
        let selected = durationDays == opt.days
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(Motion.tap) { durationDays = opt.days }
        } label: {
            VStack(spacing: 4) {
                Text(opt.label)
                    .font(.system(size: 14, weight: .bold))
                Text("\(opt.shots) shots each")
                    .font(.system(size: 9)).italic()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(selected ? Palette.gold : Palette.textTertiary)
            .background(selected ? Palette.gold.opacity(0.1) : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? Palette.gold : Palette.border, lineWidth: 1.5)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("\(opt.label), \(opt.shots) shots each")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var presenceToggle: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(Motion.tap) { requirePresence.toggle() }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(requirePresence ? Palette.red.opacity(0.18) : Palette.surface)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 16))
                        .foregroundStyle(requirePresence ? Palette.red : Palette.textTertiary)
                }
                .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 3) {
                    Text("require presence to reveal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    Text("½ of members must scan a group QR before midnight or the reveal slips to the next sunrise")
                        .font(.system(size: 10)).italic()
                        .foregroundStyle(Palette.textTertiary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Toggle("", isOn: $requirePresence).labelsHidden().tint(Palette.red)
            }
            .padding(12)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(requirePresence ? Palette.red : Palette.border, lineWidth: 1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("Require presence to reveal")
        .accessibilityValue(requirePresence ? "On" : "Off")
        .accessibilityHint("When on, half of members must scan a group QR before midnight or reveal slips a day")
    }

    // MARK: - Step 2: Invite

    private var inviteView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("invite friends")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.gold)
                Text("\"\(name)\" · \(durationDays * 12) shots · \(durationDays)d")
                    .font(.system(size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)

                if !invited.isEmpty {
                    HStack {
                        SectionLabel(text: "ADDED (\(invited.count))", color: Palette.success)
                        Spacer()
                    }
                    VStack(spacing: 4) {
                        ForEach(SampleData.friends.filter { invited.contains($0.username) }) { f in
                            friendRow(f, isInvited: true)
                        }
                    }
                }

                if invited.count < SampleData.friends.count {
                    SectionLabel(text: "ALL FRIENDS")
                    VStack(spacing: 4) {
                        ForEach(SampleData.friends.filter { !invited.contains($0.username) }) { f in
                            friendRow(f, isInvited: false)
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            nextButton(label: invited.isEmpty ? "SKIP — SHARE QR →" : "NEXT: SHARE QR (\(invited.count)) →", enabled: true) {
                withAnimation { step = .share }
            }
        }
    }

    private func friendRow(_ f: SampleData.SampleFriend, isInvited: Bool) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(Motion.tap) {
                if isInvited { invited.remove(f.username) } else { invited.insert(f.username) }
            }
        } label: {
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: "https://picsum.photos/seed/\(f.photoSeed)/80/80")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: ShimmerPlaceholder()
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                .overlay(Circle().stroke(Palette.border, lineWidth: 1))
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(f.displayName).font(.system(size: 13, weight: .medium)).foregroundStyle(Palette.textPrimary)
                    Text(f.username).font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(isInvited ? Palette.success : .clear)
                    RoundedRectangle(cornerRadius: 4).stroke(isInvited ? Palette.success : Palette.border, lineWidth: 1.5)
                    if isInvited {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .frame(width: 20, height: 20)
            }
            .padding(10)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isInvited ? Palette.success.opacity(0.4) : Palette.border, lineWidth: 1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel("\(f.displayName), \(f.username)")
        .accessibilityValue(isInvited ? "Invited" : "Not invited")
        .accessibilityHint(isInvited ? "Removes from invite list" : "Adds to invite list")
    }

    // MARK: - Step 3: Share QR

    private var shareView: some View {
        let placeholderId = "draft-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
        return ScrollView {
            VStack(spacing: 12) {
                Text("share to invite")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.gold)
                Text("send this QR or code to anyone you want in the album")
                    .font(.system(size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
                    .multilineTextAlignment(.center)

                if let img = QRCodeGenerator.image(from: placeholderId, size: 280) {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(14)
                        .background(.white)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.gold, lineWidth: 2))
                }

                Text("\(name) · \(durationDays * 12) shots · \(durationDays)d window")
                    .font(.system(size: 11)).italic()
                    .foregroundStyle(Palette.textSecondary)

                HStack(spacing: 8) {
                    ForEach(["iMessage", "AirDrop", "Copy"], id: \.self) { label in
                        Button {
                            toast.show("\(label) (demo)")
                        } label: {
                            Text(label)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .pressEffect()
                        .accessibilityLabel("Share via \(label)")
                    }
                }
                .padding(.top, 4)

                if !invited.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("INVITED (\(invited.count))")
                            .font(.system(size: 10, weight: .medium)).tracking(2)
                            .foregroundStyle(Palette.textTertiary)
                        ForEach(SampleData.friends.filter { invited.contains($0.username) }) { f in
                            HStack(spacing: 8) {
                                AsyncImage(url: URL(string: "https://picsum.photos/seed/\(f.photoSeed)/60/60")) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFill()
                                    default: ShimmerPlaceholder()
                                    }
                                }
                                .frame(width: 22, height: 22)
                                .clipShape(Circle())
                                .accessibilityHidden(true)
                                Text(f.username)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.success)
                                Spacer()
                                Text("waiting…")
                                    .font(.system(size: 10)).italic()
                                    .foregroundStyle(Palette.textTertiary)
                            }
                        }
                    }
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let errorMessage {
                    Text(errorMessage).font(.system(size: 11)).foregroundStyle(Palette.red)
                }
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            nextButton(label: isLoading ? "" : "DONE — LOAD FILM →", enabled: !isLoading, isLoading: isLoading) {
                actuallyCreateAlbum()
            }
        }
    }

    // MARK: - Step 4: Ready

    private var readyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer().frame(height: 14)
                ZStack {
                    Circle().stroke(Palette.gold, lineWidth: 4).frame(width: 100, height: 100)
                    ForEach(0..<12, id: \.self) { i in
                        Rectangle().fill(Color(white: 0.13)).frame(width: 2, height: 6)
                            .offset(y: -46)
                            .rotationEffect(.degrees(Double(i) * 30))
                    }
                    VStack(spacing: 0) {
                        Text("\(durationDays * 12)")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(Palette.gold)
                        Text("shots")
                            .font(.system(size: 9)).italic()
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                Text(name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(1 + invited.count) member\(invited.count == 0 ? "" : "s")")
                    .font(.system(size: 11)).italic()
                    .foregroundStyle(Palette.textTertiary)
                summaryCard
                Spacer().frame(height: 80)
            }
            .padding(.horizontal, 20)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button { dismiss() } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("OPEN CAMERA")
                            .font(.custom("Bebas Neue", size: 16)).tracking(4)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.gold)
                    .cornerRadius(8)
                    .warmShadow(radius: 10, y: 6, opacity: 0.5)
                }
                .buttonStyle(.plain)
                .pressEffect(scale: 0.96, lift: 1)
                .accessibilityLabel("Open camera for \(name)")
                .accessibilityHint("Starts shooting for the new roll")
                Button { dismiss() } label: {
                    Text("done — back to feed")
                        .font(.system(size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done, back to feed")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Palette.background)
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            row("duration", "\(durationDays) day\(durationDays == 1 ? "" : "s")")
            Divider().background(Palette.border)
            row("shots each", "\(durationDays * 12)")
            Divider().background(Palette.border)
            row("reveals at", "🌅 sunrise")
            Divider().background(Palette.border)
            row("require presence", requirePresence ? "yes (½ quorum)" : "no")
            Divider().background(Palette.border)
            row("film stock", filmStock?.displayName ?? "none")
            Divider().background(Palette.border)
            row("soundtrack", soundtrack.map { "\($0.title) · \($0.artist)" } ?? "none")
            Divider().background(Palette.border)
            row("members", "\(1 + invited.count) joined")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Palette.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.border, lineWidth: 1))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 11)).italic().foregroundStyle(Palette.textTertiary)
            Spacer()
            Text(value).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.gold)
        }
        .padding(.vertical, 7)
    }

    // MARK: - Shared next button

    private func nextButton(label: String, enabled: Bool, isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.border).frame(height: 1)
            Button(action: action) {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Text(label)
                            .font(.custom("Bebas Neue", size: 16)).tracking(3)
                            .foregroundStyle(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(enabled ? Palette.gold : Palette.gold.opacity(0.4))
                .clipShape(Capsule())
                .warmShadow(radius: 8, y: 4, opacity: enabled ? 0.4 : 0.1)
            }
            .buttonStyle(.plain)
            .pressEffect()
            .disabled(!enabled)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Palette.background)
        }
    }

    private func goBack() {
        withAnimation {
            if let prev = Step(rawValue: step.rawValue - 1) { step = prev }
        }
    }

    private func actuallyCreateAlbum() {
        // Sample-only mode — no Firestore write. Walk through to Ready step.
        isLoading = true
        errorMessage = nil
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            toast.success("demo: roll would be loaded")
            withAnimation(Motion.cinematic) { step = .ready }
            isLoading = false
        }
    }
}
