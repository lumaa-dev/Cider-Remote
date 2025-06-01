// Made by Lumaa

import SwiftUI

struct BrowserView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction

    let device: Device

    @State private var isLoading: Bool = true
    @State private var isLoadingMore: Bool = false
    @State private var offset: Int = 10

    @State private var albums: [LibraryAlbum] = []

    private let columns = UserDevice.shared.isPad ? [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ] : [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            } else {
                library
            }
        }
        .task {
            defer { self.isLoading = false }
            self.albums = await self.getLibrary()
        }
    }

    var library: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, alignment: .center) {
                    ForEach(self.albums) { album in
                        NavigationLink(value: album) {
                            LibraryAlbumRow(album: album)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Button {
                    self.isLoadingMore = true

                    Task {
                        defer { self.isLoadingMore = false }
                        self.albums.append(contentsOf: await self.getLibrary(offset: offset))
                        offset += 10
                    }
                } label: {
                    Text("Load 10 more")
                        .foregroundStyle(Color.cider)
                        .padding(.vertical, 10.0)
                        .padding(.horizontal, 25.0)
                        .background(Material.ultraThin)
                        .clipShape(RoundedRectangle(cornerRadius: 7.0))
                }
                .buttonStyle(SpringyButtonStyle())
                .disabled(self.isLoadingMore)
                .padding(.top, 15.0)
                .padding(.bottom, 5.0)
            }
            .navigationTitle(Text("Recently Added"))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: LibraryAlbum.self) { album in
                LibraryAlbumView(album)
                    .environmentObject(device)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(Color.cider)
                }
            }
        }
        .tint(Color.cider)
    }

    @ViewBuilder
    static func access(_ sheetVisible: Binding<Bool>, background: Color = Color.clear) -> some View {
        Button {
            sheetVisible.wrappedValue.toggle()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "play.square.stack.fill")
                    .imageScale(.large)
                    .foregroundStyle(Color.white)

                Text("View Library")
                    .font(.body.bold())
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                ZStack {
                    Rectangle()
                        .fill(Material.ultraThin)
                        .zIndex(10)

                    Rectangle()
                        .fill(background.gradient)
                        .opacity(0.6)
                        .zIndex(1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(SpringyButtonStyle())
    }
}

extension BrowserView {
    func getLibrary(offset: Int = 0) async -> [LibraryAlbum] {
        do {
            let data = try await runAppleMusicAPI(path: "/v1/me/library/recently-added?offset=\(offset)")
            var libraries: [LibraryAlbum] = []

            if let arrayd = data as? [[String: Any]] {
                for l in arrayd {
                    libraries.append(.init(data: l))
                }
            }

            return libraries
        } catch {
            print("Error getting library: \(error)")
        }

        return []
    }

    func runAppleMusicAPI(path: String) async throws -> Any {
        do {
            let data = try await sendRequest(endpoint: "amapi/run-v3", method: "POST", body: ["path": path])
            if let jsonDict = data as? [String: Any], let data = jsonDict["data"] as? [String: Any] {
                if let subdata = data["data"] as? [String: Any] { // object
                    return subdata
                } else if let subdata = data["data"] as? [[String: Any]] { // array of objects
                    return subdata
                }
            }

            return data
        } catch {
            print("Error running Apple Music API: \(error)")
            throw NetworkError.invalidResponse
        }
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
}
