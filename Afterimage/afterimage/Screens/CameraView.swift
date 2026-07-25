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
//   • the ⚡ button              → flash toggle (4-frame press cycle)
//   • the flip-camera button    → front/back flip (2-frame press)
//   • the big bottom circle     → the shutter (black frames = photo,
//                                 red frames = video)
//   • the red LED (REC lamp)    → blinks while recording, winks on capture
//
// The shell art has flat GREEN placeholder discs where the buttons live —
// the sliced button-frame art is ALWAYS drawn on top of them (all frames in
// a column share the same outer diameter, so no green ever peeks out).
// There are NO ring/glow press indicators — the art frames ARE the states.
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
    /// Whether this camera is actually the thing the user is looking at.
    /// The tab host must pass `false` while another tab is showing: a paged
    /// TabView keeps every page mounted forever, so `onDisappear` never fires
    /// there and the capture session would otherwise run the whole time you
    /// browse the feed (the app's biggest heat source — PERF_DIAGNOSIS §1a).
    /// Defaults to `true` so the full-screen-cover call sites, where SwiftUI's
    /// own appear/disappear IS accurate, keep working unchanged.
    let isActive: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AuthService.self) private var auth
    @Environment(ToastCenter.self) private var toast
    @AppStorage("lastUsedAlbumId") private var lastUsedAlbumId: String = ""
    @State private var camera = CameraController()
    @State private var shotService = ShotService()
    @State private var isUploading = false
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
    /// Auto-stops the recording at the 30-second cap even if the finger is
    /// still down.
    @State private var recordLimitWork: DispatchWorkItem?
    /// True once this press started a recording — so a release after the
    /// 30s auto-stop doesn't fall through and fire a photo.
    @State private var pressStartedVideo = false
    /// Hard cap on a single video recording.
    static let maxVideoSeconds: TimeInterval = 30
    /// Flash press cycle: after release, the NEW state's pressed frame shows
    /// for one beat before settling on its rest frame (On-rest → On-pressed →
    /// Off-pressed → Off-rest, and the reverse when toggling back).
    @State private var flashSettleFrame: String?
    /// Shutter hold: RecordPressed shows for one beat when recording starts,
    /// then settles on the full red RecordRest face for the recording.
    @State private var recordFaceSettled = false
    /// REC lamp wink on photo capture (while recording it blinks on a timer).
    @State private var lampWink = false
    /// Optimistic floor for the frame counter: bumped the INSTANT a shot is
    /// taken, so the badge ticks immediately instead of waiting for the
    /// upload + Firestore listener round-trip. Rolled back if an upload
    /// fails; the live listener count wins whenever it catches up.
    @State private var optimisticShotCount = 0
    /// The debounced `camera.stop()`. A tab flick (camera → rolls → camera)
    /// must not churn the sensor: the stop waits ~1.5s and is cancelled if the
    /// camera comes back first, so a quick round trip is free while actually
    /// leaving the tab still shuts the session down.
    @State private var pendingStop: Task<Void, Never>?

    /// What the counter badge shows — never behind the local action.
    private var displayedShotCount: Int { max(shotService.myShotCount, optimisticShotCount) }

    /// The AVCaptureSession runs only here: on screen AND foregrounded. The
    /// session itself stays *configured* across stop/start (see
    /// `CameraController.start`), so coming back is a warm restart, not a
    /// rebuild of the inputs.
    private var shouldRun: Bool { isActive && scenePhase == .active }

    init(album: Album, showsCloseButton: Bool = false, isActive: Bool = true) {
        self.album = album
        self.showsCloseButton = showsCloseButton
        self.isActive = isActive
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
        static let screen = CGRect(x: 241, y: 368, width: 446, height: 768)
        // Button geometry: measured pixel-exactly off the artwork's green
        // placeholder discs. The green is INPAINTED OUT of the shipped
        // CameraShell asset (nearest-neighbor fill), so even a missing frame
        // shows dark panel, never green. Slices have ZERO margin — the disc
        // fills the PNG canvas — so the rendered disc diameter equals the
        // frame size exactly. Diameters run a few px past the old green
        // (d=129/129/269) to swallow its anti-aliased fringe.
        static let flashCenter = CGPoint(x: 650, y: 154)
        static let flashDiameter: CGFloat = 134
        static let flipCenter = CGPoint(x: 786, y: 154)
        static let flipDiameter: CGFloat = 134
        static let shutterCenter = CGPoint(x: 452, y: 1506)
        static let shutterDiameter: CGFloat = 276
        static let shutterRadius: CGFloat = 138            // hit-target radius
        /// REC lamp overlay — the lit red dome + glow sliced from the
        /// light-ON shell art, edges feathered 16px so the crop blends
        /// seamlessly over the shell. Lamp core ≈ (798, 1264).
        static let lampRect = CGRect(x: 683, y: 1149, width: 221, height: 233)
        /// Zoom wheel — the ridged dial on the lower right of the shell.
        /// `wheelRect` is the moving window over the STRAIGHT middle of the
        /// baked wheel; the wheel's curved ends stay static (part of the
        /// shell art) and the scrolling ridge tile feathers into them.
        /// The `WheelRidges` tile is sliced from this exact region of the
        /// shell art, so color and lighting match by construction.
        static let wheelRect = CGRect(x: 744, y: 1400, width: 72, height: 255)
        static let wheelTileHeight: CGFloat = 128   // 8 ridges, seamless loop
        static let wheelRidgePitch: CGFloat = 16    // shell px per ridge
    }

    // MARK: Zoom — the wheel and the pinch both drive one zoom factor.

    /// Current zoom (1×…5×), applied to the capture device live.
    @State private var zoomFactor: CGFloat = 1
    @State private var wheelDragStartZoom: CGFloat?
    @State private var pinchStartZoom: CGFloat?
    /// Last ridge index that fired a tick haptic.
    @State private var lastRidgeTick = 0

    private static let zoomRange: ClosedRange<CGFloat> = 1...5
    /// Shell px of wheel travel per 1.0× of zoom — one ridge per 0.1×.
    private static let travelPerZoom: CGFloat = 160

    /// Accumulated wheel travel in shell px for the current zoom.
    private var wheelTravel: CGFloat { (zoomFactor - 1) * Self.travelPerZoom }

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

                // 3. Physical controls — the sliced frame art drawn OVER the
                //    green placeholder discs. Pressing swaps to the pressed
                //    frame (no rings, no scaling — the art IS the animation).
                //    (Hidden while the alignment jig is on so the green
                //    placeholders can be read on a screenshot.)
                if !Self.showAlignmentJig {
                    // Flash: 4-frame cycle. Rest → pressed (finger down) →
                    // new state's pressed (one beat after release, via
                    // flashSettleFrame) → new state's rest.
                    frameButton(rest: flashSettleFrame ?? (flashOn ? "FlashOnRest" : "FlashOffRest"),
                                pressed: flashOn ? "FlashOnPressed" : "FlashOffPressed",
                                center: Shell.flashCenter, diameter: Shell.flashDiameter,
                                scale: s, originX: originX,
                                label: flashOn ? "Flash on" : "Flash off",
                                hint: "Toggles the camera flash") {
                        flashOn.toggle()
                        camera.setFlash(flashOn ? .on : .off)
                        flashSettleFrame = flashOn ? "FlashOnPressed" : "FlashOffPressed"
                        Task {
                            try? await Task.sleep(nanoseconds: 90_000_000)
                            flashSettleFrame = nil
                        }
                    }

                    // Flip: 2 frames — rest, pressed-in while the thumb is down.
                    frameButton(rest: "FlipRest", pressed: "FlipPressed",
                                center: Shell.flipCenter, diameter: Shell.flipDiameter,
                                scale: s, originX: originX,
                                label: usingFront ? "Switch to rear camera" : "Switch to front camera",
                                hint: "Flips between front and rear cameras") {
                        usingFront.toggle()
                        // A flip lands on a fresh device — zoom resets with it.
                        zoomFactor = 1
                        lastRidgeTick = 0
                        Task { await camera.flip(toFront: usingFront) }
                    }

                    // REC lamp: winks on for a beat on photo capture; blinks on
                    // a 2-second cycle (1s lit, 1s dark) while recording video.
                    recLamp(scale: s, originX: originX)
                }

                // Shutter: tap = photo · press-and-hold = record video. The red
                // record face replaces the shutter while holding.
                shutterControl(scale: s, originX: originX)

                // Zoom wheel — the baked dial spins as the zoom changes
                // (drag it, or pinch the viewfinder).
                zoomWheel(scale: s, originX: originX)

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
        // Non-camera setup: cheap, and must happen once when the page mounts
        // regardless of whether the sensor is allowed to run yet.
        .task {
            if let uid = auth.uid, let albumId = album.id {
                shotService.startListening(albumId: albumId, currentUserId: uid)
            }
            lastUsedAlbumId = album.id ?? ""
            if !hasSeenCameraCoach {
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation { showCameraCoach = true }
            }
        }
        // The session gate. `initial: true` covers the first appearance (in a
        // full-screen cover `shouldRun` is already true when the view mounts).
        .onChange(of: shouldRun, initial: true) { _, run in
            // Either direction cancels a stop that hasn't fired yet.
            pendingStop?.cancel()
            pendingStop = nil
            if run {
                Task { await camera.start() }
            } else {
                pendingStop = Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    guard !Task.isCancelled else { return }
                    camera.stop()
                }
            }
        }
        // Still correct for the cover presentation, where disappear DOES fire —
        // and cheap when it doesn't (the pager never removes this page).
        .onDisappear {
            pendingStop?.cancel()
            pendingStop = nil
            camera.stop()
        }
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
        }
        // Overfill the white screen cutout by ~5pt-of-shell on every side so the
        // live video spills onto the black printed bezel and NO white rim (or
        // white corner) of the cutout ever shows around the picture.
        .frame(width: box.width + 10 * s, height: box.height + 10 * s)
        .clipShape(RoundedRectangle(cornerRadius: 10 * s, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10 * s, style: .continuous))
        // REC readout lives INSIDE the glass, camcorder-style — tucked hard
        // into the top-left corner of the viewfinder so it stays out of the
        // picture while recording.
        .overlay(alignment: .topLeading) {
            if isRecording {
                recordingTimer
                    .padding(.leading, 4)
                    .padding(.top, 4)
                    .allowsHitTesting(false)
            }
        }
        .onTapGesture { location in
            handleTap(location, boxSize: CGSize(width: box.width, height: box.height))
        }
        // Pinch to zoom — drives the same factor as the wheel, so the wheel
        // visibly spins while you pinch.
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    if pinchStartZoom == nil { pinchStartZoom = zoomFactor }
                    guard let start = pinchStartZoom else { return }
                    applyZoom(start * value.magnification)
                }
                .onEnded { _ in pinchStartZoom = nil }
        )
        .position(x: box.midX, y: box.midY)
    }

    // MARK: A physical control on the shell — frame-swap art over the green
    // placeholder disc. The rest frame is ALWAYS drawn (it covers the green);
    // while the finger is down the pressed frame replaces it. The swap is
    // instant on purpose — a mechanical click, not a crossfade.
    // (Everything anchors to a fixed frame; never put a flexible shape in a
    // ButtonStyle body — one once inflated the hit area to the whole screen.)

    private func frameButton(
        rest: String, pressed: String,
        center: CGPoint, diameter: CGFloat,
        scale s: CGFloat, originX: CGFloat,
        label: String, hint: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { Color.clear }
            .buttonStyle(FrameSwapButtonStyle(rest: rest, pressed: pressed,
                                              diameter: diameter * s))
            .position(x: originX + center.x * s, y: center.y * s)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
    }

    /// The REC lamp — the lit dome sliced from the light-ON shell, dropped
    /// back at its exact rect. Photo: one wink. Video: 1s lit / 1s dark.
    @ViewBuilder
    private func recLamp(scale s: CGFloat, originX: CGFloat) -> some View {
        let lampImage = Image("RecLampOn")
            .resizable()
            .frame(width: Shell.lampRect.width * s, height: Shell.lampRect.height * s)
        Group {
            if isRecording {
                TimelineView(.periodic(from: recordStart ?? Date(), by: 1.0)) { ctx in
                    let elapsed = recordStart.map { ctx.date.timeIntervalSince($0) } ?? 0
                    // Lit on even seconds: 1s on, 1s off — a 2-second cycle.
                    lampImage.opacity(Int(max(0, elapsed)) % 2 == 0 ? 1 : 0)
                }
            } else if lampWink {
                lampImage
            }
        }
        .position(x: originX + Shell.lampRect.midX * s, y: Shell.lampRect.midY * s)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    #if DEBUG
    // MARK: Alignment jig (DEBUG) — crosshairs + rings every 4 shell px.

    @ViewBuilder
    private func alignmentJig(scale s: CGFloat, originX: CGFloat) -> some View {
        jigTarget(center: Shell.flashCenter, baseDiameter: Shell.flashDiameter,
                  color: .red, scale: s, originX: originX)
        jigTarget(center: Shell.flipCenter, baseDiameter: Shell.flipDiameter,
                  color: .green, scale: s, originX: originX)
        jigTarget(center: Shell.shutterCenter, baseDiameter: Shell.shutterDiameter,
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

    /// Which shutter frame is showing. Photo tap never reaches red:
    /// ShutterRest → ShutterPressed → ShutterRest. Hold to record runs the
    /// full column: ShutterPressed → RecordPressed (one beat) → RecordRest
    /// (steady, lamp blinking) → back to rest on release.
    private var shutterFrameName: String {
        if isRecording { return recordFaceSettled ? "RecordRest" : "RecordPressed" }
        if isPressingShutter { return "ShutterPressed" }
        return "ShutterRest"
    }

    private func shutterControl(scale s: CGFloat, originX: CGFloat) -> some View {
        let d = Shell.shutterRadius * 2 * s              // hit target
        let faceD = Shell.shutterDiameter * s            // frame art over the green disc
        return ZStack {
            // Constant invisible tap target over the shutter.
            Color.white.opacity(0.001).frame(width: d, height: d)
            // Backing disc — same insurance as the small buttons.
            Circle().fill(.black).frame(width: faceD, height: faceD)
            // The frame art is ALWAYS drawn over the shell.
            Image(shutterFrameName)
                .resizable().scaledToFit()
                .frame(width: faceD, height: faceD)
        }
        .frame(width: d, height: d)
        .contentShape(Circle())
        .position(x: originX + Shell.shutterCenter.x * s, y: Shell.shutterCenter.y * s)
        .gesture(shutterGesture())
        .accessibilityLabel(isRecording ? "Stop recording" : "Shutter")
        .accessibilityHint("Tap to take a photo. Press and hold to record a video.")
    }

    // MARK: Zoom wheel — a looping ridge tile scrolls inside a feathered
    // window over the baked wheel. The tile is cut from the shell art itself,
    // so only the ridge motion is new; the housing, curved ends, lighting and
    // +/− labels are the untouched shell underneath. (This is the classic
    // fake-3D wheel: static housing + moving texture + static edge shading.)

    private func zoomWheel(scale s: CGFloat, originX: CGFloat) -> some View {
        let w = Shell.wheelRect.width * s
        let h = Shell.wheelRect.height * s
        let tileH = Shell.wheelTileHeight * s
        // Zoom in → travel up. Offset stays in (−tileH, 0], and three stacked
        // tiles (384 shell px) always cover the 255 px window.
        let shift = -(wheelTravel * s).truncatingRemainder(dividingBy: tileH)
        return VStack(spacing: 0) {
            ForEach(0..<3) { _ in
                Image("WheelRidges")
                    .resizable()
                    .frame(width: w, height: tileH)
            }
        }
        .offset(y: shift)
        .frame(width: w, height: h, alignment: .top)
        .clipped()
        // Soft capsule mask: the moving texture fades into the baked wheel's
        // curved ends and housing shadow instead of ending on a hard line.
        .mask(
            RoundedRectangle(cornerRadius: w / 2, style: .continuous)
                .padding(.vertical, 16 * s)
                .padding(.horizontal, 2 * s)
                .blur(radius: 9 * s)
        )
        .contentShape(Rectangle())
        .position(x: originX + Shell.wheelRect.midX * s,
                  y: Shell.wheelRect.midY * s)
        .gesture(wheelDragGesture(scale: s))
        .accessibilityElement()
        .accessibilityLabel("Zoom wheel")
        .accessibilityValue(String(format: "%.1fx", zoomFactor))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: applyZoom(zoomFactor + 0.2)
            case .decrement: applyZoom(zoomFactor - 0.2)
            @unknown default: break
            }
        }
    }

    /// Drag the wheel like the real thing: up (toward +) zooms in.
    private func wheelDragGesture(scale s: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if wheelDragStartZoom == nil {
                    wheelDragStartZoom = zoomFactor
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                }
                guard let start = wheelDragStartZoom else { return }
                applyZoom(start - value.translation.height * 0.008)
            }
            .onEnded { _ in wheelDragStartZoom = nil }
    }

    /// Clamp, push to the device, spin the wheel, tick per ridge.
    private func applyZoom(_ proposed: CGFloat) {
        let clamped = min(max(proposed, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        guard clamped != zoomFactor else { return }
        zoomFactor = clamped
        camera.setZoom(clamped)
        let ridge = Int((wheelTravel / Shell.wheelRidgePitch).rounded(.down))
        if ridge != lastRidgeTick {
            lastRidgeTick = ridge
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private var recordingTimer: some View {
        TimelineView(.periodic(from: Date(), by: 0.2)) { ctx in
            let secs = recordStart.map { max(0, ctx.date.timeIntervalSince($0)) } ?? 0
            HStack(spacing: 5) {
                // Camcorder dot — blinks once a second.
                Circle().fill(.red).frame(width: 6, height: 6)
                    .opacity(Int(secs * 2) % 2 == 0 ? 1 : 0.25)
                Text("REC \(Self.timeString(min(secs, Self.maxVideoSeconds)))")
                    .font(.custom("Menlo", size: 11).weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(.black.opacity(0.45)))
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
                pressStartedVideo = false
                // Physical click the instant the shutter is pressed in.
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.8)
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
                    // A press whose recording already auto-stopped at the cap
                    // is spent — releasing must not also fire a photo.
                    guard !pressStartedVideo else { return }
                    guard !isUploading, remainingShots > 0 else { return }
                    capture()
                }
            }
    }

    private func beginRecording() {
        guard !isRecording, !isUploading, remainingShots > 0 else { return }
        isRecording = true
        pressStartedVideo = true
        // Run the red frames in sequence: RecordPressed for one beat, then
        // the full RecordRest face for the rest of the recording.
        recordFaceSettled = false
        Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            recordFaceSettled = true
        }
        recordStart = Date()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        camera.startRecording()
        // Auto-stop at the cap — releasing the shutter earlier cancels this.
        let limit = DispatchWorkItem { finishRecording() }
        recordLimitWork = limit
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxVideoSeconds, execute: limit)
    }

    private func finishRecording() {
        guard isRecording else { return }
        recordLimitWork?.cancel(); recordLimitWork = nil
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
            // Poster extraction decodes a full video frame — keep it off the
            // main thread so the shutter doesn't hitch right at release.
            let extracted = await Task.detached { [camera] in
                camera.posterFrame(from: url)
            }.value
            let poster = extracted ?? Self.blackPoster()
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
        // REC lamp winks with the shutter — lit for the flash + black-out beat.
        lampWink = true
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            lampWink = false
        }
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
                } catch {
                    optimisticShotCount = max(0, optimisticShotCount - 1)   // roll back the tick
                    toast.error(error.localizedDescription)
                    print("📸 SHOT UPLOAD ERROR:", error)
                }
            }
        }
    }
}

// MARK: - Frame-swap style — the button IS its art. Rest frame at rest,
// pressed frame while the finger is down. No rings, no scaling, no fade —
// the swap is instant, like a mechanical button. All frames in a column
// share the same outer diameter, so the green placeholder stays covered.

private struct FrameSwapButtonStyle: ButtonStyle {
    let rest: String
    let pressed: String
    let diameter: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        Image(configuration.isPressed ? pressed : rest)
            .resizable()
            .scaledToFit()
            .frame(width: diameter, height: diameter)
            // Opaque black backing disc: doubles as the constant hit target
            // and guarantees the shell under the button can never peek
            // through the art's feathered edge.
            .background(Circle().fill(.black))
            .contentShape(Circle())
            // Physical click on the way down, lighter tick on release.
            .onChange(of: configuration.isPressed) { _, pressed in
                UIImpactFeedbackGenerator(style: pressed ? .rigid : .light)
                    .impactOccurred(intensity: pressed ? 0.8 : 0.5)
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
    /// Latest run intent, owned by `queue`. `start()` has to await permission
    /// before it can touch the session, and a `stop()` can land inside that
    /// window (leave the tab while the camera is still spinning up). Without
    /// this flag the late start would win and leave the sensor running behind
    /// a page the user already left.
    private var wantsRunning = false

    func start() async {
        // Record the intent BEFORE the permission hop, so an interleaved
        // stop() can veto this start (see `wantsRunning`).
        queue.async { [self] in wantsRunning = true }
        guard await requestAccess() else { return }
        // Best-effort mic — if denied, video still records (silently).
        _ = await requestMicAccess()
        await withCheckedContinuation { cont in
            queue.async { [self] in
                guard wantsRunning else { cont.resume(); return }
                // Configure ONCE and stay configured: `stop()` only stops the
                // session, it never tears inputs down, so coming back to the
                // tab is a warm restart (~fast) rather than a full rebuild.
                if !configured { configureSession(front: false) }
                if !session.isRunning {
                    session.startRunning()
                    #if DEBUG
                    print("📷 SESSION START (configured: \(configured))")
                    #endif
                }
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
                // Same one-resume invariant as `capturePhoto`: a second
                // stopRecording() must not strand the first waiter.
                if let stale = recordContinuation {
                    recordContinuation = nil
                    stale.resume(returning: nil)
                }
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

    /// Stop the sensor WITHOUT deconfiguring — inputs/outputs stay attached so
    /// the next `start()` is a warm restart. A running session off-screen is
    /// the app's biggest heat source, so this is called whenever the camera
    /// stops being the visible page (debounced by the view).
    func stop() {
        queue.async { [self] in
            self.wantsRunning = false
            if self.session.isRunning {
                self.session.stopRunning()
                #if DEBUG
                print("📷 SESSION STOP")
                #endif
            }
        }
    }

    func setFlash(_ mode: AVCaptureDevice.FlashMode) {
        queue.async { [self] in
            self.flashMode = mode
        }
    }

    /// Set the capture device's zoom factor, clamped to what the hardware
    /// supports (capped at 6× so digital zoom never gets mushy). Applies to
    /// the live preview, photos, and video alike.
    func setZoom(_ factor: CGFloat) {
        queue.async { [self] in
            guard let device = currentInput?.device else { return }
            let clamped = min(max(factor, device.minAvailableVideoZoomFactor),
                              min(device.maxAvailableVideoZoomFactor, 6))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch { /* ignore */ }
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
                // INVARIANT: exactly one resume per continuation, and never
                // overwrite an unresumed one — a dropped continuation leaves
                // its `await` suspended forever (a hung shutter). The UI's
                // `isUploading` flag normally prevents overlapping captures;
                // this is the backstop if it ever doesn't.
                if let stale = self.captureContinuation {
                    self.captureContinuation = nil
                    stale.resume(throwing: NSError(
                        domain: "Afterimage.Camera", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "capture superseded"]
                    ))
                }
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
        // AVFoundation calls this on its OWN callback thread, while
        // `capturePhoto` sets the continuation and the pending crop/mirror on
        // `queue`. Hop onto `queue` before touching any of that state — this
        // used to be a plain cross-thread read/write of `captureContinuation`.
        // The JPEG data is captured here (the AVCapturePhoto must be read
        // inside the callback); the crop/mirror work then runs on the session
        // queue, which is off the main thread either way.
        let data = photo.fileDataRepresentation()
        queue.async { [self] in
            guard let cont = captureContinuation else { return }
            captureContinuation = nil
            if let error {
                cont.resume(throwing: error)
            } else if let data, let image = UIImage(data: data) {
                cont.resume(returning: processed(image,
                                                 aspect: pendingCropAspect,
                                                 mirror: pendingMirror))
            } else {
                cont.resume(returning: nil)
            }
        }
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
