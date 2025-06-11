//
//  MusicPlayerView.swift
//  Cider Remote
//
//  Created by Elijah Klaumann on 8/26/24.
//

import SwiftUI

struct MusicPlayerView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var colorScheme: ColorSchemeManager

    @AppStorage("buttonSize") private var buttonSize: ElementSize = .medium
    @AppStorage("albumArtSize") private var albumArtSize: ElementSize = .large

    let device: Device

    @StateObject private var viewModel: MusicPlayerViewModel
    @StateObject private var userDevice: UserDevice = .shared

    @State private var currentImage: UIImage?
    @State private var isLoading = true
    @State private var isCompact = false

    init(device: Device) {
        self.device = device
        _viewModel = StateObject(wrappedValue: MusicPlayerViewModel(device: device, colorSchemeManager: ColorSchemeManager()))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                if let currentImage {
                    BlurredImageView(image: Image(uiImage: currentImage))
                        .ignoresSafeArea()
                        .overlay {
                            Color.black
                                .opacity(0.5)
                                .ignoresSafeArea()
                        }
                } else {
                    LinearGradient(colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                        .blur(radius: 60)
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme.primaryColor))
                } else {
                    VStack(spacing: 20) {
                        if let currentTrack = viewModel.currentTrack {
                            if userDevice.horizontalOrientation == .portrait || userDevice.isPad {
                                portraitView(track: currentTrack, geometry: geometry)
                            } else {
                                landscapeView(
                                    track: currentTrack,
                                    geometry: geometry,
                                    rightButtons: userDevice.horizontalOrientation == .landscapeLeft
                                )
                            }
                        } else {
                            Text("No track playing")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .padding(.top, userDevice.isPad ? (isCompact ? 0 : 50) : (isCompact ? 0 : 30))
                }
            }
            .tint(colorScheme.primaryColor)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .edgesIgnoringSafeArea(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isCompact)
        .environmentObject(colorScheme)
        .environment(\.colorScheme, ColorScheme.dark)
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
            LiveActivityManager().stopActivity()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    viewModel.refreshCurrentTrack()
                }
                if colorScheme.useAdaptiveColors {
                    colorScheme.reapplyAdaptiveColors()
                }
            }
        }
        .onChange(of: systemColorScheme) { _, newColorScheme in
            colorScheme.updateColorScheme(newColorScheme)
        }
        .onChange(of: viewModel.needsColorUpdate) { _, needsUpdate in
            if needsUpdate && colorScheme.useAdaptiveColors {
                updateColors()
            }
        }
        .onChange(of: viewModel.showingQueue) { _, newShow in
            withAnimation(.spring) {
                self.isCompact = newShow
            }
        }
        .onChange(of: viewModel.showingLyrics) { _, newShow in
            withAnimation(.spring) {
                self.isCompact = newShow
            }
        }
        .onChange(of: userDevice.horizontalOrientation) { _, _ in
            withAnimation(.spring) {
                self.viewModel.showingQueue = false
                self.viewModel.showingLyrics = false
            }
        }
    }

    @ViewBuilder
    private func portraitView(track: Track, geometry: GeometryProxy) -> some View {
        HStack {
            TrackInfoView(track: track, onImageLoaded: { image in
                currentImage = image
                colorScheme.updateColors(from: image)
                viewModel.needsColorUpdate = false
            }, albumArtSize: albumArtSize, geometry: geometry, isCompact: $isCompact)

            if isCompact {
                Spacer()

                closeBtn
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)

        if isCompact {
            if viewModel.showingQueue {
                QueueView(viewModel: viewModel)
            } else if viewModel.showingLyrics {
                LyricsView(viewModel: viewModel)
            }
        } else {
            VStack(spacing: 15) {
                PlayerControlsView(viewModel: viewModel, buttonSize: buttonSize, geometry: geometry)

                VolumeControlView(viewModel: viewModel, geometry: geometry)

                AdditionalControlsView(
                    showLyrics: $viewModel.showingLyrics,
                    showQueue: $viewModel.showingQueue,
                    buttonSize: buttonSize,
                    geometry: geometry
                )
            }
            .padding(.horizontal, userDevice.isPad ? 40 : 20)
        }
    }

    @ViewBuilder
    private func landscapeView(track: Track, geometry: GeometryProxy, rightButtons: Bool = false) -> some View {
        HStack {
            if !isCompact {
                if rightButtons {
                    TrackInfoView(track: track, onImageLoaded: { image in
                        currentImage = image
                        colorScheme.updateColors(from: image)
                        viewModel.needsColorUpdate = false
                    }, albumArtSize: albumArtSize, geometry: geometry, isCompact: $isCompact)
                    .frame(width: geometry.size.width / 2 - 20)

                    VStack(spacing: 15) {
                        PlayerControlsView(viewModel: viewModel, buttonSize: buttonSize, geometry: geometry)

                        VolumeControlView(viewModel: viewModel, geometry: geometry)
                            .padding(.horizontal)

                        AdditionalControlsView(
                            showLyrics: $viewModel.showingLyrics,
                            showQueue: $viewModel.showingQueue,
                            buttonSize: buttonSize,
                            geometry: geometry
                        )
                    }
                    .frame(width: geometry.size.width / 2 - 20)
                } else {
                    VStack(spacing: 15) {
                        PlayerControlsView(viewModel: viewModel, buttonSize: buttonSize, geometry: geometry)

                        VolumeControlView(viewModel: viewModel, geometry: geometry)
                            .padding(.horizontal)

                        AdditionalControlsView(
                            showLyrics: $viewModel.showingLyrics,
                            showQueue: $viewModel.showingQueue,
                            buttonSize: buttonSize,
                            geometry: geometry
                        )
                    }
                    .frame(width: geometry.size.width / 2 - 20)

                    TrackInfoView(track: track, onImageLoaded: { image in
                        currentImage = image
                        colorScheme.updateColors(from: image)
                        viewModel.needsColorUpdate = false
                    }, albumArtSize: albumArtSize, geometry: geometry, isCompact: $isCompact)
                    .frame(width: geometry.size.width / 2 - 20)
                }
            } else {
                if viewModel.showingLyrics {
                    LyricsView(viewModel: viewModel)
                        .frame(width: geometry.size.width - 150)
                        .overlay(alignment: .topTrailing) {
                            closeBtn
                                .padding(.top, 30)
                        }
                } else if viewModel.showingQueue {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView {
                            Label("Oops!", systemImage: "iphone.gen3.landscape")
                        } description: {
                            Text("Seems like you can't view your queue in landscape mode YET...")
                        } actions: {
                            Button {
                                withAnimation {
                                    self.viewModel.showingQueue.toggle()
                                }
                            } label: {
                                Text("Close Queue")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        VStack {
                            Text("Oops!")
                                .font(.title2.bold())

                            Text("Seems like you can't view your queue in landscape mode YET...")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)

                            Button {
                                withAnimation {
                                    self.viewModel.showingQueue.toggle()
                                }
                            } label: {
                                Text("Close Queue")
                            }
                            .buttonStyle(.bordered)
                            .padding(.top)
                        }
                    }
                }
            }
        }
    }

    private var closeBtn: some View {
        Button {
            withAnimation(.spring) {
                withAnimation(.spring) {
                    viewModel.showingQueue = false
                    viewModel.showingLyrics = false
                }
            }
        } label: {
            if #available(iOS 26.0, *) {
                Image(systemName: "xmark")
                    .foregroundStyle(Color(uiColor: UIColor.label))
                    .padding(12)
                    .glassEffect(.regular.interactive())
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.white.opacity(0.4))
                    .font(.system(size: 28))
            }
        }
    }

    private func updateColors() {
        self.currentImage = nil

        guard let artworkUrl = viewModel.currentTrack?.artwork,
              let url = URL(string: artworkUrl) else {
            colorScheme.resetToDefaultColors()
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    self.currentImage = image

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
    @Environment(\.colorScheme) var colorScheme

    let colors: [Color]

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

struct BlurredImageView: View {
    let image: Image

    var body: some View {
        image
            .resizable()
            .scaledToFill()
            .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height)
            .blur(radius: 60)
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
