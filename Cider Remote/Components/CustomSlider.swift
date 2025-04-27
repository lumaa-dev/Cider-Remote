// Made by Lumaa

import SwiftUI

struct CustomSlider: View {
    @Binding var value: Double
    @EnvironmentObject var colorScheme: ColorSchemeManager
    let bounds: ClosedRange<Double>
    @Binding var isDragging: Bool
    let onEditingChanged: (Bool) -> Void

    @State private var lastDragValue: Double?

    var body: some View {
        GeometryReader { geometry in
            let sliderHeight: CGFloat = isDragging ? 14 : 8

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Material.ultraThin)
                    .frame(height: sliderHeight)

                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: CGFloat((value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width, height: sliderHeight)
            }
            .clipShape(Capsule())
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gestureValue in
                        withAnimation(.interactiveSpring.speed(0.35)) {
                            isDragging = true
                        }
                        let newValue = bounds.lowerBound + (bounds.upperBound - bounds.lowerBound) * Double(gestureValue.location.x / geometry.size.width)
                        value = max(bounds.lowerBound, min(bounds.upperBound, newValue))

                        // Haptic feedback
                        if let last = lastDragValue, abs(newValue - last) > (bounds.upperBound - bounds.lowerBound) / 100 {
                            let impact = UIImpactFeedbackGenerator(style: .light) //MARK: API is deprecated
                            impact.impactOccurred()
                            lastDragValue = newValue
                        } else if lastDragValue == nil {
                            lastDragValue = newValue
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.interactiveSpring.speed(0.35)) {
                            isDragging = false
                        }
                        lastDragValue = nil
                        onEditingChanged(false)
                    }
            )
        }
        .environment(\.colorScheme, ColorScheme.light)
        .frame(height: 44)
    }
}
