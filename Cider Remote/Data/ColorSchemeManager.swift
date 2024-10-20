// Made by Lumaa

import SwiftUI

class ColorSchemeManager: ObservableObject {
    @Published var primaryColor: Color = Color(hex: "#fa2f48")
    @Published var secondaryColor: Color = .white
    @Published var backgroundColor: Color = .black.opacity(0.8)
    @Published var dominantColors: [Color] = []
    @AppStorage("useAdaptiveColors") var useAdaptiveColors: Bool = true {
        didSet {
            if useAdaptiveColors {
                applyColors()
            } else {
                resetToDefaultColors()
            }
        }
    }

    private var lastImageColors: [Color] = []
    private var lastImage: UIImage?
    private var currentColorScheme: ColorScheme = .light

    func updateColorScheme(_ colorScheme: ColorScheme) {
        currentColorScheme = colorScheme
        applyColors()
    }

    func updateColors(from image: UIImage) {
        lastImage = image
        let colors = image.dominantColors(count: 5)
        lastImageColors = colors
        applyColors()
    }

    func applyColors() {
        if useAdaptiveColors && !lastImageColors.isEmpty {
            dominantColors = lastImageColors
            primaryColor = lastImageColors.first ?? Color(hex: "#fa2f48")
            secondaryColor = lastImageColors.count > 1 ? lastImageColors[1] : .white
            backgroundColor = (lastImageColors.count > 2 ? lastImageColors[2] : .black).opacity(0.8)
        } else {
            resetToDefaultColors()
        }
        updateGlobalAppearance()
    }

    func resetToDefaultColors() {
        primaryColor = Color(hex: "#fa2f48")
        secondaryColor = lightDarkColor
        backgroundColor = .black.opacity(0.8)
        dominantColors = []
        updateGlobalAppearance()
    }

    func reapplyAdaptiveColors() {
        if useAdaptiveColors, let lastImage = lastImage {
            updateColors(from: lastImage)
        } else {
            resetToDefaultColors()
        }
    }

    private func updateGlobalAppearance() {
        DispatchQueue.main.async {
            UITabBar.appearance().tintColor = UIColor(self.primaryColor)
            UINavigationBar.appearance().tintColor = UIColor(self.secondaryColor)
            UISlider.appearance().minimumTrackTintColor = UIColor(self.primaryColor)
            UISlider.appearance().maximumTrackTintColor = UIColor(self.secondaryColor.opacity(0.5))
        }
    }

    private var lightDarkColor: Color {
        currentColorScheme == .dark ? .white : .black
    }
}
