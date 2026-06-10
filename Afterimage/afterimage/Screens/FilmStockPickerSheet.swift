import SwiftUI

/// Modal sheet to pick a FilmStock for a roll. Each option shows the stock
/// name, short code, tagline, and a tiny color swatch. Tapping commits.
struct FilmStockPickerSheet: View {
    @Binding var selection: FilmStock?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("pick your film")
                            .font(.custom("Bebas Neue", size: 22)).tracking(2)
                            .foregroundStyle(Palette.gold)
                        Text("every shot in this roll gets graded toward the chosen stock — locked once the roll starts.")
                            .font(.custom("Times New Roman", size: 12)).italic()
                            .foregroundStyle(Palette.textTertiary)
                            .padding(.bottom, 8)

                        // "no stock" option first
                        noStockRow

                        ForEach(FilmStock.allCases) { stock in
                            stockRow(stock)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("film stock")
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
    }

    private var noStockRow: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            selection = nil
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Rectangle().fill(Palette.surface)
                    Image(systemName: "minus")
                        .foregroundStyle(Palette.textTertiary)
                }
                .frame(width: 44, height: 44)
                .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text("no stock")
                        .font(.custom("Bebas Neue", size: 14)).tracking(2)
                        .foregroundStyle(Palette.textPrimary)
                    Text("native colors · no grade applied")
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                if selection == nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.gold)
                }
            }
            .padding(10)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                selection == nil ? Palette.gold : Palette.border, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .pressEffect()
    }

    private func stockRow(_ stock: FilmStock) -> some View {
        let selected = selection == stock
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            selection = stock
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Rectangle().fill(stock.accent)
                    Image(systemName: "camera.filters")
                        .foregroundStyle(stock.isMonochrome ? .black : .white.opacity(0.85))
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 44, height: 44)
                .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: 3) {
                    Text(stock.displayName.uppercased())
                        .font(.custom("Bebas Neue", size: 14)).tracking(2)
                        .foregroundStyle(Palette.textPrimary)
                    Text(stock.tagline)
                        .font(.custom("Times New Roman", size: 11)).italic()
                        .foregroundStyle(Palette.textSecondary)
                    Text(stock.shortCode)
                        .font(.custom("Menlo", size: 9)).tracking(1.5)
                        .foregroundStyle(stock.accent)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.gold)
                }
            }
            .padding(10)
            .background(Palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(
                selected ? Palette.gold : Palette.border,
                lineWidth: selected ? 1.5 : 1
            ))
        }
        .buttonStyle(.plain)
        .pressEffect()
        .accessibilityLabel(stock.displayName)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }
}
