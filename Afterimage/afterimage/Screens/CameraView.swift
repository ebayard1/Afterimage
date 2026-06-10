import SwiftUI
import AVFoundation
import UIKit

struct CameraView: View {
    let album: Album
    @Environment(AuthService.self) private var auth
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraController()
    @State private var shotService = ShotService()
    @State private var isUploading = false
    @State private var showConfirmation = false
    @State private var note: String = ""
    @State private var noteFocused: Bool = false
    @State private var flashOn: Bool = false
    @State private var usingFront: Bool = false
    @State private var focusIndicator: CGPoint?
    @FocusState private var noteFieldFocus: Bool
    @AppStorage("hasSeenCameraCoach") private var hasSeenCameraCoach = false
    @State private var showCameraCoach = false
    @State private var flashFlash = false
    @State private var blackOut = false
    @State private var isRecordingVoice = false
    @State private var voiceDuration: Double = 0  // 0..10
    @State private var voiceTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(controller: camera)
                .ignoresSafeArea()
                .onTapGesture { location in
                    handleTap(location)
                }

            if let p = focusIndicator {
                Circle()
                    .stroke(Palette.gold, lineWidth: 1.5)
                    .frame(width: 60, height: 60)
                    .position(p)
                    .transition(.opacity)
            }

            VStack {
                topBar
                Spacer()
                bottomControls
            }

            if showConfirmation {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(Palette.gold)
                        Text("film contributed")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.gold)
                        Text("sealed until sunrise")
                            .font(.system(size: 11)).italic()
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .transition(.opacity)
            }

            if showCameraCoach {
                CoachMarkOverlay(surface: .camera) {
                    hasSeenCameraCoach = true
                    withAnimation { showCameraCoach = false }
                }
            }

            // Shutter ritual: white flash → black-out → return.
            // The black-out is the psychological "permanence" moment — the frame is gone.
            if flashFlash {
                Color.white.ignoresSafeArea().transition(.opacity)
            }
            if blackOut {
                Color.black.ignoresSafeArea().transition(.opacity)
            }
        }
        .task {
            await camera.start()
            if let uid = auth.uid, let albumId = album.id {
                shotService.startListening(albumId: albumId, currentUserId: uid)
            }
            if !hasSeenCameraCoach {
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation { showCameraCoach = true }
            }
        }
        .onDisappear { camera.stop() }
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close camera")
            .accessibilityHint("Returns to the roll without taking a shot")
            Spacer()
            Button {
                flashOn.toggle()
                camera.setFlash(flashOn ? .on : .off)
            } label: {
                Image(systemName: flashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(flashOn ? Palette.gold : .white.opacity(0.7))
                    .padding(10)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .pressEffect()
            .accessibilityLabel(flashOn ? "Flash on" : "Flash off")
            .accessibilityHint("Toggles the camera flash")
            Button {
                usingFront.toggle()
                Task { await camera.flip(toFront: usingFront) }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.4))
                    .clipShape(Circle())
            }
            .pressEffect()
            .accessibilityLabel(usingFront ? "Switch to rear camera" : "Switch to front camera")
            Spacer()
            Text("\(shotService.myShotCount)")
                .font(.system(size: 16, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.gold)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
                .accessibilityLabel("\(shotService.myShotCount) of your shots on this roll")
        }
        .padding()
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Voice note row (only when recording or when something's been captured)
            if isRecordingVoice || voiceDuration > 0 {
                voiceNoteStrip
                    .padding(.horizontal, 24)
            }
            // Note field with inline mic button
            HStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .foregroundStyle(.white.opacity(0.6))
                TextField("", text: $note, prompt: Text("what were you doing? (optional)").foregroundStyle(.white.opacity(0.4)))
                    .focused($noteFieldFocus)
                    .foregroundStyle(.white)
                    .submitLabel(.done)
                    .onSubmit { noteFieldFocus = false }
                if !note.isEmpty {
                    Button { note = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                Button { toggleVoiceRecord() } label: {
                    Image(systemName: isRecordingVoice ? "mic.fill" : (voiceDuration > 0 ? "mic.circle.fill" : "mic"))
                        .foregroundStyle(isRecordingVoice ? Palette.red : (voiceDuration > 0 ? Palette.gold : .white.opacity(0.7)))
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain)
                .pressEffect()
                .accessibilityLabel(isRecordingVoice ? "Stop recording voice note" : "Record voice note")
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.black.opacity(0.55))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(
                isRecordingVoice ? Palette.red : .white.opacity(0.15),
                lineWidth: isRecordingVoice ? 1.5 : 1))
            .cornerRadius(18)
            .padding(.horizontal, 24)

            // Flash-charged status LED — only visible when flash is armed.
            // Pulses softly to sell the "the device is alive, the charge is
            // ready" disposable-camera metaphor.
            if flashOn {
                FlashReadyLED()
            }

            Text("NO RETAKES")
                .font(.custom("Bebas Neue", size: 14)).tracking(6)
                .foregroundStyle(Palette.gold.opacity(0.85))
                .warmthFlicker(period: 4.2, floor: 0.78)

            Button(action: capture) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.6), lineWidth: 3)
                        .frame(width: 92, height: 92)
                    Circle()
                        .stroke(Palette.gold.opacity(0.35), lineWidth: 1)
                        .frame(width: 102, height: 102)
                    Circle()
                        .fill(.white)
                        .frame(width: 74, height: 74)
                }
                .opacity(isUploading ? 0.5 : 1.0)
                .warmShadow(radius: 14, y: 6, opacity: 0.55)
            }
            .buttonStyle(.plain)
            // Per Emil: scale-on-press should sit in 0.95–0.98. 0.92 reads as
            // "the button slipped." Shutter is the most haptic moment in the
            // app — tighten the gesture so it feels deliberate, not bouncy.
            .pressEffect(scale: 0.96, lift: 1)
            .disabled(isUploading)
            .padding(.bottom, 36)
            .accessibilityLabel("Take a shot")
            .accessibilityHint("Captures a photo and seals it until reveal. No retakes.")
        }
    }

    /// Animated waveform shown above the note field while a voice note is being
    /// recorded (or after it's been captured). Sample-only — no real audio.
    private var voiceNoteStrip: some View {
        HStack(spacing: 10) {
            if isRecordingVoice {
                PulsingDot(color: Palette.red, size: 6)
                Text(String(format: "%0.1fs", voiceDuration))
                    .font(.custom("Menlo", size: 11)).tracking(1)
                    .foregroundStyle(Palette.red)
            } else {
                Image(systemName: "waveform")
                    .foregroundStyle(Palette.gold)
                Text(String(format: "voice note · %0.1fs", voiceDuration))
                    .font(.custom("Menlo", size: 11)).tracking(1)
                    .foregroundStyle(Palette.gold)
            }
            Waveform(bars: 24, isLive: isRecordingVoice, color: isRecordingVoice ? Palette.red : Palette.gold)
                .frame(maxWidth: .infinity)
            if !isRecordingVoice {
                Button {
                    voiceDuration = 0
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Discard voice note")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(.black.opacity(0.55))
        .overlay(Capsule().stroke(
            isRecordingVoice ? Palette.red : Palette.gold.opacity(0.5), lineWidth: 1))
        .clipShape(Capsule())
    }

    private func toggleVoiceRecord() {
        if isRecordingVoice {
            voiceTimer?.invalidate()
            voiceTimer = nil
            isRecordingVoice = false
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            voiceDuration = 0
            isRecordingVoice = true
            voiceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    voiceDuration += 0.1
                    if voiceDuration >= 10 {  // 10s cap (matches Afterimage's ritual brevity)
                        voiceTimer?.invalidate()
                        voiceTimer = nil
                        isRecordingVoice = false
                    }
                }
            }
        }
    }

    private func handleTap(_ location: CGPoint) {
        guard !noteFieldFocus else {
            noteFieldFocus = false
            return
        }
        camera.focus(atNormalized: location, screenSize: UIScreen.main.bounds.size)
        // Per Emil: never ease-in on UI elements — ease-in delays movement at
        // the moment the user is watching most closely, making it feel sluggish.
        // Both enter AND exit of the focus indicator use Motion.crisp (200ms
        // strong ease-out).
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
        guard !isUploading, let albumId = album.id else { return }
        isUploading = true
        let capturedNote = note
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.linear(duration: 0.06)) { flashFlash = true }
        Task {
            try? await Task.sleep(nanoseconds: 90_000_000)
            withAnimation(.linear(duration: 0.05)) {
                flashFlash = false
                blackOut = true
            }
            // Hold blackout for ~500ms — the frame is gone forever.
            try? await Task.sleep(nanoseconds: 500_000_000)

            if album.isSample {
                // Demo path — no Firebase. Append a session shot the album detail will pick up.
                SampleSessionShots.shared.add(
                    albumId: albumId, note: capturedNote, userId: "me"
                )
                note = ""
                withAnimation(Motion.crisp) { blackOut = false }
                withAnimation { showConfirmation = true }
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                withAnimation { showConfirmation = false }
                toast.success("added to the roll")
            } else if let uid = auth.uid {
                // Real (signed-in) path
                do {
                    if let image = try await camera.capturePhoto() {
                        try await shotService.upload(
                            image: image,
                            albumId: albumId,
                            userId: uid,
                            note: capturedNote
                        )
                        note = ""
                        withAnimation(Motion.crisp) { blackOut = false }
                        withAnimation { showConfirmation = true }
                        try? await Task.sleep(nanoseconds: 1_100_000_000)
                        withAnimation { showConfirmation = false }
                        toast.success("added to the roll")
                    } else {
                        withAnimation { blackOut = false }
                    }
                } catch {
                    withAnimation { blackOut = false }
                    toast.error("upload failed — try again")
                }
            } else {
                withAnimation { blackOut = false }
            }
            isUploading = false
        }
    }
}

// MARK: - Camera controller (AVFoundation wrapper)

nonisolated final class CameraController: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "afterimage.camera.session")
    private var configured = false
    private var captureContinuation: CheckedContinuation<UIImage?, Error>?
    private var currentInput: AVCaptureDeviceInput?
    private var flashMode: AVCaptureDevice.FlashMode = .off

    func start() async {
        guard await requestAccess() else { return }
        await withCheckedContinuation { cont in
            queue.async { [self] in
                if !configured { configureSession(front: false) }
                if !session.isRunning { session.startRunning() }
                cont.resume()
            }
        }
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

    func capturePhoto() async throws -> UIImage? {
        try await withCheckedThrowingContinuation { cont in
            queue.async { [self] in
                self.captureContinuation = cont
                let settings = AVCapturePhotoSettings()
                if self.output.supportedFlashModes.contains(self.flashMode) {
                    settings.flashMode = self.flashMode
                }
                self.output.capturePhoto(with: settings, delegate: self)
            }
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
        session.sessionPreset = .photo
        let position: AVCaptureDevice.Position = front ? .front : .back
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        configured = true
    }
}

extension CameraController {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        if let error {
            captureContinuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) {
            captureContinuation?.resume(returning: image)
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
