// Made by Lumaa

import SwiftUI

struct PlayerControlsView: View {
    @Environment(\.colorScheme) var systemColorScheme

    @EnvironmentObject var colorScheme: ColorSchemeManager

    @ObservedObject var viewModel: MusicPlayerViewModel

    @State private var isDragging = false

    let buttonSize: ElementSize
    let geometry: GeometryProxy

    var body: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let scale: CGFloat = isIPad ? 1.1 : 1.0  // Slightly reduced scale

        VStack(spacing: 12 * scale) {  // Increased spacing between main elements
                                       // Playback bar
            VStack(spacing: isIPad ? 4 : 0) {  // Increased spacing between slider and timestamps
                CustomSlider(value: $viewModel.currentTime,
                             bounds: 0...viewModel.duration,
                             isDragging: $isDragging,
                             onEditingChanged: { editing in
                    if !editing {
                        Task {
                            await viewModel.seekToTime()
                        }
                    }
                })
                .tint(Color.white)

                // Timestamps
                HStack {
                    Text(formatTime(viewModel.currentTime))
                    Spacer()
                    Text(formatTime(viewModel.duration))
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .frame(width: min(geometry.size.width * (isIPad ? 0.7 : 0.9), 500))

            HStack(spacing: 0) {
                Button(action: {
                    Task {
                        await viewModel.toggleLike()
                    }
                }) {
                    Image(systemName: viewModel.isLiked ? "star.fill" : "star")
                        .foregroundColor(viewModel.isLiked ? Color(hex: "#fa2f48") : lightDarkColor)
                        .frame(width: buttonSize.dimension * scale, height: buttonSize.dimension * scale)
                }
                .buttonStyle(SpringyButtonStyle())

                Spacer()

                HStack(alignment: .center, spacing: calculateButtonSpacing()) {
                    Button(action: {
                        Task {
                            await viewModel.previousTrack()
                        }
                    }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: buttonSize.fontSize * 1.2 * scale))
                            .foregroundColor(lightDarkColor)
                            .frame(width: buttonSize.dimension * 1.2 * scale, height: buttonSize.dimension * 1.2 * scale)
                    }
                    .buttonStyle(SpringyButtonStyle())

                    Button(action: {
                        Task {
                            await viewModel.togglePlayPause()
                        }
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: buttonSize.fontSize * 2.5 * scale))
                            .foregroundColor(lightDarkColor)
                            .frame(width: buttonSize.dimension * 1.8 * scale, height: buttonSize.dimension * 1.8 * scale)
                    }
                    .buttonStyle(SpringyButtonStyle())

                    Button(action: {
                        Task {
                            await viewModel.nextTrack()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: buttonSize.fontSize * 1.2 * scale))
                            .foregroundColor(lightDarkColor)
                            .frame(width: buttonSize.dimension * 1.2 * scale, height: buttonSize.dimension * 1.2 * scale)
                    }
                    .buttonStyle(SpringyButtonStyle())
                }
                .frame(width: min(geometry.size.width * (isIPad ? 0.5 : 0.6), 300))

                Spacer()

                AdditionalControls(viewModel: viewModel, lightDarkColor: lightDarkColor, buttonSize: buttonSize)
            }
            .frame(width: min(geometry.size.width * (isIPad ? 0.8 : 0.95), 500))
            .font(.system(size: isIPad ? 22 : 20))  // Slightly reduced font size for iPad
        }
        .padding(.top, isIPad ? 20 : 0)  // Add padding at the top
    }

    private func calculateButtonSpacing() -> CGFloat {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let totalWidth = min(geometry.size.width * (isIPad ? 0.5 : 0.6), 300)
        let buttonWidths = buttonSize.dimension * 1.2 * 2 + buttonSize.dimension * 1.8
        let remainingSpace = totalWidth - buttonWidths

        return remainingSpace / 4 // Divide by 4 to create 3 equal spaces between buttons
    }

    private var lightDarkColor: Color {
        systemColorScheme == .dark ? .white : .black
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AdditionalControls: View {
    let viewModel: MusicPlayerViewModel
    let lightDarkColor: Color
    let buttonSize: ElementSize

    init(viewModel: MusicPlayerViewModel, lightDarkColor: Color, buttonSize: ElementSize) {
        self.viewModel = viewModel
        self.lightDarkColor = lightDarkColor
        self.buttonSize = buttonSize
    }

    var body: some View {
        Menu {
            Button {
                Task {
                    await viewModel.toggleAddToLibrary()
                }
            } label: {
                Label(viewModel.isInLibrary ? "Remove from Library" : "Add to Library", systemImage: viewModel.isInLibrary ? "minus" : "plus")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundColor(lightDarkColor)
                .frame(width: buttonSize.dimension * (UIDevice.current.userInterfaceIdiom == .pad ? 1.1 : 1.0), height: buttonSize.dimension * (UIDevice.current.userInterfaceIdiom == .pad ? 1.1 : 1.0))
        }
        .buttonStyle(SpringyButtonStyle())
    }
}

struct VolumeControlView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel
    @State private var isDragging = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .foregroundColor(.secondary)
            CustomSlider(value: $viewModel.volume,
                         bounds: 0...1,
                         isDragging: $isDragging,
                         onEditingChanged: { editing in
                if !editing {
                    Task {
                        viewModel.adjustVolume()
                    }
                }
            })
            .accentColor(.red)
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.secondary)
        }
        .frame(height: 30)  // Set a fixed height for the volume control
    }
}

struct AdditionalControlsView: View {
    let buttonSize: ElementSize
    let geometry: GeometryProxy
    @Environment(\.colorScheme) var colorScheme
    @Binding var showLyrics: Bool
    @Binding var showQueue: Bool

    var body: some View {
        HStack(spacing: 30) {
            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showLyrics.toggle()
                }
            }) {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showQueue.toggle()
                }
            }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
        .frame(height: 44)
        .padding(.bottom, 10)
    }
}
