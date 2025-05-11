// Made by Lumaa

import UIKit
import SocketIO
import Combine

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
    @Published var lyrics: [LyricLine]? = nil

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
        guard let currentTrack else { return }

        print("Current track ID: \(currentTrack.id)")

        if let cachedLyrics = lyricCache[currentTrack.id] {
            print("Using cached lyrics for track: \(currentTrack.id)")
            self.lyrics = cachedLyrics
            return
        }

        self.lyrics = nil
        guard let lyricsUrl = URL(string: "https://rise.cider.sh/api/v1/lyrics/mxm") else { return }

        do {
            print("Fetching lyrics ONLINE for track: \(currentTrack.id)")

            let lyricReq: Track.RequestLyrics = .init(track: currentTrack)
            let encoder: JSONEncoder = .init()
            let body: Data = try encoder.encode(lyricReq)

            var req = URLRequest(url: lyricsUrl, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: .infinity)
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")

            req.httpMethod = "POST"
            req.httpBody = body

            let (data, response) = try await URLSession.shared.data(for: req)

//            if let str = String(data: data, encoding: .utf8) {
//                print(str)
//            }

            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let decoder: JSONDecoder = .init()
                let mxm = try decoder.decode(Track.MxmLyrics.self, from: data)

                let lines = mxm.decodeHtml()
                print("Parsed \(lines.count) lyric lines")
                DispatchQueue.main.async {
                    self.lyrics = lines
                    self.lyricCache[currentTrack.id] = self.lyrics
                }
            } else {
                self.lyrics = []
                throw NetworkError.serverError("Couldn't reach server")
            }
        } catch {
            self.lyrics = []
            print(error)
            handleError(error)
        }
    }

    func fetchLyricsFromClient() async {
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
            print("Fetching lyrics FROM CLIENT for track: \(currentTrack.id)")
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
