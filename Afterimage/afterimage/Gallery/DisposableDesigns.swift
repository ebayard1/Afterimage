import SwiftUI

private let kodak = Color(red: 0.91, green: 0.44, blue: 0.13)

struct ContactSheetDesign: View {
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("Sam's Birthday").font(.system(size: 13)).italic().foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("14 EXP").font(.system(size: 11, design: .monospaced)).foregroundStyle(kodak)
                }
                .padding(10)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
                ZStack {
                    Rectangle().fill(kodak)
                    VStack(spacing: 3) {
                        HStack {
                            Text("AFTERIMAGE 400").font(.system(size: 9, design: .monospaced)).foregroundStyle(.black)
                            Spacer()
                            Text("DEV-2026-05").font(.system(size: 9, design: .monospaced)).foregroundStyle(.black)
                        }
                        .padding(.horizontal, 4)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3), spacing: 3) {
                            ForEach(0..<12, id: \.self) { i in
                                ZStack(alignment: .topLeading) {
                                    Rectangle().fill(Color(white: 0.07))
                                        .frame(height: 76)
                                        .overlay(
                                            RadialGradient(colors: [.clear, .black.opacity(0.5)], center: .center, startRadius: 8, endRadius: 50)
                                        )
                                    Text(String(format: "%02d", i + 1))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 3).padding(.vertical, 1)
                                        .background(kodak)
                                    HStack {
                                        Spacer()
                                        VStack {
                                            Spacer()
                                            Text(["S", "L", "M", "Y"][i % 4])
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.black)
                                                .frame(width: 12, height: 12)
                                                .background(kodak)
                                                .clipShape(Circle())
                                        }
                                    }
                                    .padding(3)
                                }
                                .overlay(Rectangle().stroke(Color(white: 0.20), lineWidth: 1))
                            }
                        }
                        HStack {
                            Text("PROCESS C-41").font(.system(size: 9, design: .monospaced)).foregroundStyle(.black)
                            Spacer()
                            Text("↓ 2 MORE").font(.system(size: 9, design: .monospaced)).foregroundStyle(.black)
                        }
                        .padding(.horizontal, 4)
                    }
                    .padding(4)
                    .background(Palette.background)
                    .padding(6)
                }
                Spacer()
            }
        }
    }
}

struct ChemicalTraysDesign: View {
    private let trays: [(label: String, status: String, color: Color, time: String, desc: String, prog: CGFloat)] = [
        ("DEVELOPER", "done", Palette.red, "✓ DONE", "images emerging from silver halide", 1.0),
        ("STOP BATH", "done", Color(red: 0.53, green: 0.25, blue: 0.06), "✓ DONE", "reaction halted, image fixed in place", 1.0),
        ("FIXER", "active", Color(red: 0.42, green: 0.42, blue: 0.06), "8:44", "removing unexposed silver…", 0.6),
    ]
    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.02, blue: 0.02).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Spacer().frame(height: 60)
                VStack(spacing: 4) {
                    Text("developing").font(.system(size: 22, weight: .semibold)).italic().foregroundStyle(Palette.red)
                    Text("Sam's Birthday · 14 shots").font(.system(size: 10)).foregroundStyle(Palette.darkRed)
                }
                .frame(maxWidth: .infinity)
                ForEach(trays, id: \.label) { t in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(t.label).font(.system(size: 12)).tracking(1).foregroundStyle(t.color)
                            Spacer()
                            Text(t.time).font(.system(size: 13, design: .monospaced)).tracking(2).foregroundStyle(t.color)
                        }
                        Text(t.desc).font(.system(size: 10)).italic().foregroundStyle(t.color.opacity(0.55))
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color(red: 0.10, green: 0.02, blue: 0.02))
                                Rectangle().fill(t.color).frame(width: geo.size.width * t.prog)
                            }
                        }
                        .frame(height: 3)
                    }
                    .padding(10)
                    .background(t.status == "active" ? t.color.opacity(0.05) : Color.clear)
                    .overlay(Rectangle().stroke(t.color, lineWidth: 1.5))
                }
                Text("wash → dry → scan → reveal")
                    .font(.system(size: 11)).italic().foregroundStyle(Palette.darkRed)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .overlay(Rectangle().stroke(Palette.darkRed, style: StrokeStyle(lineWidth: 1, dash: [3])))
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }
}

struct FlashChargeDesign: View {
    var body: some View {
        ZStack {
            Color(white: 0.03).ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                // Flash unit diagram
                ZStack {
                    Rectangle().fill(Color(white: 0.07))
                        .frame(width: 140, height: 80)
                        .overlay(Rectangle().stroke(Color(white: 0.20), lineWidth: 2))
                    // Tube
                    Capsule().fill(Color(red: 1.0, green: 0.9, blue: 0.6).opacity(0.15))
                        .frame(width: 90, height: 14)
                        .overlay(Capsule().stroke(Color(white: 0.27), lineWidth: 1))
                    // LED
                    Circle().fill(kodakOrange)
                        .frame(width: 12, height: 12)
                        .shadow(color: kodakOrange, radius: 6)
                        .offset(x: 60, y: -28)
                    VStack {
                        Spacer()
                        Text("CHARGING").font(.system(size: 11, design: .monospaced)).tracking(2).foregroundStyle(kodakOrange)
                    }
                    .frame(width: 140, height: 80)
                }
                Text("uploading shot").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                Text("sealed + committed to Sam's Birthday.\nsyncing to the group…")
                    .font(.system(size: 11)).italic().multilineTextAlignment(.center).foregroundStyle(Palette.textTertiary)
                VStack(spacing: 4) {
                    HStack {
                        Text("UPLOAD").font(.system(size: 11, design: .monospaced)).foregroundStyle(kodakOrange)
                        Spacer()
                        Text("74%").font(.system(size: 11, design: .monospaced)).foregroundStyle(kodakOrange)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color(white: 0.10)).overlay(Rectangle().stroke(Color(white: 0.17), lineWidth: 1))
                            LinearGradient(colors: [kodakOrange, Color(red: 1.0, green: 0.82, blue: 0.38)],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: geo.size.width * 0.74)
                        }
                    }
                    .frame(height: 5)
                }
                .frame(width: 220)
                Text("shot 19 of 24 · sealed until sunrise")
                    .font(.system(size: 10)).italic().foregroundStyle(Palette.textTertiary)
                Spacer()
            }
        }
    }
    private var kodakOrange: Color { Color(red: 0.91, green: 0.44, blue: 0.13) }
}

struct FilmAdvanceDesign: View {
    var body: some View {
        ZStack {
            Color(white: 0.02).ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer().frame(height: 40)
                ZStack {
                    Rectangle().fill(Color(white: 0.05))
                    RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .center, startRadius: 30, endRadius: 220)
                    // Corner brackets
                    ZStack {
                        ForEach([(top: true, left: true), (top: true, left: false),
                                 (top: false, left: true), (top: false, left: false)], id: \.left) { corner in
                            corners(top: corner.top, left: corner.left)
                        }
                    }
                    .padding(10)
                    // Exposure counter (red cellophane)
                    Text("19")
                        .font(.system(size: 18, design: .monospaced).bold()).tracking(1)
                        .foregroundStyle(Color(red: 1, green: 0.4, blue: 0.25))
                        .shadow(color: Color(red: 1, green: 0.2, blue: 0.1), radius: 4)
                        .frame(width: 32, height: 22)
                        .background(Color(red: 0.55, green: 0, blue: 0))
                        .overlay(Rectangle().stroke(Palette.red, lineWidth: 1.5))
                        .offset(x: 110, y: -90)
                    // Flash ready LED
                    HStack(spacing: 4) {
                        Circle().fill(kodak).frame(width: 8, height: 8).shadow(color: kodak, radius: 4)
                        Text("READY").font(.system(size: 11, design: .monospaced)).foregroundStyle(kodak)
                    }
                    .offset(x: -90, y: -90)
                }
                .frame(height: 240)
                // Advance wheel strip
                HStack(spacing: 0) {
                    ForEach(0..<28, id: \.self) { i in
                        Rectangle().fill(i % 3 == 0 ? Color(white: 0.27) : Color(white: 0.17))
                            .frame(width: 4, height: 8)
                            .padding(.horizontal, 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Color(white: 0.10))
                .overlay(Rectangle().fill(Color(white: 0.20)).frame(height: 1), alignment: .top)
                .overlay(Rectangle().fill(Color(white: 0.20)).frame(height: 1), alignment: .bottom)
                SprocketStrip()
                // Controls
                VStack(spacing: 10) {
                    Spacer().frame(height: 8)
                    HStack(spacing: 8) {
                        LCD(text: "f/1.8")
                        LCD(text: "1/60")
                        LCD(text: "ISO 400")
                    }
                    ZStack {
                        Circle().fill(RadialGradient(
                            colors: [Color(white: 0.40), Color(white: 0.16), Color(white: 0.10)],
                            center: .topLeading, startRadius: 5, endRadius: 40))
                            .frame(width: 64, height: 64)
                            .overlay(Circle().stroke(Color(white: 0.53), lineWidth: 3))
                        Circle().fill(RadialGradient(
                            colors: [Color(white: 0.33), Color(white: 0.10)],
                            center: .topLeading, startRadius: 4, endRadius: 28))
                            .frame(width: 44, height: 44)
                    }
                    HStack(spacing: 6) {
                        Text("advance →").font(.system(size: 9)).italic().foregroundStyle(Palette.textTertiary)
                        HStack(spacing: 1) {
                            ForEach(0..<7, id: \.self) { i in
                                Rectangle().fill(i % 2 == 0 ? Color(white: 0.16) : Color(white: 0.10))
                                    .frame(width: 4, height: 14)
                            }
                        }
                        .padding(.horizontal, 2)
                        .overlay(Rectangle().stroke(Color(white: 0.27), lineWidth: 1.5))
                    }
                    Text("NO PREVIEW · NO RETAKE")
                        .font(.system(size: 10, design: .monospaced)).tracking(2).foregroundStyle(Palette.textTertiary)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(Color(white: 0.03))
                Spacer()
            }
        }
    }
    @ViewBuilder
    private func corners(top: Bool, left: Bool) -> some View {
        let stroke: Color = .white.opacity(0.4)
        HStack {
            if left {
                VStack(spacing: 0) {
                    if top { Rectangle().fill(stroke).frame(width: 14, height: 2) }
                    Spacer(minLength: 0)
                    Rectangle().fill(stroke).frame(width: 2, height: 14)
                    if !top { Spacer(minLength: 0) }
                }
                Spacer()
            } else {
                Spacer()
                VStack(spacing: 0) {
                    if top { Rectangle().fill(stroke).frame(width: 14, height: 2) }
                    Spacer(minLength: 0)
                    Rectangle().fill(stroke).frame(width: 2, height: 14)
                    if !top { Spacer(minLength: 0) }
                }
            }
        }
        .frame(width: 180, height: 180)
    }
}

struct NegativeStripDesign: View {
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "chevron.left").foregroundStyle(Palette.textTertiary)
                    Text("Sam's Birthday").font(.system(size: 13)).italic().foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text("▶ RECAP")
                        .font(.system(size: 11, design: .monospaced)).tracking(1).foregroundStyle(Palette.red)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .overlay(Rectangle().stroke(Palette.red, lineWidth: 1))
                }
                .padding(10)
                .overlay(Rectangle().fill(Palette.border).frame(height: 1), alignment: .bottom)
                // Negative strip
                ZStack {
                    Rectangle().fill(kodak)
                    HStack(spacing: 2) {
                        ForEach(0..<6, id: \.self) { i in
                            VStack(spacing: 1) {
                                Text(String(format: "%02d", i + 1))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 1)
                                    .background(kodak)
                                ZStack {
                                    Rectangle().fill(Color(white: 0.07)).frame(height: 50)
                                    RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .center, startRadius: 6, endRadius: 30)
                                    if i == 2 { Rectangle().stroke(kodak, lineWidth: 2) }
                                }
                                Text(["S","L","M","Y","S","L"][i])
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 1)
                                    .background(kodak)
                            }
                            .overlay(Rectangle().stroke(Color(white: 0.16), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(Palette.background)
                }
                .padding(.vertical, 2)
                .background(kodak)
                // Selected frame
                ZStack {
                    Rectangle().fill(kodak)
                    Rectangle().fill(Color(white: 0.07)).padding(6)
                    RadialGradient(colors: [.clear, .black.opacity(0.5)], center: .center, startRadius: 40, endRadius: 200)
                    Text("03")
                        .font(.system(size: 11, design: .monospaced)).tracking(1).foregroundStyle(.black)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(kodak)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                    VStack(alignment: .leading, spacing: 4) {
                        Spacer()
                        HStack {
                            Circle().fill(kodak).frame(width: 16, height: 16)
                            Text("@maya · 8:22 PM").font(.system(size: 10)).italic().foregroundStyle(.white.opacity(0.75))
                        }
                        Text("\u{201C}the rooftop moment 🌙\u{201D}")
                            .font(.system(size: 12)).italic().foregroundStyle(.white)
                    }
                    .padding(14)
                    .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
                HStack {
                    Text("AFTERIMAGE 400").font(.system(size: 10, design: .monospaced)).tracking(1).foregroundStyle(.black)
                    Spacer()
                    Text("3 / 14").font(.system(size: 10, design: .monospaced)).tracking(1).foregroundStyle(.black)
                    Spacer()
                    Text("C-41").font(.system(size: 10, design: .monospaced)).tracking(1).foregroundStyle(.black)
                }
                .padding(.horizontal, 10).padding(.vertical, 2)
                .background(kodak)
                Spacer()
            }
        }
    }
    private var kodak: Color { Color(red: 0.91, green: 0.44, blue: 0.13) }
}
