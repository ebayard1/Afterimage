import SwiftUI

@Observable
@MainActor
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let kind: Kind
        enum Kind { case success, error, info }
    }

    var current: Toast?

    func show(_ message: String, kind: Toast.Kind = .info) {
        let toast = Toast(message: message, kind: kind)
        current = toast
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if self?.current?.id == toast.id {
                self?.current = nil
            }
        }
    }

    func success(_ msg: String) { show(msg, kind: .success) }
    func error(_ msg: String)   { show(msg, kind: .error) }
}

struct ToastOverlay: View {
    @Environment(ToastCenter.self) private var center

    var body: some View {
        VStack {
            if let toast = center.current {
                HStack(spacing: 10) {
                    Image(systemName: icon(for: toast.kind))
                        .foregroundStyle(color(for: toast.kind))
                    Text(toast.message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color(for: toast.kind).opacity(0.5), lineWidth: 1)
                )
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(duration: 0.3), value: center.current)
        .allowsHitTesting(false)
    }

    private func icon(for kind: ToastCenter.Toast.Kind) -> String {
        switch kind {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    private func color(for kind: ToastCenter.Toast.Kind) -> Color {
        switch kind {
        case .success: return Palette.gold
        case .error:   return Palette.red
        case .info:    return Palette.textSecondary
        }
    }
}
