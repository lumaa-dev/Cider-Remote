// Made by Lumaa

import SwiftUI

struct QueueView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @ObservedObject var viewModel: MusicPlayerViewModel

    @State private var searchText: String = ""
    @State private var searchResults: [Track] = []
    @State private var tappedTrack: Track? = nil
    @State private var fetchingResults: Bool = false

    @FocusState private var isSearching: Bool

    var body: some View {
        ZStack {
            List {
                TextField(text: $searchText, prompt: Text("Search")) {
                    EmptyView()
                }
                .focused($isSearching)
                .labelsHidden()
                .submitLabel(.search)
                .padding(.horizontal)
                .padding(.vertical, 8.0)
                .background(Material.bar)
                .clipShape(Capsule())
                .padding(.horizontal)
                .scrollDismissesKeyboard(.immediately)
                .onSubmit {
                    Task {
                        fetchingResults = true
                        searchResults = await viewModel.searchSong(query: searchText)
                        fetchingResults = false
                    }
                }
                .ciderRowOptimized()

                if !isSearching && searchText.isEmpty {
                    Divider()
                        .overlay { Color.white }
                        .padding(.horizontal)
                        .ciderRowOptimized()

                    Section {
                        queueView
                            .ciderRowOptimized()
                    }
                    .ciderOptimized()
                } else {
                    resultsView
                        .ciderRowOptimized()
                }
            }
            .ciderOptimized()
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder
    private var queueView: some View {
        if viewModel.queueItems.count <= 0 {
            if #available(iOS 17.0, *) {
                ContentUnavailableView("Queue empty", systemImage: "list.number", description: Text("Your Cider queue is empty"))
            } else {
                VStack {
                    Image(systemName: "list.number")
                        .imageScale(.large)
                        .font(.title2)
                        .padding(.bottom)

                    Text("Queue empty")
                        .font(.title3)

                    Text("Your Cider queue is empty")
                        .font(.caption)
                        .foregroundStyle(Color.gray)
                }
            }
        } else {
            ForEach(viewModel.queueItems, id: \.id) { track in
                Button {
                    Task {
                        await viewModel.playFromQueue(track)
                    }
                } label: {
                    trackRow(track, showDuration: true)
                        .ciderRowOptimized()
                }
            }
            .onDelete { set in
                guard var sourceQueue = viewModel.sourceQueue else { return }
                viewModel.queueItems.remove(atOffsets: set)
                sourceQueue.remove(set: set)

                viewModel.sourceQueue = sourceQueue

                Task {
                    for i in set {
                        await viewModel.removeQueue(index: i)
                    }
                }
            }
            .onMove { from, to in
                guard var sourceQueue = viewModel.sourceQueue, let firstIndex = from.first else { return }
                viewModel.queueItems.move(fromOffsets: from, toOffset: to)
                sourceQueue.move(from: from, to: to)

                viewModel.sourceQueue = sourceQueue

                Task {
                    await viewModel.moveQueue(from: firstIndex, to: to)
                }
            }
        }
    }

    @ViewBuilder
    private var resultsView: some View {
        if fetchingResults {
            ProgressView()
                .progressViewStyle(.circular)
                .padding(.vertical)
        } else {
            if searchResults.count > 0 || isSearching {
                Divider()
                    .overlay { Color.white }
                    .padding(.horizontal)

                ForEach(searchResults, id: \.id) { track in
                    if track.songHref != nil {
                        Button {
                            Task {
                                self.tappedTrack = track
                                print(self.tappedTrack?.artist ?? "[Unknown]")
                                await viewModel.playTrackHref(track)
                                self.tappedTrack = nil
                            }
                        } label: {
                            HStack {
                                trackRow(track)

                                if self.tappedTrack == track {
                                    Spacer()

                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .padding(.trailing)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .ciderRowOptimized()
                    } else {
                        trackRow(track)
                            .ciderRowOptimized()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Divider()
                    .overlay { Color.white }
                    .padding(.horizontal)

                if #available(iOS 17.0, *) {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.magnifyingglass")
                            .imageScale(.large)
                            .font(.title2)
                            .padding(.bottom)

                        Text("No results for \"\(searchText)\"")
                            .font(.title3)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trackRow(_ track: Track, showDuration: Bool = false) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: track.artwork)) { phase in
                switch phase {
                    case .empty:
                        Color.gray.opacity(0.3)
                    case .success(let image):
                        image.resizable()
                    case .failure:
                        Image(systemName: "music.note")
                            .foregroundStyle(.gray)
                    @unknown default:
                        EmptyView()
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(track.artist)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            if showDuration {
                Spacer()

#if DEBUG
                if let trackIndex = self.viewModel.sourceQueue?.firstIndex(of: track), trackIndex >= 0 {
                    Text("\(trackIndex)")
                        .font(.caption.bold())
                }
#endif

                Text(formatDuration(track.duration))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
    }

    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
