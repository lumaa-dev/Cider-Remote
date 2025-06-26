// Made by Lumaa

import SwiftUI

struct LibraryTrackRow: View {
    let track: LibraryTrack
    var number: Int
    var showCover: Bool = false

    private let coverSize: CGFloat = 50

    init(_ track: LibraryTrack, number: Int, showCover: Bool = false) {
        self.track = track
        self.number = number
        self.showCover = showCover
    }

    var body: some View {
        HStack {
            if showCover {
                AsyncImage(url: URL(string: track.artwork)) { image in
                    image
                        .resizable()
                        .frame(width: self.coverSize, height: self.coverSize)
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
                    .frame(width: self.coverSize, height: self.coverSize)
                }
                .padding(.trailing)
            } else {
                Text(number, format: .number)
                    .font(.callout)
                    .foregroundStyle(Color.secondary)
                    .padding(.trailing)
            }

            VStack(alignment: .leading) {
                Text(track.name)
                    .foregroundStyle(track.catalogId == "[UNKNOWN]" ? Color.gray : Color(uiColor: UIColor.label))
                    .font(.body)
                    .multilineTextAlignment(.leading)

                if track.album?.artist != track.artist {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
