// Made by Lumaa

import Foundation
import UIKit

struct Track: Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artwork: String
    let duration: Double
    var artworkData: Data

    func getArtwork() async -> UIImage? {
        do {
            let url: URL = URL(string: self.artwork)!
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                return image
            }
        } catch {
            print("Error loading image: \(error)")
        }
        return nil
    }

    func getArtwork() -> UIImage? {
        var ui: UIImage? = nil
        Task {
            do {
                let url: URL = URL(string: self.artwork)!
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    ui = image
                }
            } catch {
                print("Error loading image: \(error)")
            }
        }
        return ui
    }

    func getArtwork() -> UIImage {
        return UIImage(data: self.artworkData) ?? UIImage.logo
    }

    mutating func setArtworkData() async {
        if let (data, _) = try? await URLSession.shared.data(from: URL(string: self.artwork)!) {
            self.artworkData = data
        }
    }
}
