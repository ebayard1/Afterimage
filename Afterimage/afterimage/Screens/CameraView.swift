import SwiftUI
import AVFoundation
import UIKit

// MARK: - CameraView — the physical camera
//
// The whole camera screen IS the device: the `CameraShell` asset (a photoreal
// point-and-shoot back) fills the available frame, top-anchored, and every
// control is the real control ON the shell:
//
//   • the white screen cutout   → the live viewfinder (video never draws
//                                 outside it — flash/black-out ritual and the
//                                 "sealed" confirmation all render inside)
//   • the ⚡ button              → flash toggle (gold glow ring when armed)
//   • the flip-camera button    → front/back flip
//   • the big bottom circle     → the shutter
//   • the red LED               → decorative power light on the shell art
//
// A Menlo frame counter (taken/total, e.g. 13/24) sits in the top-left corner
// in a small rounded black badge. One roll at a time — no roll selector.
//
// All hit-targets and the screen rect are mapped in the shell image's own
// pixel space and scaled with it, so the layout is exact at every size.
struct CameraView: View {
    let album: Album
    /// When true, show a close (✕) button — the camera is presented as a
    /// full-screen cover (e.g. from an album) where there's no tab bar to leave by.
    let showsCloseButton: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(ToastCenter.self) private var toast
    @AppStorage("lastUsedAlbumId") private var lastUsedAlbumId: String = ""
    @State private var camera = CameraController()
    @State private var shotService = ShotService()
    @State private var isUploading = false
    @State private var showConfirmation = false
    @State private var flashOn: Bool = false
    @State private var usingFront: Bool = false
    /// Focus ring position, in the viewfinder's own coordinate space.
    @State private var focusIndicator: CGPoint?
    @AppStorage("hasSeenCameraCoach") private var hasSeenCameraCoach = false
    @State private var showCameraCoach = false
    @State private var flashFlash = false
    @State private var blackOut = false
    // Video mode — press-and-hold the shutter (Snapchat-style).
    @State private var isRecording = false
    @State private var isPressingShutter = false
    @State private var recordStart: Date?
    @State private var recordHoldWork: DispatchWorkItem?
    /// Optimistic floor for the frame counter: bumped the INSTANT a shot is
    /// taken, so the badge ticks immediately instead of waiting for the
    /// upload + Firestore listener round-trip. Rolled back if an upload
    /// fails; the live listener count wins whenever it catches up.
    @State private var optimisticShotCount = 0

    /// What the counter badge shows — never behind the local action.
    private var displayedShotCount: Int { max(shotService.myShotCount, optimisticShotCount) }

    init(album: Album, showsCloseButton: Bool = false) {
        self.album = album
        self.showsCloseButton = showsCloseButton
    }

    /// Shots each member gets per roll — the "24 exposures" of the disposable.
    private let rollCapacity = 24

    /// DEBUG calibration overlay: draws crosshair + reference rings at the
    /// Shell map's button coordinates (ring pitch 4 shell px) so the baked
    /// buttons' true centers/diameters can be read off a live screen capture.
    /// MUST be false for normal use.
    static let showAlignmentJig = false

    // MARK: Shell map — everything in the 904×1740 pixel space of the
    // `CameraShell` asset. Measured off the artwork itself. This art is
    // full-bleed (content reaches all four edges — no transparent margin),
    // so `body` fits it to the screen width with no overfill or nudge.
    private enum Shell {
        static let size = CGSize(width: 904, height: 1740)
        /// The white screen cutout the viewfinder lives in.
        static let screen = CGRect(x: 241, y: 368, width: 446, height: 769)
        // Button geometry below was circle-fitted to the baked-in buttons'
        // rim rings in the artwork (and verified visually against overlay
        // renders) — centers are the rings' centers, diameters span the full
        // button including its bezel, so the sliced button art drops exactly
        // on top of the printed button.
        // Diameters calibrated on-device with the DEBUG alignment jig
        // (see showAlignmentJig): the jig's reference rings were compared to
        // the baked buttons on a live screen capture.
        // Sized/positioned to fully COVER the baked buttons including their
        // bottom drop-shadow skirts (art-vs-art shading differs, so the
        // overlay must swallow the printed button entirely or the baked art
        // peeks out below). Calibrated against live device captures.
        static let flashCenter = CGPoint(x: 649, y: 162)
        static let flashDiameter: CGFloat = 136
        // Flip shows the baked button at rest (press reveals the sliced art
        // scaled down), so its center is the BAKED button's ring-fit center.
        static let flipCenter = CGPoint(x: 781, y: 146)
        static let flipDiameter: CGFloat = 112
        static let controlRadius: CGFloat = 62          // hit-target radius
        static let shutterCenter = CGPoint(x: 465, y: 1505)
        static let shutterRadius: CGFloat = 126         // hit target: full ring stack
        /// RecordFace overlay: covers the shutter face + inner rings.
        static let recordFaceDiameter: CGFloat = 224
    }

    var body: some View {
        GeometryReader { geo in
            // Scale the shell to the FULL screen width, TOP-anchored — its top
            // edge touches the very top of the screen (the top safe area is
            // ignored below) and its sides touch the screen edges. The art is
            // full-bleed, so it fits the width exactly — no overfill, no nudge.
            let s = geo.size.width / Shell.size.width
            let shellW = Shell.size.width * s
            let shellH = Shell.size.height * s
            let originX = (geo.size.width - shellW) / 2
            let box = CGRect(
                x: originX + Shell.screen.minX * s,
                y: Shell.screen.minY * s,
                width: Shell.screen.width * s,
                height: Shell.screen.height * s
            )

            ZStack(alignment: .topLeading) {
                // 1. The device shell itself.
                Image("CameraShell")
                    .resizable()
                    .frame(width: shellW, height: shellH)
                    .offset(x: originX, y: 0)
                    .accessibilityHidden(true)

                // 2. The live viewfinder — clipped to the white screen cutout,
                // inset a hair so the printed bezel stays visible. Everything
                // that happens to the picture (focus ring, shutter ritual,
                // sealed confirmation) happens INSIDE this box, never outside.
                viewfinder(box: box, scale: s)

                // DEBUG alignment jig — draws calibration rings at the Shell
                // map coordinates so the baked buttons' true positions can be
                // read off a live screen capture. Ring pitch = 4 shell px.
                #if DEBUG
                if Self.showAlignmentJig {
                    alignmentJig(scale: s, originX: originX)
                }
                #endif

                // 3. Physical controls — the sliced button art overlaid on the
                //    shell so they can animate. Flash swaps its glyph on/off; a
                //    white ring pops up while a control is pressed. (Hidden
                //    while the alignment jig is on so the baked buttons show.)
                if !Self.showAlignmentJig {
                    controlButton(image: flashOn ? "FlashOn" : "FlashOff",
                                  center: Shell.flashCenter, diameter: Shell.flashDiameter,
                                  scale: s, originX: originX,
                                  label: flashOn ? "Flash on" : "Flash off",
                                  hint: "Toggles the camera flash") {
                        flashOn.toggle()
                        camera.setFlash(flashOn ? .on : .off)
                    }

                    // Flip: the BAKED button is the resting look; while the
                    // thumb is down, the sliced FlipButton art appears SCALED
                    // DOWN — the art itself is the "pressed in" state.
                    pressRevealButton(image: "FlipButton",
                                      center: Shell.flipCenter, diameter: Shell.flipDiameter,
                                      scale: s, originX: originX,
                                      label: usingFront ? "Switch to rear camera" : "Switch to front camera",
                                      hint: "Flips between front and rear cameras") {
                        usingFront.toggle()
                        Task { await camera.flip(toFront: usingFront) }
                    }
                }

                // Shutter: tap = photo · press-and-hold = record video. The red
                // record face replaces the shutter while holding.
                shutterControl(scale: s, originX: originX)

                // Recording timer pill, above the shutter while recording.
                if isRecording {
                    recordingTimer
                        .position(x: originX + Shell.shutterCenter.x * s,
                                  y: Shell.shutterCenter.y * s - Shell.shutterRadius * s - 24)
                }

                // Frame counter — vertically CENTRED on the flash button (its
                // centre is Shell.flashCenter.y in shell space), pinned to the
                // left. `.position` centres the badge on that exact line, so its
                // middle lines up with the flash button. The ✕ (cover mode only)
                // sits to its right on the same line.
                counterBadge
                    .position(x: 86, y: Shell.flashCenter.y * s)
                if showsCloseButton {
                    closeButton
                        .position(x: 180, y: Shell.flashCenter.y * s)
                }

                if showCameraCoach {
                    CoachMarkOverlay(surface: .camera) {
                        hasSeenCameraCoach = true
                        withAnimation { showCameraCoach = false }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        // The shell art runs under the status bar so its top edge touches the
        // very top of the screen.
        .ignoresSafeArea(edges: .top)
        .task {
            await camera.start()
            if let uid = auth.uid, let albumId = album.id {
                shotService.startListening(albumId: albumId, currentUserId: uid)
            }
            lastUsedAlbumId = album.id ?? ""
            if !hasSeenCameraCoach {
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation { showCameraCoach = true }
            }
        }
        .onDisappear { camera.stop() }
    }

    private var remainingShots: Int { max(0, rollCapacity - displayedShotCount) }

    // MARK: Top-left chrome — the frame counter in a small rounded black
    // badge, plus the close button when presented as a full-screen cover.

    /// Phosphor green used for the frame counter and its glow.
    private let counterGreen = Color(red: 0.36, green: 0.96, blue: 0.46)

    private var counterBadge: some View {
        Text("\(displayedShotCount)/\(rollCapacity)")
            .font(.custom("Menlo", size: 28).weight(.bold))
            .tracking(2)
            .foregroundStyle(counterGreen)
            .warmthFlicker(period: 4.6, floor: 0.85)
            // Green glow — a soft double bloom radiating off the digits.
            .shadow(color: counterGreen.opacity(0.9), radius: 7)
            .shadow(color: counterGreen.opacity(0.55), radius: 15)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black))
            .accessibilityLabel("\(displayedShotCount) of \(rollCapacity) shots taken on this roll")
    }

    private var closeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            camera.stop()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(9)
                .background(.black.opacity(0.45))
                .clipShape(Circle())
        }
        .pressEffect()
        .accessibilityLabel("Close camera")
    }

    // MARK: Viewfinder — everything visual stays inside the white box.

    private func viewfinder(box: CGRect, scale s: CGFloat) -> some View {
        ZStack {
            CameraPreviewView(controller: camera)

            if let p = focusIndicator {
                Circle()
                    .stroke(Palette.gold, lineWidth: 1.5)
                    .frame(width: 54, height: 54)
                    .position(p)
                    .transition(.opacity)
            }

            // Shutter ritual: white flash → black-out → return, all inside the
            // viewfinder glass. The black-out is the "permanence" moment.
            if flashFlash { Color.white.transition(.opacity) }
            if blackOut { Color.black.transition(.opacity) }

            if showConfirmation {
                ZStack {
                    Color.black.opacity(0.85)
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 36))
                            .foregroundStyle(Palette.gold)
                        Text("film contributed")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Palette.gold)
                        Text("sealed until sunrise")
                            .font(.system(size: 11)).italic()
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .transition(.opacity)
                // Don't swallow taps — the shutter is already re-armed.
                .allowsHitTesting(false)
            }
        }
        // Overfill the white screen cutout by ~5pt-of-shell on every side so the
        // live video spills onto the black printed bezel and NO white rim (or
        // white corner) of the cutout ever shows around the picture.
        .frame(width: box.width + 10 * s, height: box.height + 10 * s)
        .clipShape(RoundedRectangle(cornerRadius: 10 * s, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10 * s, style: .continuous))
        .onTapGesture { location in
            handleTap(location, boxSize: CGSize(width: box.width, height: box.height))
        }
        .position(x: box.midX, y: box.midY)
    }

    // MARK: A physical control on the shell — the sliced button art overlaid on
    // the baked-in button, with a white "pop" ring while pressed.

    /// A control whose RESTING look is the baked-in button on the shell art.
    /// While pressed, the sliced button art appears scaled DOWN — the art is
    /// the "pressed in" state. (Everything anchors to the label's fixed frame;
    /// never put a flexible shape in the style — one once inflated the hit
    /// area to the whole screen.)
    private func pressRevealButton(
        image: String, center: CGPoint, diameter: CGFloat,
        scale s: CGFloat, originX: CGFloat,
        label: String, hint: String, action: @escaping () -> Void
    ) -> some View {
        let d = diameter * s
        return Button(action: action) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: d, height: d)
        }
        .buttonStyle(PressRevealButtonStyle())
        .position(x: originX + center.x * s, y: center.y * s)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }

    private func controlButton(
        image: String, center: CGPoint, diameter: CGFloat,
        scale s: CGFloat, originX: CGFloat,
        label: String, hint: String, action: @escaping () -> Void
    ) -> some View {
        let d = diameter * s
        return Button(action: action) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(width: d, height: d)
        }
        .buttonStyle(ControlButtonStyle(ringDiameter: d * 1.02))
        .position(x: originX + center.x * s, y: center.y * s)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
    }

    #if DEBUG
    // MARK: Alignment jig (DEBUG) — crosshairs + rings every 4 shell px.

    @ViewBuilder
    private func alignmentJig(scale s: CGFloat, originX: CGFloat) -> some View {
        jigTarget(center: Shell.flashCenter, baseDiameter: Shell.flashDiameter,
                  color: .red, scale: s, originX: originX)
        jigTarget(center: Shell.flipCenter, baseDiameter: Shell.flipDiameter,
                  color: .green, scale: s, originX: originX)
        jigTarget(center: Shell.shutterCenter, baseDiameter: Shell.recordFaceDiameter,
                  color: .cyan, scale: s, originX: originX)
    }

    private func jigTarget(center: CGPoint, baseDiameter: CGFloat, color: Color,
                           scale s: CGFloat, originX: CGFloat) -> some View {
        ZStack {
            // Reference rings at base radius −8…+8 shell px, pitch 4. The base
            // ring is drawn heavier so it's unambiguous in a capture.
            ForEach([-8, -4, 0, 4, 8], id: \.self) { off in
                Circle()
                    .stroke(color.opacity(off == 0 ? 1.0 : 0.55),
                            lineWidth: off == 0 ? 2 : 0.7)
                    .frame(width: (baseDiameter + CGFloat(off) * 2) * s,
                           height: (baseDiameter + CGFloat(off) * 2) * s)
            }
            // Crosshair through the mapped center.
            Rectangle().fill(color).frame(width: (baseDiameter + 40) * s, height: 1)
            Rectangle().fill(color).frame(width: 1, height: (baseDiameter + 40) * s)
        }
        .position(x: originX + center.x * s, y: center.y * s)
        .allowsHitTesting(false)
    }
    #endif

    // MARK: Shutter — tap = photo, press-and-hold = record video.

    private func shutterControl(scale s: CGFloat, originX: CGFloat) -> some View {
        let d = Shell.shutterRadius * 2 * s              // hit target: full ring stack
        let faceD = Shell.recordFaceDiameter * s          // red face: face + inner rings
        return ZStack {
            // Constant invisible tap target over the baked shutter.
            Color.white.opacity(0.001).frame(width: d, height: d)
            if isRecording {
                // Recording: red face full-size with the pulsing ring.
                Image("RecordFace")
                    .resizable().scaledToFit()
                    .frame(width: faceD, height: faceD)
                RecordingRing(diameter: d * 1.02)
            } else if isPressingShutter {
                // Pressed (photo): the shutter itself pushes inward. The
                // overlay is the shutter disc sliced from the SHELL ART, so
                // it's pixel-identical to the baked button — red is video-only.
                Image("ShutterFace")
                    .resizable().scaledToFit()
                    .frame(width: d, height: d)
                    .scaleEffect(0.92)
            }
        }
        .animation(.easeOut(duration: 0.1), value: isPressingShutter)
        .animation(.easeOut(duration: 0.12), value: isRecording)
        .frame(width: d, height: d)
        .contentShape(Circle())
        .position(x: originX + Shell.shutterCenter.x * s, y: Shell.shutterCenter.y * s)
        .gesture(shutterGesture())
        .accessibilityLabel(isRecording ? "Stop recording" : "Shutter")
        .accessibilityHint("Tap to take a photo. Press and hold to record a video.")
    }

    private var recordingTimer: some View {
        TimelineView(.periodic(from: Date(), by: 0.2)) { ctx in
            let secs = recordStart.map { max(0, ctx.date.timeIntervalSince($0)) } ?? 0
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 8, height: 8)
                Text(Self.timeString(secs))
                    .font(.custom("Menlo", size: 13).weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(.black.opacity(0.6)))
        }
        .transition(.opacity)
    }

    private static func timeString(_ secs: TimeInterval) -> String {
        let s = Int(secs)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func shutterGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPressingShutter else { return }
                isPressingShutter = true
                guard !isUploading, remainingShots > 0 else { return }
                // Hold past this threshold → start recording. A quicker release
                // is a plain photo tap.
                let work = DispatchWorkItem { beginRecording() }
                recordHoldWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
            }
            .onEnded { _ in
                isPressingShutter = false
                recordHoldWork?.cancel(); recordHoldWork = nil
                if isRecording {
                    finishRecording()
                } else {
                    guard !isUploading, remainingShots > 0 else { return }
                    capture()
                }
            }
    }

    private func beginRecording() {
        guard !isRecording, !isUploading, remainingShots > 0 else { return }
        withAnimation(Motion.crisp) { isRecording = true }
        recordStart = Date()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        camera.startRecording()
    }

    private func finishRecording() {
        guard isRecording else { return }
        withAnimation(Motion.crisp) { isRecording = false }
        recordStart = nil
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        let wasFirst = displayedShotCount == 0
        // Counter ticks immediately for videos too — rolled back on failure.
        optimisticShotCount = displayedShotCount + 1
        isUploading = true
        Task {
            let url = await camera.stopRecording()
            isUploading = false
            guard let url else {
                optimisticShotCount = max(0, optimisticShotCount - 1)
                toast.error("couldn't save that video")
                return
            }
            guard let albumId = album.id, let uid = auth.uid else { return }
            let poster = camera.posterFrame(from: url) ?? Self.blackPoster()
            // Background upload — never blocks the next shot.
            Task {
                var place: (latitude: Double, longitude: Double, name: String?)?
                if wasFirst { place = await LocationService.shared.currentPlace() }
                do {
                    try await shotService.uploadVideo(
                        fileURL: url, poster: poster, albumId: albumId, userId: uid,
                        note: "", latitude: place?.latitude, longitude: place?.longitude,
                        locationName: place?.name
                    )
                    toast.success("added to the roll")
                } catch {
                    optimisticShotCount = max(0, optimisticShotCount - 1)   // roll back the tick
                    toast.error(error.localizedDescription)
                    print("🎥 VIDEO UPLOAD ERROR:", error)
                }
            }
        }
    }

    /// Fallback poster if first-frame extraction fails — a plain black still so
    /// the upload still succeeds and the frame reads as an (unopened) negative.
    private static func blackPoster() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 108, height: 192)).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 108, height: 192))
        }
    }

    private func handleTap(_ location: CGPoint, boxSize: CGSize) {
        camera.focus(atNormalized: location, screenSize: boxSize)
        // Per Emil: never ease-in on UI elements — ease-in delays movement at
        // the moment the user is watching most closely, making it feel sluggish.
        withAnimation(Motion.crisp) {
            focusIndicator = location
        }
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(Motion.crisp) {
                focusIndicator = nil
            }
        }
    }

    private func capture() {
        guard !isUploading, let albumId = album.id, let uid = auth.uid else { return }
        isUploading = true
        // Only the FIRST shot of a roll stamps GPS (read now, on the main actor,
        // before the work hops to the background).
        let isFirstShot = displayedShotCount == 0
        // Counter ticks the INSTANT the shutter fires — rolled back on failure.
        optimisticShotCount = displayedShotCount + 1
        // Camera-like haptic: a crisp mechanical click, then a lighter
        // "film advance" clack right behind it.
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8)
        }
        withAnimation(.linear(duration: 0.06)) { flashFlash = true }
        Task {
            try? await Task.sleep(nanoseconds: 90_000_000)
            withAnimation(.linear(duration: 0.05)) {
                flashFlash = false
                blackOut = true
            }
            // Brief black-out — the "frame is gone" beat. Kept short so the next
            // shot is available almost immediately.
            try? await Task.sleep(nanoseconds: 320_000_000)

            // Capture + crop to exactly what the viewfinder framed — the white
            // screen box's aspect, not the phone screen's.
            let boxAspect = Shell.screen.width / Shell.screen.height
            let captured = try? await camera.capturePhoto(cropAspect: boxAspect)

            // Re-arm the shutter the INSTANT the frame is in hand. The upload
            // (location + storage + Firestore) runs in the background below and
            // never gates the next shot — shoot as fast as you can tap.
            withAnimation(Motion.crisp) { blackOut = false }
            isUploading = false

            guard let image = captured else {
                optimisticShotCount = max(0, optimisticShotCount - 1)   // roll back the tick
                toast.error("couldn't capture that frame")
                return
            }

            // Light, non-blocking confirmation flourish (does not block tapping
            // the shutter again — see `.allowsHitTesting(false)` on the overlay).
            withAnimation { showConfirmation = true }
            Task {
                try? await Task.sleep(nanoseconds: 650_000_000)
                withAnimation { showConfirmation = false }
            }

            // Background upload. Each shot uploads independently; rapid-fire
            // shots simply enqueue more concurrent uploads.
            Task {
                var place: (latitude: Double, longitude: Double, name: String?)?
                if isFirstShot {
                    place = await LocationService.shared.currentPlace()
                }
                do {
                    try await shotService.upload(
                        image: image,
                        albumId: albumId,
                        userId: uid,
                        note: "",
                        latitude: place?.latitude,
                        longitude: place?.longitude,
                        locationName: place?.name
                    )
                    toast.success("added to the roll")
                } catch {
                    optimisticShotCount = max(0, optimisticShotCount - 1)   // roll back the tick
                    toast.error(error.localizedDescription)
                    print("📸 SHOT UPLOAD ERROR:", error)
                }
            }
        }
    }
}

// MARK: - Press-reveal style — nothing at rest (the baked art shows through);
// the label art appears scaled down while pressed. No ring — the smaller art
// alone reads as the press.

private struct PressRevealButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 1 : 0)
            // Constant, label-sized invisible hit target (transparent views
            // don't hit-test on their own).
            .background(Circle().fill(Color.white.opacity(0.001)))
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Control button style — a white "pop" ring while pressed

private struct ControlButtonStyle: ButtonStyle {
    let ringDiameter: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.95 : 0), lineWidth: 2.5)
                    .frame(width: ringDiameter, height: ringDiameter)
                    .shadow(color: .white.opacity(configuration.isPressed ? 0.7 : 0), radius: 6)
            }
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Recording ring — pulsing halo around the shutter while recording

private struct RecordingRing: View {
    let diameter: CGFloat
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let pulse = (sin(t * 4) + 1) / 2
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 3)
                .frame(width: diameter, height: diameter)
                .shadow(color: Color.red.opacity(0.6 + 0.4 * pulse), radius: 6 + 6 * pulse)
                .opacity(0.75 + 0.25 * pulse)
        }
    }
}

// MARK: - Camera controller (AVFoundation wrapper)

nonisolated final class CameraController: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    /// Video (movie) recording output for the press-and-hold video mode.
    private let movieOutput = AVCaptureMovieFileOutput()
    private var audioInput: AVCaptureDeviceInput?
    /// Resumed when a recording finishes writing — carries the local .mov URL.
    private var recordContinuation: CheckedContinuation<URL?, Never>?
    private let queue = DispatchQueue(label: "afterimage.camera.session")
    private var configured = false
    private var captureContinuation: CheckedContinuation<UIImage?, Error>?
    private var currentInput: AVCaptureDeviceInput?
    private var flashMode: AVCaptureDevice.FlashMode = .off
    private var isFront = false
    /// Aspect (width ÷ height) the captured frame is center-cropped to, so the
    /// saved photo matches exactly what the full-screen preview showed.
    private var pendingCropAspect: CGFloat = 0
    private var pendingMirror = false

    func start() async {
        guard await requestAccess() else { return }
        // Best-effort mic — if denied, video still records (silently).
        _ = await requestMicAccess()
        await withCheckedContinuation { cont in
            queue.async { [self] in
                if !configured { configureSession(front: false) }
                if !session.isRunning { session.startRunning() }
                cont.resume()
            }
        }
    }

    private func requestMicAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    // MARK: Video recording (press-and-hold on the shutter)

    /// Begin recording a movie to a temp file. Safe to call repeatedly.
    /// Attaches the microphone for the duration of the recording only — a
    /// permanently-hot mic pins iOS's "mic in use" pill over the island.
    func startRecording() {
        queue.async { [self] in
            guard !movieOutput.isRecording else { return }
            if audioInput == nil,
               let mic = AVCaptureDevice.default(for: .audio),
               let micInput = try? AVCaptureDeviceInput(device: mic),
               session.canAddInput(micInput) {
                session.beginConfiguration()
                session.addInput(micInput)
                session.commitConfiguration()
                audioInput = micInput
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            if let conn = movieOutput.connection(with: .video) {
                if conn.isVideoRotationAngleSupported(90) { conn.videoRotationAngle = 90 }
                if conn.isVideoMirroringSupported { conn.isVideoMirrored = isFront }
            }
            movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    /// Detach the microphone once a recording ends, dismissing the system's
    /// mic-in-use indicator. Runs on the session queue.
    private func detachAudio() {
        guard let micInput = audioInput else { return }
        session.beginConfiguration()
        session.removeInput(micInput)
        session.commitConfiguration()
        audioInput = nil
    }

    /// Stop recording and return the finished .mov URL (nil if not recording or
    /// the write failed).
    func stopRecording() async -> URL? {
        await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            queue.async { [self] in
                guard movieOutput.isRecording else { cont.resume(returning: nil); return }
                recordContinuation = cont
                movieOutput.stopRecording()
            }
        }
    }

    var isRecording: Bool { movieOutput.isRecording }

    /// Extract the first frame of a recorded movie as the poster still.
    func posterFrame(from url: URL) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 1080, height: 1920)
        let t = CMTime(value: 1, timescale: 30)
        guard let cg = try? gen.copyCGImage(at: t, actualTime: nil) else { return nil }
        return UIImage(cgImage: cg)
    }

    func stop() {
        queue.async { [self] in
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func setFlash(_ mode: AVCaptureDevice.FlashMode) {
        queue.async { [self] in
            self.flashMode = mode
        }
    }

    func flip(toFront: Bool) async {
        await withCheckedContinuation { cont in
            queue.async { [self] in
                self.session.beginConfiguration()
                if let current = self.currentInput {
                    self.session.removeInput(current)
                    self.currentInput = nil
                }
                let position: AVCaptureDevice.Position = toFront ? .front : .back
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                    self.currentInput = input
                    self.isFront = toFront
                }
                self.session.commitConfiguration()
                cont.resume()
            }
        }
    }

    func focus(atNormalized point: CGPoint, screenSize: CGSize) {
        guard screenSize.width > 0, screenSize.height > 0 else { return }
        // Convert UIKit point (origin top-left) to AVCapture device coordinates (0..1, origin top-left in portrait)
        let normalized = CGPoint(
            x: max(0, min(1, point.x / screenSize.width)),
            y: max(0, min(1, point.y / screenSize.height))
        )
        queue.async { [self] in
            guard let device = self.currentInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = normalized
                    if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = normalized
                    if device.isExposureModeSupported(.autoExpose) {
                        device.exposureMode = .autoExpose
                    }
                }
                device.unlockForConfiguration()
            } catch { /* ignore */ }
        }
    }

    /// Capture a still and center-crop it to `cropAspect` (width ÷ height) so the
    /// saved photo matches what the full-screen preview framed — the preview uses
    /// `resizeAspectFill`, which hides the rest of the 4:3 sensor frame.
    func capturePhoto(cropAspect: CGFloat) async throws -> UIImage? {
        try await withCheckedThrowingContinuation { cont in
            queue.async { [self] in
                self.captureContinuation = cont
                self.pendingCropAspect = cropAspect
                self.pendingMirror = self.isFront
                let settings = AVCapturePhotoSettings()
                if self.output.supportedFlashModes.contains(self.flashMode) {
                    settings.flashMode = self.flashMode
                }
                self.output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    /// Bakes orientation into pixels, center-crops to `aspect`, optionally mirrors
    /// (front camera, to match the mirrored preview).
    private func processed(_ image: UIImage, aspect: CGFloat, mirror: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true

        // 1. Normalize orientation so we can crop in display space.
        let upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }

        // 2. Center-crop to the target aspect.
        var result = upright
        if aspect > 0, let cg = upright.cgImage {
            let w = CGFloat(cg.width), h = CGFloat(cg.height)
            let imgAspect = w / h
            let crop: CGRect
            if imgAspect > aspect {
                let newW = (h * aspect).rounded()
                crop = CGRect(x: ((w - newW) / 2).rounded(), y: 0, width: newW, height: h)
            } else {
                let newH = (w / aspect).rounded()
                crop = CGRect(x: 0, y: ((h - newH) / 2).rounded(), width: w, height: newH)
            }
            if let cropped = cg.cropping(to: crop) {
                result = UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
            }
        }

        // 3. Mirror front-camera shots to match the preview.
        guard mirror else { return result }
        return UIGraphicsImageRenderer(size: result.size, format: format).image { ctx in
            ctx.cgContext.translateBy(x: result.size.width, y: 0)
            ctx.cgContext.scaleBy(x: -1, y: 1)
            result.draw(in: CGRect(origin: .zero, size: result.size))
        }
    }

    private func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private func configureSession(front: Bool) {
        session.beginConfiguration()
        // `.high` supports BOTH photo stills and movie recording on the same
        // session (the `.photo` preset can't add a movie output). Photo quality
        // stays plenty for the film-strip frames.
        session.sessionPreset = .high
        let position: AVCaptureDevice.Position = front ? .front : .back
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
            isFront = front
        }
        // NOTE: the microphone is deliberately NOT attached here. A hot mic
        // makes iOS pin the expanded "mic in use" pill over the Dynamic
        // Island the whole time the camera page is open. The audio input is
        // attached only for the duration of a video recording (see
        // startRecording / detachAudio).
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        session.commitConfiguration()
        configured = true
    }
}

extension CameraController {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        queue.async { [self] in
            detachAudio()   // drop the mic-in-use indicator as soon as we stop
            let cont = recordContinuation
            recordContinuation = nil
            if let error {
                print("🎥 VIDEO RECORD ERROR:", error.localizedDescription)
                cont?.resume(returning: nil)
            } else {
                cont?.resume(returning: outputFileURL)
            }
        }
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        if let error {
            captureContinuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) {
            let cropped = processed(image, aspect: pendingCropAspect, mirror: pendingMirror)
            captureContinuation?.resume(returning: cropped)
        } else {
            captureContinuation?.resume(returning: nil)
        }
        captureContinuation = nil
    }
}

// MARK: - SwiftUI bridge for the preview layer

struct CameraPreviewView: UIViewRepresentable {
    let controller: CameraController

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = controller.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
