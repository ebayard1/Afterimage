import SwiftUI
import UIKit

struct JoinAlbumView: View {
    @Environment(AuthService.self) private var auth
    @Environment(ToastCenter.self) private var toast
    @Environment(\.dismiss) private var dismiss
    /// Shared instance owned by `ContentView` — see `CreateAlbumView`.
    @Environment(AlbumService.self) private var albumService
    @State private var albumCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    Text("join album")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Palette.gold)
                        .padding(.top, 4)

                    Button { showScanner = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 22))
                                .foregroundStyle(Palette.gold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("scan a QR code")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Palette.textPrimary)
                                Text("point your camera at a friend's screen")
                                    .font(.system(size: 10)).italic()
                                    .foregroundStyle(Palette.textTertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Palette.textTertiary)
                                .font(.system(size: 12))
                        }
                        .padding(12)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.gold, lineWidth: 1.5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    HStack {
                        Rectangle().fill(Palette.border).frame(height: 1)
                        Text("or paste a code")
                            .font(.system(size: 10)).italic()
                            .foregroundStyle(Palette.textTertiary)
                        Rectangle().fill(Palette.border).frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    Text("album code")
                        .font(.system(size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                    TextField("", text: $albumCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Palette.surface)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.border, lineWidth: 1))
                        .cornerRadius(6)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.red)
                    }

                    Spacer()

                    Button { join(code: albumCode) } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Text("JOIN →")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Palette.gold)
                        .foregroundStyle(.black)
                        .cornerRadius(6)
                    }
                    .disabled(isLoading || albumCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                QRScannerView { code in
                    join(code: code)
                }
            }
        }
    }

    private func join(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            guard let uid = auth.uid else {
                errorMessage = "you must be signed in to join"
                isLoading = false
                return
            }
            do {
                guard let albumId = try await albumService.resolveInvite(code: trimmed) else {
                    errorMessage = "no roll found for that code"
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    isLoading = false
                    return
                }
                try await albumService.join(albumId: albumId, userId: uid)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                toast.success("joined the roll")
                isLoading = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                isLoading = false
            }
        }
    }
}
