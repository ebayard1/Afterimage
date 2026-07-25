import SwiftUI
import UIKit

// MARK: - ProfilePhotoCaptureView
//
// Live-camera capture for the profile picture. Always the device camera (no
// photo-library import) — opens on the front camera so it reads as a selfie,
// frames a square, captures, then lets you confirm or retake before it uploads
// to `users/{uid}/avatar.jpg` via `UserService.uploadAvatar`.

struct ProfilePhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @Environment(UserService.self) private var users
    @Environment(ToastCenter.self) private var toast

    @State private var camera = CameraController()
    @State private var usingFront = true
    @State private var captured: UIImage?
    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                // Square viewfinder / preview of the captured shot.
                GeometryReader { geo in
                    let side = min(geo.size.width, geo.size.height)
                    ZStack {
                        if let img = captured {
                            Image(uiImage: img)
                                .resizable().scaledToFill()
                                .frame(width: side, height: side)
                                .clipped()
                        } else {
                            CameraPreviewView(controller: camera)
                                .frame(width: side, height: side)
                                .clipped()
                        }
                    }
                    .frame(width: side, height: side)
                    .overlay(Rectangle().stroke(Palette.gold, lineWidth: 1.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 20)

                controls
            }
        }
        .task {
            await camera.start()
            await camera.flip(toFront: true)   // selfie by default
        }
        .onDisappear { camera.stop() }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.5)).clipShape(Circle())
            }
            .accessibilityLabel("Cancel")
            Spacer()
            Text("PROFILE PHOTO")
                .font(.custom("Bebas Neue", size: 16)).tracking(3)
                .foregroundStyle(Palette.gold)
            Spacer()
            // Balance spacer for the close button.
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
    }

    @ViewBuilder
    private var controls: some View {
        if let img = captured {
            // Confirm / retake.
            HStack(spacing: 14) {
                Button {
                    captured = nil
                } label: {
                    actionLabel("RETAKE", icon: "arrow.counterclockwise", filled: false)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)

                Button {
                    save(img)
                } label: {
                    actionLabel(isSaving ? "SAVING…" : "USE PHOTO", icon: "checkmark", filled: true)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .padding(.horizontal, 24).padding(.vertical, 28)
        } else {
            HStack {
                Spacer()
                Button(action: capture) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.6), lineWidth: 3).frame(width: 78, height: 78)
                        Circle().fill(.white).frame(width: 64, height: 64)
                    }
                }
                .buttonStyle(.plain)
                .pressEffect(scale: 0.96, lift: 1)
                .accessibilityLabel("Take profile photo")
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button {
                    usingFront.toggle()
                    Task { await camera.flip(toFront: usingFront) }
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.4)).clipShape(Circle())
                }
                .padding(.trailing, 30)
                .accessibilityLabel("Flip camera")
            }
            .padding(.vertical, 28)
        }
    }

    private func actionLabel(_ title: String, icon: String, filled: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold))
            Text(title).font(.custom("Bebas Neue", size: 17)).tracking(2)
        }
        .foregroundStyle(filled ? .black : Palette.gold)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            Capsule().fill(filled ? Palette.gold : Color.clear)
                .overlay(Capsule().stroke(filled ? .clear : Palette.gold.opacity(0.6), lineWidth: 1.5))
        )
    }

    private func capture() {
        Haptics.medium()
        Task {
            // Square crop for the avatar.
            if let img = try? await camera.capturePhoto(cropAspect: 1.0) {
                await MainActor.run { captured = img }
            } else {
                toast.error("couldn't capture — try again")
            }
        }
    }

    private func save(_ img: UIImage) {
        guard let uid = auth.uid, !isSaving else { return }
        isSaving = true
        Task {
            do {
                try await users.uploadAvatar(img, uid: uid)
                toast.success("profile photo updated")
                dismiss()
            } catch {
                isSaving = false
                toast.error("couldn't save photo")
            }
        }
    }
}
