// Made by Lumaa

import SwiftUI

struct LyricsView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @EnvironmentObject var colorSchemeManager: ColorSchemeManager

    @ObservedObject var viewModel: MusicPlayerViewModel
    @State private var activeLine: LyricLine?

    private let lineSpacing: CGFloat = 18 // Increased spacing between lines
    private let lyricAdvanceTime: Double = 0.3 // Advance lyrics 0.5 seconds early

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Material.thin)
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
                                            .foregroundStyle(.gray)
                                    @unknown default:
                                        EmptyView()
                                }
                            }
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentTrack.title)
                                    .font(.system(size: 18, weight: .bold))
                                    .lineLimit(1)
                                Text(currentTrack.artist)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 28))
                        }
                        .padding(.trailing, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                    Divider().padding(.horizontal, 20)


                    if viewModel.lyrics.isEmpty {
                        Spacer()

                        Text("No lyrics available")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                            .padding()

                        Spacer()
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
        .foregroundStyle(colorScheme == .dark ? .white : .black)
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

    var body: some View {
        Text(lyric.text)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(textColor)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(nil)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .scaleEffect(isActive ? 1.0 : 0.7, anchor: .leading)
            .animation(.spring(duration: 0.3), value: isActive)
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
