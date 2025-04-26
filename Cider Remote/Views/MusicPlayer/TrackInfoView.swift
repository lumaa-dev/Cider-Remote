// Made by Lumaa

import SwiftUI

struct TrackInfoView: View {
    let track: Track
    let onImageLoaded: (UIImage) -> Void
    let albumArtSize: ElementSize
    let geometry: GeometryProxy

    var body: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let scale: CGFloat = isIPad ? 1.1 : 1.0  // Slightly reduced scale
        
        VStack(spacing: 10 * scale) {  // Reduced spacing
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
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: artworkSize, height: artworkSize)  // Remove scale from here
            .cornerRadius(8)
            .shadow(radius: 10)

            VStack(spacing: 5 * scale) {  // Reduced spacing
                Text(track.title)
                    .font(.system(size: titleFontSize * scale))
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: artistFontSize * scale))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: geometry.size.width * (isIPad ? 0.7 : 0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, isIPad ? 20 : 0)  // Add padding at the bottom
    }

    private var artworkSize: CGFloat {
        switch albumArtSize {
            case .small: return min(geometry.size.width * 0.6, 200)
            case .medium: return min(geometry.size.width * 0.7, 300)
            case .large: return min(geometry.size.width * 0.8, 400)
        }
    }

    private var titleFontSize: CGFloat {
        switch albumArtSize {
            case .small: return .getFontSize(UIFont.preferredFont(forTextStyle: .title2))
            case .medium: return .getFontSize(UIFont.preferredFont(forTextStyle: .title2)) + 3.0
            case .large: return .getFontSize(UIFont.preferredFont(forTextStyle: .title2)) + 8.0
        }
    }

    private var artistFontSize: CGFloat {
        switch albumArtSize {
            case .small: return .getFontSize(UIFont.preferredFont(forTextStyle: .caption1))
            case .medium: return .getFontSize(UIFont.preferredFont(forTextStyle: .caption1)) + 3.0
            case .large: return .getFontSize(UIFont.preferredFont(forTextStyle: .caption1)) + 8.0
        }
    }
}
