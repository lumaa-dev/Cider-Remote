// Made by Lumaa

import SwiftUI

struct LibraryAlbumRow: View {
    let album: LibraryAlbum

    private let width: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: URL(string: album.artwork)) { image in
                image
                    .resizable()
                    .frame(width: self.width, height: self.width)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            } placeholder: {
                ZStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .zIndex(20)

                    Rectangle()
                        .fill(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .zIndex(10)
                }
                .frame(width: self.width, height: self.width)
            }

            Text(album.title)
                .lineLimit(1)
            Text(album.artist)
                .lineLimit(1)
                .foregroundStyle(Color.secondary)
        }
        .frame(width: self.width)
    }
}
