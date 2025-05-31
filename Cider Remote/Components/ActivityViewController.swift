// Made by Lumaa

import SwiftUI
import UIKit

struct ActivityViewController: UIViewControllerRepresentable {
    let track: Track

    func makeUIViewController(context: Context) -> UIActivityViewController {
        if let url: URL = URL(string: "https://music.apple.com/us/song/\(track.catalogId)") {
            return UIActivityViewController(activityItems: [url], applicationActivities: nil)
        } else {
            let ui: UIImage = track.getArtwork()
            return UIActivityViewController(activityItems: [ui], applicationActivities: nil)
        }
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
