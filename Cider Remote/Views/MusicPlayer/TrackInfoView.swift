// Made by Lumaa

import SwiftUI

struct TrackInfoView: View {
    let track: Track
    let onImageLoaded: (UIImage) -> Void
    let albumArtSize: ElementSize
    let geometry: GeometryProxy

    @Binding var isCompact: Bool

    var body: some View {
        if isCompact {
            compact
        } else {
            large
        }
    }

    @ViewBuilder
    var compact: some View {
        HStack(spacing: 16.0) {
            artwork

            VStack(alignment: .leading) {
                Text(track.title)
                    .font(.body.bold())
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    var large: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        let scale: CGFloat = isIPad ? 1.1 : 1.0  // Slightly reduced scale
        let titleFontSize: CGFloat = CGFloat.getFontSize(UIFont.preferredFont(forTextStyle: .title2)) + 8.0
        let artistFontSize: CGFloat = CGFloat.getFontSize(UIFont.preferredFont(forTextStyle: .caption1)) + 8.0

        VStack(spacing: 10 * scale) {  // Reduced spacing
            artwork

            VStack(spacing: 5 * scale) {
                Text(track.title)
                    .font(.system(size: titleFontSize * scale).bold())
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: artistFontSize * scale))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.bottom, isIPad ? 20 : 0) // use full display of iPad
        .frame(maxWidth: .infinity, alignment: .center)
        .transition(.opacity)
    }

    @ViewBuilder
    private var artwork: some View {
        let deviceFactor: CGFloat = UserDevice.shared.isPad ? 0.8 : 0.9
        let artworkSize: CGFloat = isCompact ? 65 : (UserDevice.shared.horizontalOrientation == .portrait ? geometry.size.width * deviceFactor : 250)

        AsyncImage(url: URL(string: track.artwork)) { phase in
            switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .onAppear {
                            if let uiImage = image.asUIImage() {
                                onImageLoaded(uiImage)
                            }
                        }
                case .failure:
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.gray)
                @unknown default:
                    EmptyView()
            }
        }
        .frame(width: artworkSize, height: artworkSize)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 10)
    }
}
