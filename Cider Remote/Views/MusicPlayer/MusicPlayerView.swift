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

struct MusicPlayerView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var colorScheme: ColorSchemeManager

    @AppStorage("buttonSize") private var buttonSize: ElementSize = .medium
    @AppStorage("albumArtSize") private var albumArtSize: ElementSize = .large

    let device: Device

    @StateObject private var viewModel: MusicPlayerViewModel

    @State private var currentImage: UIImage?
    @State private var isLoading = true
    @State private var isCompact = false

    init(device: Device) {
        self.device = device
        _viewModel = StateObject(wrappedValue: MusicPlayerViewModel(device: device, colorSchemeManager: ColorSchemeManager()))
    }

    var body: some View {
        GeometryReader { geometry in
            let isIPad = UIDevice.current.userInterfaceIdiom == .pad
            let scale: CGFloat = isIPad ? 1.2 : 1.0
            
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
                        .scaleEffect(1.5 * scale)
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme.primaryColor))
                } else {
                    VStack(spacing: 20 * scale) {
                        if let currentTrack = viewModel.currentTrack {
                            HStack {
                                TrackInfoView(track: currentTrack, onImageLoaded: { image in
                                    currentImage = image
                                    colorScheme.updateColors(from: image)
                                    viewModel.needsColorUpdate = false
                                }, albumArtSize: albumArtSize, geometry: geometry, isCompact: $isCompact)
                                .scaleEffect(scale)

                                if isCompact {
                                    Spacer()

                                    Button {
                                        withAnimation(.spring) {
                                            withAnimation(.spring) {
                                                viewModel.showingQueue = false
                                                viewModel.showingLyrics = false
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Color.white.opacity(0.4))
                                            .font(.system(size: 28))
                                    }
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
                                VStack(spacing: 15 * scale) {
                                    PlayerControlsView(viewModel: viewModel, buttonSize: buttonSize, geometry: geometry)
                                        .scaleEffect(scale)

                                    VolumeControlView(viewModel: viewModel)
                                        .padding(.horizontal)

                                    AdditionalControlsView(
                                        buttonSize: buttonSize,
                                        geometry: geometry,
                                        showLyrics: $viewModel.showingLyrics,
                                        showQueue: $viewModel.showingQueue
                                    )
                                    .scaleEffect(scale)
                                }
                                .padding(.horizontal, isIPad ? 40 : 20)
                            }
                        } else {
                            Text("No track playing")
                                .font(.title)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .padding(.top, isIPad ? (isCompact ? 0 : 50) : (isCompact ? 0 : 30))
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
        .onChange(of: viewModel.showingQueue) { newShow in
            withAnimation(.spring) {
                self.isCompact = newShow
            }
        }
        .onChange(of: viewModel.showingLyrics) { newShow in
            withAnimation(.spring) {
                self.isCompact = newShow
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

@MainActor
class MusicPlayerViewModel: ObservableObject {
    let device: Device

    /// The "Now Playing" activity
    @Published var nowPlaying: NowPlaying? = nil
    /// Everything Live Activity for the playing song
    @Published var liveActivity: LiveActivityManager = LiveActivityManager.shared
    @Published var queueItems: [Track] = []
    @Published var sourceQueue: Queue?
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
    @Published var showingLyrics = false
    @Published var showingQueue = false
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

    init(device: Device, colorSchemeManager: ColorSchemeManager = .init()) {
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
        self.liveActivity.device = device
    }

    func startListening() {
        print("Attempting to connect to socket")
        let socketURL = device.connectionMethod == "tunnel"
            ? "https://\(device.host)"
            : "http://\(device.host):10767"
        manager = SocketManager(socketURL: URL(string: socketURL)!, config: [.log(false), .compress])
        socket = manager?.defaultSocket

        setupSocketEventHandlers()
        socket?.connect()
    }

    private func setupSocketEventHandlers() {
        socket?.on(clientEvent: .connect) { [weak self] data, ack in
            print("Socket connected")
            
            Task {
                await self?.getCurrentTrack()
                self?.nowPlaying = .init(viewModel: self!)
                self?.nowPlaying?.setNowPlayingInfo()
                self?.nowPlaying?.setNowPlayingPlaybackInfo()

                if let currentTrack = self?.currentTrack {
                    self!.liveActivity.startActivity(using: currentTrack)
                }

                AppDelegate.shared.scheduleAppRefresh()
            }
        }

        socket?.on("API:Playback") { [weak self] data, ack in
            guard let self = self,
                  let playbackData = data[0] as? [String: Any],
                  let type = playbackData["type"] as? String else {
                print("Invalid playback data received")
                return
            }

//            print("Received playback event: \(type)")
            
            DispatchQueue.main.async {
                switch type {
                case "playbackStatus.nowPlayingStatusDidChange":
                    if let info = playbackData["data"] as? [String: Any] {
                        self.setAdaptiveData(info)
                    }
                case "playbackStatus.nowPlayingItemDidChange":
                    if let info = playbackData["data"] as? [String: Any] {
                        self.updateTrackInfo(info)
                        if let currentTrack = self.currentTrack {
                            self.liveActivity.startActivity(using: currentTrack)
                        }
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
                        self.nowPlaying?.setNowPlayingPlaybackInfo()
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

    func initializePlayer() async {
        await getCurrentTrack()
        await getCurrentVolume()
        await fetchQueueItems()
    }

    func refreshCurrentTrack() {
        Task {
            await getCurrentTrack()
            await getCurrentVolume()

            if let currentTrack, queueItems.first?.id == currentTrack.id {
                queueItems.removeFirst()
            } else {
                await fetchQueueItems()
            }

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
        guard let currentTrack else { print("[QUEUE] Need currentTrack to get current queue"); return }

        print("Fetching current queue")
        do {
            let data = try await sendRequest(endpoint: "playback/queue")
            if let jsonDict = data as? [[String: Any]] {
                let attributes: [[String : Any]] = jsonDict.compactMap { $0["attributes"] as? [String : Any] }
                let queue: [Track] = attributes.map { getTrack(using: $0) }

                var queueItem: Queue = .init(tracks: queue)
                queueItem.defineCurrent(track: currentTrack)

                self.sourceQueue = queueItem // after defining offset
                self.queueItems = queueItem.tracks
            }
        } catch {
            handleError(error)
        }
    }

    func getCurrentTrack() async {
        print("Fetching current track")
        do {
            let data = try await sendRequest(endpoint: "playback/now-playing", method: "GET")
            if let jsonDict = data as? [String: Any],
               let info = jsonDict["info"] as? [String: Any] {
                updateTrackInfo(info, alt: true)
                nowPlaying?.setNowPlayingInfo()
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

            let data: Data? = nil

//            Task {
//                let image = await self.loadImage(for: URL(string: artworkUrl)!)
//                if let imgData = image?.pngData() {
//                    data = imgData
//                }
//            }

            let newTrack = Track(id: id,
                                 title: title,
                                 artist: artist,
                                 album: album,
                                 artwork: artworkUrl,
                                 duration: duration / 1000,
                                 artworkData: data ?? Data()
            )

            if self.currentTrack != newTrack {
                self.currentTrack = newTrack
                self.needsColorUpdate = self.colorSchemeManager.useAdaptiveColors
                self.lyrics = [] // Clear lyrics when track changes
                Task {
                    await self.updateQueue(newTrack: newTrack)
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

    private func updateQueue(newTrack: Track) async {
        print("[QUEUE] smart update")
        if newTrack.id == queueItems.first?.id { // newTrack is the next playing song in the queue
            queueItems = Array(queueItems.dropFirst())
        } else {
            await fetchQueueItems()
        }
    }

    func playFromQueue(_ track: Track) async {
        guard let sourceQueue, let index = sourceQueue.tracks.firstIndex(where: { $0.id == track.id }) else { return }
        print("[QUEUE] play from queue")

        do {
            _ = try await sendRequest(
                endpoint: "playback/queue/change-to-index",
                method: "POST",
                body: ["index" : index + sourceQueue.offset]
            )
            await updateQueue(newTrack: track)
        } catch {
            handleError(error)
        }
    }

    func moveQueue(from startIndex: Int, to destinationIndex: Int) async {
        guard let sourceQueue, startIndex != destinationIndex else { return }
        do {
            _ = try await sendRequest(endpoint: "playback/queue/move-to-position",
                                      method: "POST",
                                      body: ["startIndex" : startIndex + sourceQueue.offset, "destinationIndex": destinationIndex + sourceQueue.offset]
            )
            try? await Task.sleep(nanoseconds: 500_000_000) // we don't wait, then the *fetchQueueItems* will error
            await fetchQueueItems()
        } catch {
            handleError(error)
        }
    }

    func removeQueue(index: Int) async {
        guard let sourceQueue else { return }
        do {
            _ = try await sendRequest(endpoint: "playback/queue/remove-by-index",
                                      method: "POST",
                                      body: ["index": index + sourceQueue.offset]
            )
        } catch {
            handleError(error)
        }
    }

    private func getTrack(using info: [String: Any]) -> Track {
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

            let data: Data? = nil

            return Track(id: id,
                         title: title,
                         artist: artist,
                         album: album,
                         artwork: artworkUrl,
                         duration: duration / 1000,
                         artworkData: data ?? Data()
            )
        } else {
            return Track(id: id,
                         title: title,
                         artist: artist,
                         album: album,
                         artwork: "",
                         duration: duration / 1000,
                         artworkData: Data()
            )
        }
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

    func searchSong(query: String) async -> [Track] {
        print("Searching for: \(query)")
        do {
            let data = try await sendRequest(endpoint: "amapi/run-v3", method: "POST", body: ["path": "/v1/catalog/us/search?term=\(query)&types=songs"])

            if let jsonDict = data as? [String: Any], let data = jsonDict["data"] as? [String: Any], let _results = data["results"] as? [String: Any] {
                guard let songs = _results["songs"] as? [String: Any], let results = songs["data"] as? [[String: Any]] else {
                    print("Couldn't decrypt stuff")
                    return []
                }

                var searchResults: [Track] = []
                for result in results {
                    guard let attributes = result["attributes"] as? [String: Any], let artwork = attributes["artwork"] as? [String: Any] else {
                        print("Oopsy, couldn't add search result")
                        return []
                    }

                    searchResults
                        .append(
                            .init(
                                id: attributes["isrc"] as! String,
                                title: attributes["name"] as! String,
                                artist: attributes["artistName"] as! String,
                                album: attributes["albumName"] as! String,
                                artwork: String((artwork["url"] as! String).replacing(/{(w|h)}/, with: "500")),
                                duration: (Double(attributes["durationInMillis"] as? String ?? "0") ?? 0.0) / 1000,
                                artworkData: Data(),
                                songHref: (result["href"] as! String)
                            )
                        )
                }

                print("[searchSong] RETURNING \(searchResults.count) results")
                return searchResults
            } else {
                throw NetworkError.decodingError
            }
        } catch {
            handleError(error)
        }

        return []
    }

    func playHref(href: String) async {
        print("Playing song using HREF")

        do {
            _ = try await sendRequest(endpoint: "playback/play-item-href", method: "POST", body: ["href": href])
        } catch {
            handleError(error)
        }
    }

    func playTrackHref(_ track: Track) async {
        guard let href = track.songHref else { fatalError("No HREF in this Track") }
        print("Playing TRACK song using HREF")

        do {
            _ = try await sendRequest(endpoint: "playback/play-item-href", method: "POST", body: ["href": href])
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

    func loadArtwork() async -> UIImage? {
        guard let artwork = self.currentTrack?.artwork else { return nil }
        let url: URL = URL(string: artwork)!
        return await self.loadImage(for: url)
    }

    private func sendRequest(endpoint: String, method: String = "GET", body: [String: Any]? = nil) async throws -> Any {
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
//        print("Response raw: \(String(data: data, encoding: .utf8) ?? "[No data]")")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        print("Response status code: \(httpResponse.statusCode)")

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError("Server responded with status code \(httpResponse.statusCode)")
        }

        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
//            print("Received data: \(json)")
            return json
        } catch {
            print(error)
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
