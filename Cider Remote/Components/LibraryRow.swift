// Made by Lumaa

import SwiftUI

struct LibraryRow: View {
    let title: String
    let author: String
    let artwork: String

    init(title: String, author: String, artwork: String) {
        self.title = title
        self.author = author
        self.artwork = artwork
    }

    init(from album: LibraryAlbum) {
        self.title = album.title
        self.author = album.artist
        self.artwork = album.artwork
    }

    init(from playlist: LibraryPlaylist) {
        self.title = playlist.name
        self.author = ""
        self.artwork = playlist.artwork
    }

    private let width: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: URL(string: artwork)) { image in
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

            Text(title)
                .lineLimit(1)
            
            Text(author)
                .lineLimit(1)
                .foregroundStyle(Color.secondary)
        }
        .frame(width: self.width)
    }
}
