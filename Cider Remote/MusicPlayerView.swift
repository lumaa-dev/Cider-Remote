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
    @Published var useAdaptiveColors: Bool = false

    func updateColors(from image: UIImage) {
        let colors = image.dominantColors(count: 5)
        dominantColors = colors
        if !colors.isEmpty {
            primaryColor = colors.first ?? Color(hex: "#fa2f48")
            secondaryColor = colors.count > 1 ? colors[1] : .white
            backgroundColor = (colors.count > 2 ? colors[2] : .black).opacity(0.8)
            useAdaptiveColors = true
        } else {
            resetColors()
        }
        updateGlobalAppearance()
    }

    func resetColors() {
        primaryColor = Color(hex: "#fa2f48")
        secondaryColor = .white
        backgroundColor = .black.opacity(0.8)
        dominantColors = []
        useAdaptiveColors = false
        updateGlobalAppearance()
    }

    private func updateGlobalAppearance() {
        DispatchQueue.main.async {
            UITabBar.appearance().tintColor = UIColor(self.primaryColor)
            UINavigationBar.appearance().tintColor = UIColor(self.primaryColor)
            UISlider.appearance().minimumTrackTintColor = UIColor(self.primaryColor)
            UISlider.appearance().maximumTrackTintColor = UIColor(self.secondaryColor.opacity(0.5))
        }
    }
}


struct MusicPlayerView: View {
    let device: Device
    @StateObject var viewModel: MusicPlayerViewModel
    @StateObject var colorScheme = ColorSchemeManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                BlurredBackgroundView(colors: colorScheme.dominantColors)

                ScrollView {
                    VStack(spacing: 20) {
                        if let currentTrack = viewModel.currentTrack {
                            TrackInfoView(track: currentTrack, onImageLoaded: { image in
                                colorScheme.updateColors(from: image)
                                viewModel.needsColorUpdate = false
                            })
                            .frame(height: geometry.size.height * 0.45)

                            VStack(spacing: 20) {
                                PlayerControlsView(viewModel: viewModel)
                                VolumeControlView(viewModel: viewModel)
                                AdditionalControlsView()
                            }
                            .padding(.horizontal)
                        } else {
                            Text("No track playing")
                                .font(.title)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(minHeight: geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .environmentObject(colorScheme)
        .onAppear {
            viewModel.startListening()
            viewModel.getCurrentTrack()
            viewModel.getCurrentVolume()
        }
        .onDisappear {
            viewModel.stopListening()
            colorScheme.resetColors()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                viewModel.refreshCurrentTrack()
            }
        }
        .onChange(of: viewModel.needsColorUpdate) { needsUpdate in
            if needsUpdate {
                updateColors()
            }
        }
    }

    private func updateColors() {
        guard let artworkUrl = viewModel.currentTrack?.artwork,
              let url = URL(string: artworkUrl) else {
            colorScheme.resetColors()
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    colorScheme.resetColors()
                }
                return
            }

            DispatchQueue.main.async {
                colorScheme.updateColors(from: image)
                viewModel.needsColorUpdate = false
            }
        }.resume()
    }
}

struct TrackInfoView: View {
    let track: Track
    let onImageLoaded: (UIImage) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
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
            .frame(width: 300, height: 300)
            .cornerRadius(8)
            .shadow(radius: 10)
            
            VStack(spacing: 5) {
                Text(track.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct PlayerControlsView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel
    @EnvironmentObject var colorScheme: ColorSchemeManager
    @State private var isDragging = false
    @Environment(\.colorScheme) var systemColorScheme

    var body: some View {
        VStack(spacing: 10) {
            CustomSlider(value: $viewModel.currentTime,
                         bounds: 0...viewModel.duration,
                         isDragging: $isDragging,
                         onEditingChanged: { editing in
                             if !editing {
                                 viewModel.seekToTime()
                             }
                         })
                .accentColor(colorScheme.primaryColor)

            HStack {
                Text(formatTime(viewModel.currentTime))
                Spacer()
                Text(formatTime(viewModel.duration))
            }
            .font(.caption)
            .foregroundColor(colorScheme.secondaryColor)

            HStack {
                Button(action: viewModel.toggleLike) {
                    Image(systemName: viewModel.isLiked ? "star.fill" : "star")
                        .foregroundColor(viewModel.isLiked ? Color(hex: "#fa2f48") : lightDarkColor)
                        .frame(width: 44, height: 44) // Expanded tappable area
                }
                .buttonStyle(SpringyButtonStyle())

                Spacer()

                HStack(spacing: 20) {
                    Button(action: viewModel.previousTrack) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(lightDarkColor)
                            .frame(width: 60, height: 60) // Expanded tappable area
                    }
                    .buttonStyle(SpringyButtonStyle())

                    Button(action: viewModel.togglePlayPause) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(lightDarkColor)
                            .frame(width: 100, height: 100) // Expanded tappable area
                    }
                    .buttonStyle(SpringyButtonStyle())

                    Button(action: viewModel.nextTrack) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 30))
                            .foregroundColor(lightDarkColor)
                            .frame(width: 60, height: 60) // Expanded tappable area
                    }
                    .buttonStyle(SpringyButtonStyle())
                }

                Spacer()

                Menu {
                    Button(action: {
                        viewModel.toggleAddToLibrary()
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
                        .frame(width: 44, height: 44) // Expanded tappable area
                }
                .buttonStyle(SpringyButtonStyle())
            }
            .font(.title2)
        }
    }

    private var adaptiveColor: Color {
        let brightness = colorScheme.primaryColor.brightness
        let systemIsDark = systemColorScheme == .dark
        
        if systemIsDark {
            return brightness < 0.5 ? .white : .black
        } else {
            return brightness > 0.6 ? .black : .white
        }
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
        HStack(spacing: 12) {  // Keep the spacing as is
            Image(systemName: "speaker.fill")
                .foregroundColor(.secondary)
            CustomSlider(value: $viewModel.volume,
                         bounds: 0...1,
                         isDragging: $isDragging,
                         onEditingChanged: { editing in
                             if !editing {
                                 viewModel.adjustVolume()
                             }
                         })
                .accentColor(.red)
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.secondary)
        }
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
                    .frame(height: 8)  // Increased height from 4 to 8
                
                Rectangle()
                    .fill(colorScheme.secondaryColor)
                    .frame(width: CGFloat((value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width, height: 8)  // Increased height from 4 to 8
            }
            .cornerRadius(4)  // Increased corner radius from 2 to 4
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
        .frame(height: 44)  // Increased height from 30 to 44 to accommodate taller bars
    }
}

struct MenuOptionsView: View {
    @ObservedObject var viewModel: MusicPlayerViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        List {
            Button(action: {
                viewModel.toggleAddToLibrary()
                presentationMode.wrappedValue.dismiss()
            }) {
                Label(viewModel.isInLibrary ? "Remove from Library" : "Add to Library", systemImage: viewModel.isInLibrary ? "minus" : "plus")
            }
            
            // Add more menu options as needed
        }
        .listStyle(PlainListStyle())
    }
}

struct LargeButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(8)
        }
    }
}

struct AdditionalControlsView: View {
    var body: some View {
        HStack(spacing: 15) {
            LargeButton(title: "Lyrics", systemImage: "quote.bubble", action: {
                // Add action for showing lyrics
            })
            
            LargeButton(title: "Queue", systemImage: "list.bullet", action: {
                // Add action for showing queue
            })
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

class MusicPlayerViewModel: ObservableObject {
    let device: Device
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 0.5
    @Published var isLiked: Bool = false
    @Published var isInLibrary: Bool = false
    @Published var needsColorUpdate: Bool = false

    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var cancellables = Set<AnyCancellable>()

    init(device: Device) {
        self.device = device
    }
    
    func startListening() {
        print("Attempting to connect to socket")
        manager = SocketManager(socketURL: URL(string: "http://\(device.host):10767")!, config: [.log(true), .compress])
        socket = manager?.defaultSocket

        setupSocketEventHandlers()
        socket?.connect()
    }

    private func setupSocketEventHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            print("Socket connected")
            self?.getCurrentTrack()
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
        print("Refreshing current track")
        getCurrentTrack()
        getCurrentVolume()
        reconnectSocketIfNeeded()
    }

    private func reconnectSocketIfNeeded() {
        if socket?.status != .connected {
            print("Socket not connected, reconnecting...")
            socket?.connect()
        }
    }
    
    func getCurrentTrack() {
        print("Fetching current track")
        sendRequest(endpoint: "now-playing", method: "GET") { [weak self] result in
            switch result {
            case .success(let data):
                print("Current track data received: \(data)")
                if let info = data["info"] as? [String: Any] {
                    DispatchQueue.main.async {
                        self?.updateTrackInfo(info)
                    }
                } else {
                    print("Error: 'info' key not found in data")
                }
            case .failure(let error):
                print("Error fetching current track: \(error)")
            }
        }
    }
    
    private func updateTrackInfo(_ info: [String: Any]) {
        print("Updating track info: \(info)")
        let title = info["name"] as? String ?? ""
        let artist = info["artistName"] as? String ?? ""
        let album = info["albumName"] as? String ?? ""
        let duration = info["durationInMillis"] as? Double ?? 0

        if let artwork = info["artwork"] as? [String: Any],
           var artworkUrl = artwork["url"] as? String {
            // Replace placeholders in artwork URL
            artworkUrl = artworkUrl.replacingOccurrences(of: "{w}", with: "1024")
            artworkUrl = artworkUrl.replacingOccurrences(of: "{h}", with: "1024")

            let newTrack = Track(id: info["id"] as? String ?? "",
                                 title: title,
                                 artist: artist,
                                 album: album,
                                 artwork: artworkUrl,
                                 duration: duration / 1000)

            if self.currentTrack != newTrack {
                self.currentTrack = newTrack
                self.needsColorUpdate = true
            }
        }

        self.isLiked = info["inFavorites"] as? Bool ?? false
        self.isInLibrary = info["inLibrary"] as? Bool ?? false
        self.duration = duration / 1000

        if let currentPlaybackTime = info["currentPlaybackTime"] as? Double {
            self.currentTime = currentPlaybackTime
        }

        self.isPlaying = false;

        print("Updated currentTrack: \(String(describing: self.currentTrack))")
        print("isPlaying: \(self.isPlaying)")
    }
    
    func getCurrentVolume() {
        print("Fetching current volume")
        sendRequest(endpoint: "volume", method: "GET") { [weak self] result in
            switch result {
            case .success(let data):
                if let volume = data["volume"] as? Double {
                    DispatchQueue.main.async {
                        self?.volume = volume
                    }
                    print("Current volume: \(volume)")
                } else {
                    print("Error: 'volume' key not found in data")
                }
            case .failure(let error):
                print("Error fetching current volume: \(error)")
            }
        }
    }
    
    func togglePlayPause() {
            print("Toggling play/pause")
            isPlaying.toggle() // Immediately update UI
            sendRequest(endpoint: "playpause", method: "POST") { [weak self] result in
                switch result {
                case .success:
                    // Server confirmed the change, no need to update UI again
                    break
                case .failure:
                    // Revert the UI change if the server request failed
                    DispatchQueue.main.async {
                        self?.isPlaying.toggle()
                    }
                }
            }
        }
    
    func nextTrack() {
        print("Skipping to next track")
        sendRequest(endpoint: "next", method: "POST") { [weak self] _ in
            DispatchQueue.main.async {
                self?.getCurrentTrack() // Refresh track info after skipping
            }
        }
    }

    func previousTrack() {
        print("Going to previous track")
        sendRequest(endpoint: "previous", method: "POST") { [weak self] _ in
            DispatchQueue.main.async {
                self?.getCurrentTrack() // Refresh track info after going to previous track
            }
        }
    }
    
    func seekToTime() {
        print("Seeking to time: \(currentTime)")
        sendRequest(endpoint: "seek", method: "POST", body: ["position": currentTime])
    }
    
    func toggleLike() {
        let newRating = isLiked ? 0 : 1
        print("Toggling like status to: \(newRating)")
        sendRequest(endpoint: "set-rating", method: "POST", body: ["rating": newRating]) { [weak self] result in
            if case .success = result {
                DispatchQueue.main.async {
                    self?.isLiked.toggle()
                }
            }
        }
    }
    
    func toggleAddToLibrary() {
        if !isInLibrary {
            print("Adding to library")
            sendRequest(endpoint: "add-to-library", method: "POST") { [weak self] result in
                if case .success = result {
                    DispatchQueue.main.async {
                        self?.isInLibrary = true
                    }
                }
            }
        }
    }
    
    func adjustVolume() {
        print("Adjusting volume to: \(volume)")
        sendRequest(endpoint: "volume", method: "POST", body: ["volume": volume]) { [weak self] result in
            switch result {
            case .success(let data):
                if let newVolume = data["volume"] as? Double {
                    DispatchQueue.main.async {
                        self?.volume = newVolume
                    }
                    print("Volume adjusted to: \(newVolume)")
                }
            case .failure(let error):
                print("Error adjusting volume: \(error)")
            }
        }
    }
    
    private func setManualData(_ info: [String: Any]) {
        print("Setting manual data: \(info)")
        DispatchQueue.main.async {
            let title = info["name"] as? String ?? ""
            let artist = info["artistName"] as? String ?? ""
            let album = info["albumName"] as? String ?? ""
            let duration = info["durationInMillis"] as? Double ?? 0
            
            if let artwork = info["artwork"] as? [String: Any],
               let artworkUrl = artwork["url"] as? String {
                self.currentTrack = Track(id: info["id"] as? String ?? "",
                                          title: title,
                                          artist: artist,
                                          album: album,
                                          artwork: artworkUrl,
                                          duration: duration / 1000)
            }
            
            self.isLiked = info["inFavorites"] as? Bool ?? false
            self.isInLibrary = info["inLibrary"] as? Bool ?? false
            self.duration = duration / 1000
            
            if let currentPlaybackTime = info["currentPlaybackTime"] as? Double {
                self.currentTime = currentPlaybackTime
            }
            
            // Assume it's playing if we have track info
            self.isPlaying = true
        }
    }

    private func setAdaptiveData(_ info: [String: Any]) {
        print("Setting adaptive data: \(info)")
        DispatchQueue.main.async {
            self.isLiked = info["inFavorites"] as? Bool ?? false
            self.isInLibrary = info["inLibrary"] as? Bool ?? false
            
            if let currentPlaybackTime = info["currentPlaybackTime"] as? Double {
                self.currentTime = currentPlaybackTime
            }
            if let durationInMillis = info["durationInMillis"] as? Double {
                self.duration = durationInMillis / 1000
            }
        }
    }
    
    private func setPlaybackStatus(_ info: [String: Any]) {
        print("Setting playback status: \(info)")
        if let state = info["state"] as? String {
            self.isPlaying = (state == "playing")
        }
    }
    
    private func sendRequest(endpoint: String, method: String, body: [String: Any]? = nil, completion: ((Result<[String: Any], Error>) -> Void)? = nil) {
        guard let url = URL(string: "http://\(device.host):10767/api/v1/playback/\(endpoint)") else {
            print("Invalid URL")
            completion?(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
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

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion?(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response")
                completion?(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }

            print("Response status code: \(httpResponse.statusCode)")

            guard let data = data else {
                print("No data received")
                completion?(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("Received data: \(json)")
                    completion?(.success(json))
                } else {
                    print("Invalid JSON format")
                    completion?(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])))
                }
            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
                completion?(.failure(error))
            }
        }

        task.resume()
    }
}
