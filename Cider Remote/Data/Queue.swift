// Made by Lumaa

import Foundation

struct Queue {
    var tracks: [Track]
    let source: Self.Source?

    init(tracks: [Track], source: Self.Source? = nil) {
        self.tracks = tracks
        self.source = source
    }

    struct Source {
        let name: String
        let artworkURL: URL?
        let type: String
    }

    mutating func defineCurrent(track: Track) {
        guard let index = self.tracks.firstIndex(where: { $0.id == track.id }) else { return }

        let fx = self.tracks[index + 1...self.tracks.count - 1]
        self.tracks = Array(fx)
    }
}
