// Made by Lumaa

import SwiftUI

struct LibraryTrackRow: View {
    let track: LibraryTrack

    var body: some View {
        HStack {
            Text(track.trackNumber, format: .number)
                .font(.callout)
                .foregroundStyle(Color.secondary)
                .padding(.trailing)

            VStack(alignment: .leading) {
                Text(track.name)
                    .foregroundStyle(track.catalogId == "[UNKNOWN]" ? Color.gray : Color(uiColor: UIColor.label))
                    .font(.body)
                    .multilineTextAlignment(.leading)

                if track.album.artist != track.artist {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
