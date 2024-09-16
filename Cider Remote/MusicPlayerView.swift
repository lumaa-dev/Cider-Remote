//
//  MusicPlayerView.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//


import SwiftUI
import UIKit
import SocketIO
import Combine

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


struct MusicPlayerView: View {
    let device: Device
    @StateObject private var viewModel: MusicPlayerViewModel
    @State private var currentImage: UIImage?
    @EnvironmentObject var colorScheme: ColorSchemeManager
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("buttonSize") private var buttonSize: Size = .medium
    @AppStorage("albumArtSize") private var albumArtSize: Size = .large

    @State private var showingLyrics = false
    @State private var showingQueue = false
    @State private var isLoading = true

    init(device: Device) {
        self.device = device
        _viewModel = StateObject(wrappedValue: MusicPlayerViewModel(device: device, colorSchemeManager: ColorSchemeManager()))
    }

    var body: some View {
        GeometryReader { geometry in
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            let scale: CGFloat = isIPad ? 1.2 : 1.0
            
            ZStack {
                BlurredBackgroundView(colors: colorScheme.dominantColors)

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5 * scale)
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme.primaryColor))
                } else {
                    VStack(spacing: 20 * scale) {
                        if let currentTrack = viewModel.currentTrack {
                            TrackInfoView(track: currentTrack, onImageLoaded: { image in
                                currentImage = image
                                colorScheme.updateColors(from: image)
                                viewModel.needsColorUpdate = false
                            }, albumArtSize: albumArtSize, geometry: geometry)
                            .scaleEffect(scale)

                            VStack(spacing: 15 * scale) {
                                PlayerControlsView(viewModel: viewModel, buttonSize: buttonSize, geometry: geometry)
                                    .scaleEffect(scale)
                                VolumeControlView(viewModel: viewModel)
                                    .padding(.horizontal)
                                AdditionalControlsView(
                                    buttonSize: buttonSize,
                                    geometry: geometry,
                                    showLyrics: $showingLyrics,
                                    showQueue: $showingQueue
                                )
                                .scaleEffect(scale)
                            }
                            .padding(.horizontal, isIPad ? 40 : 20)
                        } else {
                            Text("No track playing")
                                .font(.title)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .padding(.top, isIPad ? 50 : 30)
                }

                if showingLyrics {
                    LyricsView(isShowing: $showingLyrics, viewModel: viewModel)
                        .transition(
                            AnyTransition.move(edge: .bottom)
                                .combined(with: .offset(y: 50))
                        )
                        .ignoresSafeArea(edges: .bottom)
                }

                if showingQueue {
                    QueueView(isShowing: $showingQueue, viewModel: viewModel)
                        .transition(
                            AnyTransition.move(edge: .bottom)
                                .combined(with: .offset(y: 50))
                        )
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .edgesIgnoringSafeArea(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .environmentObject(colorScheme)
        .onAppear {
            colorScheme.updateColorScheme(systemColorScheme)
            viewModel.startListening()
            Task {
                await viewModel.initializePlayer()
                await MainActor.run {
                    withAnimation {
                        isLoading = false
                    }
                }
            }
        }
        .onDisappear {
            viewModel.stopListening()
            if colorScheme.useAdaptiveColors {
                colorScheme.resetToDefaultColors()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    viewModel.refreshCurrentTrack()
                }
                if colorScheme.useAdaptiveColors {
                    colorScheme.reapplyAdaptiveColors()
                }
            }
        }
        .onChange(of: systemColorScheme) { newColorScheme in
            colorScheme.updateColorScheme(newColorScheme)
        }
        .onChange(of: viewModel.needsColorUpdate) { needsUpdate in
            if needsUpdate && colorScheme.useAdaptiveColors {
                updateColors()
            }
        }
    }

    private func updateColors() {
        guard let artworkUrl = viewModel.currentTrack?.artwork,
              let url = URL(string: artworkUrl) else {
            colorScheme.resetToDefaultColors()
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        colorScheme.updateColors(from: image)
                        viewModel.needsColorUpdate = false
                    }
                }
            } catch {
                print("Error loading artwork: \(error)")
                await MainActor.run {
                    colorScheme.resetToDefaultColors()
                }
            }
        }
    }
}

extension MusicPlayerViewModel {
    func initializePlayer() async {
        do {
            try await getCurrentTrack()
            try await getCurrentVolume()
            try await fetchQueueItems()
        } catch {
            await MainActor.run {
                self.handleError(error)
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct LyricsView: View {
    @Binding var isShowing: Bool
    @ObservedObject var viewModel: MusicPlayerViewModel
    @State private var activeLine: LyricLine?
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager

    private let lineSpacing: CGFloat = 24 // Increased spacing between lines
    private let lyricAdvanceTime: Double = 0.3 // Advance lyrics 0.5 seconds early

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BlurView(style: .systemMaterial)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    // Header with Artwork
                    HStack(spacing: 16) {
                        if let currentTrack = viewModel.currentTrack {
                            AsyncImage(url: URL(string: currentTrack.artwork)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure:
                                    Image(systemName: "music.note")
                                        .foregroundColor(.gray)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 64, height: 64)
                            .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentTrack.title)
                                    .font(.system(size: 22, weight: .bold))
                                    .lineLimit(1)
                                Text(currentTrack.artist)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button(action: {
                            withAnimation(.spring()) {
                                isShowing = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 28))
                        }
                        .padding(.trailing, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider().padding(.horizontal, 20)


                    if viewModel.lyrics.isEmpty {
                        Text("No lyrics available")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        LyricsScrollView(
                            lyrics: viewModel.lyrics,
                            activeLine: $activeLine,
                            currentTime: $viewModel.currentTime,
                            viewportHeight: geometry.size.height - 110, // Adjust for header
                            lineSpacing: lineSpacing
                        )
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
        .foregroundColor(colorScheme == .dark ? .white : .black)
        .onAppear {
            Task {
                await viewModel.fetchLyrics()
            }
        }
        .onChange(of: viewModel.currentTime) { newTime in
            updateCurrentLyric(time: newTime + lyricAdvanceTime)
        }
    }

    private func updateCurrentLyric(time: Double) {
        guard let currentLine = viewModel.lyrics.last(where: { $0.timestamp <= time }) else {
            activeLine = nil
            return
        }
        activeLine = currentLine
    }
}

struct LyricsScrollView: View {
    let lyrics: [LyricLine]
    @Binding var activeLine: LyricLine?
    @Binding var currentTime: Double
    let viewportHeight: CGFloat
    let lineSpacing: CGFloat

    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { scrollView in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: lineSpacing) {
                        Spacer(minLength: 180) // Space for one line above active lyric
                        ForEach(lyrics) { line in
                            LyricLineView(
                                lyric: line,
                                isActive: line == activeLine,
                                maxWidth: geometry.size.width - 40
                            )
                            .id(line.id)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                        }
                        Spacer(minLength: viewportHeight - 180) // Remaining space below lyrics
                    }
                }
                .onChange(of: activeLine) { newActiveLine in
                    if let newActiveLine = newActiveLine, !isDragging {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            if let index = lyrics.firstIndex(of: newActiveLine), index > 0 {
                                scrollView.scrollTo(lyrics[index - 1].id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: viewportHeight)
        .gesture(
            DragGesture()
                .onChanged { _ in isDragging = true }
                .onEnded { _ in
                    isDragging = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.updateActiveLine()
                    }
                }
        )
        .onAppear {
            updateActiveLine()
        }
        .onChange(of: currentTime) { _ in
            updateActiveLine()
        }
    }

    private func updateActiveLine() {
        if !isDragging {
            activeLine = lyrics.last { $0.timestamp <= currentTime + 0.5 }
        }
    }
}

struct LyricLineView: View {
    let lyric: LyricLine
    let isActive: Bool
    let maxWidth: CGFloat

    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var colorSchemeManager: ColorSchemeManager

    var body: some View {
        Text(lyric.text)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundColor(textColor)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }

    private var fontSize: CGFloat {
        isActive ? 30 : 22
    }

    private var fontWeight: Font.Weight {
        isActive ? .bold : .regular
    }

    private var textColor: Color {
        if (isActive) {
            return colorScheme == .dark ? .white : .black
        } else {
            return .gray.opacity(0.6)
        }
    }
}

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let timestamp: Double
    let isMainLyric: Bool
}

struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct QueueView: View {
    @Binding var isShowing: Bool
    @ObservedObject var viewModel: MusicPlayerViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Blurred background
            BlurView(style: .systemMaterial)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Up Next")
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 28))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

                // Queue list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.queueItems, id: \.id) { track in
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: track.artwork)) { phase in
                                    switch phase {
                                    case .empty:
                                        Color.gray.opacity(0.3)
                                    case .success(let image):
                                        image.resizable()
                                    case .failure:
                                        Image(systemName: "music.note")
                                            .foregroundColor(.gray)
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .cornerRadius(4)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text(track.artist)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(formatDuration(track.duration))
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .foregroundColor(.primary)
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct TrackInfoView: View {
    let track: Track
    let onImageLoaded: (UIImage) -> Void
    let albumArtSize: Size
    let geometry: GeometryProxy

    var body: some View {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let scale: CGFloat = isIPad ? 1.1 : 1.0  // Slightly reduced scale
        
        VStack(spacing: 10 * scale) {  // Reduced spacing
            AsyncImage(url: URL(string: track.artwork)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .onAppear {
                            if let uiImage = image.asUIImage() {
                                onImageLoaded(uiImage)
                            }
                        }
                case .failure:
                    Image(systemName: "music.note")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.gray)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: artworkSize, height: artworkSize)  // Remove scale from here
            .cornerRadius(8)
            .shadow(radius: 10)

            VStack(spacing: 5 * scale) {  // Reduced spacing
                Text(track.title)
                    .font(.system(size: titleFontSize * scale))
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: artistFontSize * scale))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: geometry.size.width * (isIPad ? 0.7 : 0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, isIPad ? 20 : 0)  // Add padding at the bottom
    }

    private var artworkSize: CGFloat {
        switch albumArtSize {
        case .small: return min(geometry.size.width * 0.6, 200)
        case .medium: return min(geometry.size.width * 0.7, 300)
        case .large: return min(geometry.size.width * 0.8, 400)
        }
    }

    private var titleFontSize: CGFloat {
        switch albumArtSize {
        case .small: return 20
        case .medium: return 24
        case .large: return 28
        }
    }

    private var artistFontSize: CGFloat {
        switch albumArtSize {
        case .small: return 16
        case .medium: return 18
        case .large: return 20
        }
    }
}

struct PlayerControlsView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel
    @EnvironmentObject var colorScheme: ColorSchemeManager
    @State private var isDragging = false
    @Environment(\.colorScheme) var systemColorScheme
    let buttonSize: Size
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
                    .accentColor(colorScheme.primaryColor)

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

                Menu {
                    Button(action: {
                        Task {
                            await viewModel.toggleAddToLibrary()
                        }
                    }) {
                        Label(viewModel.isInLibrary ? "Remove from Library" : "Add to Library", systemImage: viewModel.isInLibrary ? "minus" : "plus")
                    }

                    Button(action: {
                        // Add action for showing lyrics
                    }) {
                        Label("Show Lyrics", systemImage: "quote.bubble")
                    }

                    Button(action: {
                        // Add action for showing queue
                    }) {
                        Label("Show Queue", systemImage: "list.bullet")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(lightDarkColor)
                        .frame(width: buttonSize.dimension * scale, height: buttonSize.dimension * scale)
                }
                .buttonStyle(SpringyButtonStyle())
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

struct ResponsiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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


struct CustomSlider: View {
    @Binding var value: Double
    @EnvironmentObject var colorScheme: ColorSchemeManager
    let bounds: ClosedRange<Double>
    @Binding var isDragging: Bool
    let onEditingChanged: (Bool) -> Void

    @State private var lastDragValue: Double?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(height: 8)

                Rectangle()
                    .fill(colorScheme.secondaryColor)
                    .frame(width: CGFloat((value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width, height: 8)
            }
            .cornerRadius(4)
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gestureValue in
                        isDragging = true
                        let newValue = bounds.lowerBound + (bounds.upperBound - bounds.lowerBound) * Double(gestureValue.location.x / geometry.size.width)
                        value = max(bounds.lowerBound, min(bounds.upperBound, newValue))

                        // Haptic feedback
                        if let last = lastDragValue, abs(newValue - last) > (bounds.upperBound - bounds.lowerBound) / 100 {
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            lastDragValue = newValue
                        } else if lastDragValue == nil {
                            lastDragValue = newValue
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastDragValue = nil
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 44)
    }
}

struct LargeButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let size: Size
    let geometry: GeometryProxy

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: adjustedFontSize))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: adjustedHeight)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(8)
        }
    }

    private var adjustedFontSize: CGFloat {
        min(size.fontSize * 0.8, 22)  // Reduce font size and set a maximum
    }

    private var adjustedHeight: CGFloat {
        min(size.dimension * 1.2, 60)  // Adjust height and set a maximum
    }
}

struct SmallButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    let size: Size
    let geometry: GeometryProxy

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: adjustedFontSize))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: adjustedHeight)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(8)
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

struct AdditionalControlsView: View {
    let buttonSize: Size
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    var brightness: Double {
        let components = UIColor(self).cgColor.components
        return (components?[0] ?? 0.0) * 0.299 + (components?[1] ?? 0.0) * 0.587 + (components?[2] ?? 0.0) * 0.114
    }
}

extension UIImage {
    func dominantColors(count: Int = 3) -> [Color] {
        guard let inputImage = self.cgImage else { return [] }
        let width = inputImage.width
        let height = inputImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        rawData.withUnsafeMutableBytes { ptr in
            if let context = CGContext(data: ptr.baseAddress,
                                       width: width,
                                       height: height,
                                       bitsPerComponent: 8,
                                       bytesPerRow: 4 * width,
                                       space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                context.draw(inputImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
        
        var colors: [Color] = []
        let pixelCount = width * height
        let sampleCount = max(pixelCount / 1000, 1)  // Sample every 1000th pixel or at least 1
        
        for i in stride(from: 0, to: pixelCount * 4, by: sampleCount * 4) {
            let red = Double(rawData[i]) / 255.0
            let green = Double(rawData[i + 1]) / 255.0
            let blue = Double(rawData[i + 2]) / 255.0
            colors.append(Color(red: red, green: green, blue: blue))
        }
        
        // Remove duplicates and limit to the requested count
        return Array(Set(colors)).prefix(count).map { $0 }
    }
}

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        let view = controller.view
        
        let targetSize = controller.view.intrinsicContentSize
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = .clear
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

struct BlurredBackgroundView: View {
    let colors: [Color]
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.2)

            ForEach(colors.indices, id: \.self) { index in
                Circle()
                    .fill(colors[index].opacity(colorScheme == .dark ? 0.6 : 0.4))
                    .frame(width: 150, height: 150)
                    .offset(x: CGFloat.random(in: -100...100),
                            y: CGFloat.random(in: -100...100))
                    .blur(radius: 60)
            }
        }
        .ignoresSafeArea()
    }
}


struct Track: Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artwork: String
    let duration: Double
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

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(String)
}

@MainActor
class MusicPlayerViewModel: ObservableObject {
    let device: Device
    @Published var queueItems: [Track] = []
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 0.5
    @Published var isLiked: Bool = false
    @Published var isInLibrary: Bool = false
    @Published var needsColorUpdate: Bool = false
    @Published var showLibraryPopup = false
    @Published var showFavoritePopup = false
    @Published var errorMessage: String?
    @Published var lyrics: [LyricLine] = []

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var cancellables = Set<AnyCancellable>()

    private var volumeDebouncer: Debouncer?
    private var seekDebouncer: Debouncer?
    private var imageCache = NSCache<NSString, UIImage>()
    private var lyricCache: [String: [LyricLine]] = [:]
    
    private var colorSchemeManager: ColorSchemeManager

    init(device: Device, colorSchemeManager: ColorSchemeManager) {
        self.device = device
        self.colorSchemeManager = colorSchemeManager
        self.volumeDebouncer = Debouncer(delay: 0.3) { [weak self] in
            guard let self = self else { return }
            Task {
                await self.adjustVolumeDebounced()
            }
        }
        self.seekDebouncer = Debouncer(delay: 0.3) { [weak self] in
            guard let self = self else { return }
            Task {
                await self.seekToTimeDebounced()
            }
        }
    }

    func startListening() {
        print("Attempting to connect to socket")
        let socketURL = device.connectionMethod == "tunnel"
            ? "https://\(device.host)"
            : "http://\(device.host):10767"
        manager = SocketManager(socketURL: URL(string: socketURL)!, config: [.log(true), .compress])
        socket = manager?.defaultSocket

        setupSocketEventHandlers()
        socket?.connect()
    }

    private func setupSocketEventHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            print("Socket connected")
            
            Task {
                await self?.getCurrentTrack()
            }
        }

        socket?.on("API:Playback") { [weak self] data, ack in
            guard let self = self,
                  let playbackData = data[0] as? [String: Any],
                  let type = playbackData["type"] as? String else {
                print("Invalid playback data received")
                return
            }
            
            print("Received playback event: \(type)")
            
            DispatchQueue.main.async {
                switch type {
                case "playbackStatus.nowPlayingStatusDidChange":
                    if let info = playbackData["data"] as? [String: Any] {
                        self.setAdaptiveData(info)
                    }
                case "playbackStatus.nowPlayingItemDidChange":
                    if let info = playbackData["data"] as? [String: Any] {
                        self.updateTrackInfo(info)
                    }
                case "playbackStatus.playbackStateDidChange":
                    if let info = playbackData["data"] as? [String: Any] {
                        self.setPlaybackStatus(info)
                    }
                case "playbackStatus.playbackTimeDidChange":
                    if let info = playbackData["data"] as? [String: Any],
                       let isPlaying = info["isPlaying"] as? Int,
                       let currentPlaybackTime = info["currentPlaybackTime"] as? Double {
                        self.isPlaying = isPlaying == 1 ? true : false
                        self.currentTime = currentPlaybackTime
                    }
                default:
                    print("Unhandled event type: \(type)")
                }
            }
        }
    }

    func stopListening() {
        print("Disconnecting socket")
        socket?.disconnect()
    }

    func refreshCurrentTrack() {
        Task {
            await getCurrentTrack()
            await getCurrentVolume()
            reconnectSocketIfNeeded()
        }
    }

    private func reconnectSocketIfNeeded() {
        if socket?.status != .connected {
            print("Socket not connected, reconnecting...")
            socket?.connect()
        }
    }

    func fetchQueueItems() async {
        // Implement this method to fetch the queue items from the API
        // For now, we'll use dummy data
        queueItems = [
            Track(id: "1", title: "Stand By Me", artist: "Ben E. King", album: "Don't Play That Song", artwork: "https://example.com/artwork1.jpg", duration: 180),
            Track(id: "2", title: "Imagine", artist: "John Lennon", album: "Imagine", artwork: "https://example.com/artwork2.jpg", duration: 210),
            Track(id: "3", title: "What's Going On", artist: "Marvin Gaye", album: "What's Going On", artwork: "https://example.com/artwork3.jpg", duration: 195),
        ]
    }

    func getCurrentTrack() async {
        print("Fetching current track")
        do {
            let data = try await sendRequest(endpoint: "playback/now-playing", method: "GET")
            if let jsonDict = data as? [String: Any],
               let info = jsonDict["info"] as? [String: Any] {
                updateTrackInfo(info, alt: true)
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            handleError(error)
        }
    }
    
    func fetchLyrics() async {
        guard let currentTrack = currentTrack else {
            print("No current track available")
            return
        }

        print("Current track ID: \(currentTrack.id)")

        if let cachedLyrics = lyricCache[currentTrack.id] {
            print("Using cached lyrics for track: \(currentTrack.id)")
            self.lyrics = cachedLyrics
            return
        }

        do {
            print("Fetching lyrics for track: \(currentTrack.id)")
            let data = try await sendRequest(endpoint: "lyrics/\(currentTrack.id)", method: "GET")
            print("Received lyrics data: \(data)")

            if let lyricsData = data as? [[String: Any]] {
                let parsedLyrics = lyricsData.compactMap { lyricData -> LyricLine? in
                    guard let start = lyricData["start"] as? Double,
                          let text = lyricData["text"] as? String,
                          let empty = lyricData["empty"] as? Bool,
                          !empty && !text.isEmpty else {
                        return nil
                    }
                    // Determine if it's a main lyric or secondary lyric
                    let isMainLyric = !(text.hasPrefix("(") && text.hasSuffix(")"))
                    return LyricLine(text: text, timestamp: start, isMainLyric: isMainLyric)
                }
                print("Parsed \(parsedLyrics.count) lyric lines")
                DispatchQueue.main.async {
                    self.lyrics = parsedLyrics
                    self.lyricCache[currentTrack.id] = self.lyrics
                }
            } else {
                print("Unexpected lyrics data format")
                throw NetworkError.decodingError
            }
        } catch {
            print("Error fetching lyrics: \(error)")
            handleError(error)
        }
    }
    
    private func setPlaybackStatus(_ info: [String: Any]) {
        print("Setting playback status: \(info)")
        if let state = info["state"] as? String {
            self.isPlaying = (state == "playing")
        }
    }
    
    private func setAdaptiveData(_ info: [String: Any]) {
        print("Setting adaptive data: \(info)")
        DispatchQueue.main.async {
            if let isLiked = info["inFavorites"] as? Int, isLiked == 1 {
                self.isLiked = true
            } else {
                self.isLiked = false
            }
            
            if let isInLibrary = info["inLibrary"] as? Int, isInLibrary == 1 {
                self.isInLibrary = true
            } else {
                self.isInLibrary = false
            }
            
            if let currentPlaybackTime = info["currentPlaybackTime"] as? Double {
                self.currentTime = currentPlaybackTime
            }
            if let durationInMillis = info["durationInMillis"] as? Double {
                self.duration = durationInMillis / 1000
            }
        }
    }

    private func updateTrackInfo(_ info: [String: Any], alt: Bool = false) {
        print("Updating track info: \(info)")
        
        // Extract ID from playParams
        let id: String
        if let playParams = info["playParams"] as? [String: Any],
           let trackId = playParams["id"] as? String {
            id = trackId
        } else {
            id = info["id"] as? String ?? ""
        }
        
        let title = info["name"] as? String ?? ""
        let artist = info["artistName"] as? String ?? ""
        let album = info["albumName"] as? String ?? ""
        let duration = info["durationInMillis"] as? Double ?? 0

        if let artwork = info["artwork"] as? [String: Any],
           var artworkUrl = artwork["url"] as? String {
            // Replace placeholders in artwork URL
            artworkUrl = artworkUrl.replacingOccurrences(of: "{w}", with: "1024")
            artworkUrl = artworkUrl.replacingOccurrences(of: "{h}", with: "1024")

            let newTrack = Track(id: id,
                                 title: title,
                                 artist: artist,
                                 album: album,
                                 artwork: artworkUrl,
                                 duration: duration / 1000)

            if self.currentTrack != newTrack {
                self.currentTrack = newTrack
                self.needsColorUpdate = self.colorSchemeManager.useAdaptiveColors
                self.lyrics = [] // Clear lyrics when track changes
                Task {
                    await self.fetchLyrics() // Fetch lyrics for the new track
                }
            }
        }
        
        if alt {
            self.isLiked = info["inFavorites"] as? Bool ?? false
            self.isInLibrary = info["inLibrary"] as? Bool ?? false
        }
        self.duration = duration / 1000

        if let currentPlaybackTime = info["currentPlaybackTime"] as? Double {
            self.currentTime = currentPlaybackTime
        }

        self.isPlaying = false

        print("Updated currentTrack: \(String(describing: self.currentTrack))")
        print("isPlaying: \(self.isPlaying)")
    }

    func getCurrentVolume() async {
        print("Fetching current volume")
        do {
            let data = try await sendRequest(endpoint: "playback/volume", method: "GET")
            if let jsonDict = data as? [String: Any],
               let volume = jsonDict["volume"] as? Double {
                self.volume = volume
                print("Current volume: \(volume)")
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            handleError(error)
        }
    }

    func togglePlayPause() async {
        print("Toggling play/pause")
        isPlaying.toggle() // Immediately update UI
        do {
            _ = try await sendRequest(endpoint: "playback/playpause", method: "POST")
            // Server confirmed the change, no need to update UI again
        } catch {
            // Revert the UI change if the server request failed
            isPlaying.toggle()
            handleError(error)
        }
    }

    func nextTrack() async {
        print("Skipping to next track")
        do {
            _ = try await sendRequest(endpoint: "playback/next", method: "POST")
            await getCurrentTrack() // Refresh track info after skipping
        } catch {
            handleError(error)
        }
    }

    func previousTrack() async {
        print("Going to previous track")
        do {
            _ = try await sendRequest(endpoint: "playback/previous", method: "POST")
            await getCurrentTrack() // Refresh track info after going to previous track
        } catch {
            handleError(error)
        }
    }

    func seekToTime() async {
        print("Seeking to time: \(currentTime)")
        do {
            _ = try await sendRequest(endpoint: "playback/seek", method: "POST", body: ["position": currentTime])
        } catch {
            handleError(error)
        }
    }

    func toggleLike() async {
        let newRating = isLiked ? 0 : 1
        print("Toggling like status to: \(newRating)")
        do {
            _ = try await sendRequest(endpoint: "playback/set-rating", method: "POST", body: ["rating": newRating])
            isLiked.toggle()
            showFavoritePopup = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showFavoritePopup = false
            }
        } catch {
            handleError(error)
        }
    }

    func toggleAddToLibrary() async {
        if !isInLibrary {
            print("Adding to library")
            do {
                _ = try await sendRequest(endpoint: "playback/add-to-library", method: "POST")
                isInLibrary = true
                showLibraryPopup = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showLibraryPopup = false
                }
            } catch {
                handleError(error)
            }
        }
    }

    func adjustVolume() {
        volumeDebouncer?.call()
    }

    private func adjustVolumeDebounced() async {
        print("Adjusting volume to: \(volume)")
        do {
            let data = try await sendRequest(endpoint: "playback/volume", method: "POST", body: ["volume": volume])
            if let jsonDict = data as? [String: Any],
               let newVolume = jsonDict["volume"] as? Double {
                self.volume = newVolume
                print("Volume adjusted to: \(newVolume)")
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            handleError(error)
        }
    }

    func seekToTime() {
        seekDebouncer?.call()
    }

    private func seekToTimeDebounced() async {
        print("Seeking to time: \(currentTime)")
        do {
            _ = try await sendRequest(endpoint: "playback/seek", method: "POST", body: ["position": currentTime])
        } catch {
            handleError(error)
        }
    }

    func loadImage(for url: URL) async -> UIImage? {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: url.absoluteString as NSString) {
            return cachedImage
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                // Cache the image
                imageCache.setObject(image, forKey: url.absoluteString as NSString)
                return image
            }
        } catch {
            print("Error loading image: \(error)")
        }
        return nil
    }

    private func sendRequest(endpoint: String, method: String, body: [String: Any]? = nil) async throws -> Any {
        let baseURL = device.connectionMethod == "tunnel"
            ? "https://\(device.host)"
            : "http://\(device.host):10767"
        guard let url = URL(string: "\(baseURL)/api/v1/\(endpoint)") else {
            throw NetworkError.invalidURL
        }

        print("Sending request to: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue(device.token, forHTTPHeaderField: "apptoken")

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            print("Request body: \(body)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        print("Response status code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Server responded with status code \(httpResponse.statusCode)")
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            print("Received data: \(json)")
            return json
        } catch {
            throw NetworkError.decodingError
        }
    }

    private func handleError(_ error: Error) {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .invalidURL:
                errorMessage = "Invalid URL"
            case .invalidResponse:
                errorMessage = "Invalid response from server"
            case .decodingError:
                errorMessage = "Error decoding data"
            case .serverError(let message):
                errorMessage = "Server error: \(message)"
            }
        } else {
            errorMessage = error.localizedDescription
        }
        print("Error: \(errorMessage ?? "Unknown error")")
    }
}

class Debouncer {
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private let action: () -> Void

    init(delay: TimeInterval, queue: DispatchQueue = .main, action: @escaping () -> Void) {
        self.delay = delay
        self.queue = queue
        self.action = action
    }

    func call() {
        workItem?.cancel()
        let workItem = DispatchWorkItem(block: action)
        self.workItem = workItem
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
