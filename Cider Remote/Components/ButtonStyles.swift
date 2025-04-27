// Made by Lumaa

import SwiftUI

// MARK: - Button Components

struct SmallButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let size: ElementSize
    let geometry: GeometryProxy

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: adjustedFontSize))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: adjustedHeight)
            .background(Color.secondary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var adjustedFontSize: CGFloat {
        switch size {
            case .small: return 12
            case .medium: return 14
            case .large: return 16
        }
    }

    private var adjustedHeight: CGFloat {
        switch size {
            case .small: return 30
            case .medium: return 34
            case .large: return 38
        }
    }
}

struct LargeButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let size: ElementSize
    let geometry: GeometryProxy

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: adjustedFontSize))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: adjustedHeight)
            .background(Color.secondary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var adjustedFontSize: CGFloat {
        min(size.fontSize * 0.8, 22)  // Reduce font size and set a maximum
    }

    private var adjustedHeight: CGFloat {
        min(size.dimension * 1.2, 60)  // Adjust height and set a maximum
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    @EnvironmentObject var colorScheme: ColorSchemeManager
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(colorScheme.primaryColor)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.secondary.opacity(0.1))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct SpringyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle()) // Makes the entire frame tappable
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
    }
}

struct ResponsiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
