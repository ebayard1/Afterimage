import SwiftUI
import MapKit

/// Full-screen map showing every revealed roll location as a pin. Tap a pin
/// to peek at the album name + date and jump into it.
struct RollMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var auth
    @State private var selected: Album?
    @State private var presentedAlbum: Album?
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var pins: [(album: Album, coord: CLLocationCoordinate2D)] {
        SampleData.albums.compactMap { album in
            guard album.isRevealed, let id = album.id,
                  let coord = SampleData.coordinate(forAlbumId: id) else { return nil }
            return (album, coord)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                ForEach(Array(pins.enumerated()), id: \.element.album.id) { _, pin in
                    Annotation(pin.album.name, coordinate: pin.coord) {
                        pinView(pin.album)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll))
            .ignoresSafeArea()
            .preferredColorScheme(.dark)

            topBar
                .frame(maxHeight: .infinity, alignment: .top)

            if let album = selected {
                albumCard(album)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
            } else {
                footer
                    .padding(.bottom, 28)
            }
        }
        .sheet(item: $presentedAlbum) { album in
            NavigationStack {
                AlbumDetailView(album: album)
                    .environment(auth)
            }
        }
        .onAppear {
            // Frame the pins
            if let first = pins.first {
                cameraPosition = .region(MKCoordinateRegion(
                    center: first.coord,
                    span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 60)
                ))
            }
        }
    }

    private func pinView(_ album: Album) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(Motion.cinematic) { selected = album }
        } label: {
            ZStack {
                Circle()
                    .fill(album.filmStock?.accent ?? Palette.gold)
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                Image(systemName: "film.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(album.filmStock?.isMonochrome == true ? .white : .black)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(album.name) pin")
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("ROLL MAP")
                    .font(.custom("Bebas Neue", size: 12)).tracking(3)
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(pins.count) locations")
                    .font(.custom("Menlo", size: 10)).tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.black.opacity(0.6))
            .clipShape(Capsule())
        }
        .padding(.horizontal, 14).padding(.top, 14)
    }

    private func albumCard(_ album: Album) -> some View {
        Button {
            presentedAlbum = album
        } label: {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: album.coverPhotoURL ?? "")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: ShimmerPlaceholder()
                    }
                }
                .frame(width: 64, height: 64)
                .clipped()
                .overlay(Rectangle().stroke(Palette.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(album.name.uppercased())
                        .font(.custom("Bebas Neue", size: 18)).tracking(2)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    if let loc = SampleData.location(forAlbumId: album.id ?? "") {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin").font(.system(size: 9))
                                .foregroundStyle(Palette.gold)
                            Text(loc.uppercased())
                                .font(.custom("Bebas Neue", size: 11)).tracking(1.5)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    Text(dateStamp(album))
                        .font(.custom("Menlo", size: 10)).tracking(1)
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(Palette.gold)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.gold.opacity(0.5), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .pressEffect()
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation { selected = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 10))
            Text("tap a pin to open the roll")
                .font(.system(size: 11)).italic()
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(.black.opacity(0.55))
        .clipShape(Capsule())
    }

    private func dateStamp(_ album: Album) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        return f.string(from: album.createdAt).uppercased()
    }
}
