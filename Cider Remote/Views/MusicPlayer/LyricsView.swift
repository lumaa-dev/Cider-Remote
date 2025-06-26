// Made by Lumaa

import SwiftUI

struct LyricsView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @EnvironmentObject var colorSchemeManager: ColorSchemeManager

    @ObservedObject var viewModel: MusicPlayerViewModel
    @ObservedObject private var userDevice: UserDevice = .shared

    @State private var activeLine: LyricLine?

    private let lineSpacing: CGFloat = 18 // Increased spacing between lines
    private let lyricAdvanceTime: Double = 0.3 // Advance lyrics 0.5 seconds early

    private var lyricProviderString: String? {
        guard let prov =  viewModel.lyricsProvider else { return nil }

        switch prov {
            case .mxm:
                return "Musixmatch"
            case .am:
                return "Apple Music"
            case .cache:
                return "Remote (Cache)"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    Divider().padding(.horizontal, 20)


                    if let lyrics = viewModel.lyrics {
                        if lyrics.isEmpty {
                            Spacer()

                            VStack {
                                if #available(iOS 17.0, *) {
                                    ContentUnavailableView("No lyrics available", systemImage: "quote.bubble")
                                } else {
                                    Text("No lyrics available")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.secondary)
                                        .padding()
                                }
                            }

                            Spacer()
                        } else {
                            ZStack {
                                if userDevice.horizontalOrientation == .portrait || userDevice.isPad {
                                    LyricsScrollView(
                                        lyrics: lyrics,
                                        activeLine: $activeLine,
                                        currentTime: $viewModel.currentTime,
                                        viewportHeight: geometry.size.height,
                                        lineSpacing: lineSpacing
                                    )
                                } else {
                                    ImmersiveLyricsView(
                                        lyrics: lyrics,
                                        activeLine: $activeLine,
                                        currentTime: $viewModel.currentTime
                                    )
                                }
                            }
                            .overlay(alignment: .bottom) {
                                if let lyricProviderString {
                                    if #available(iOS 26.0, *) {
                                        Text(lyricProviderString)
                                            .font(.callout)
                                            .padding(.horizontal)
                                            .padding(.vertical, 7.5)
                                            .glassEffect(.regular, in: .capsule)
                                            .padding(.bottom, 22.5)
                                    } else {
                                        Text(lyricProviderString)
                                            .font(.callout)
                                            .padding(.horizontal)
                                            .padding(.vertical, 7.5)
                                            .background(Material.thin)
                                            .clipShape(.capsule)
                                            .padding(.bottom, 22.5)
                                    }
                                }
                            }
                        }
                    } else {
                        Spacer()

                        ProgressView()
                            .progressViewStyle(.circular)

                        Spacer()
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
        .foregroundStyle(colorScheme == .dark ? .white : .black)
        .onAppear {
            if viewModel.lyrics == nil {
                Task {
                    await viewModel.fetchAllLyrics()
                }
            }
        }
        .onDisappear {
        }
        .onChange(of: viewModel.currentTime) { _, newTime in
            updateCurrentLyric(time: newTime + lyricAdvanceTime)
        }
    }

    private func updateCurrentLyric(time: Double) {
        guard let lyrics = viewModel.lyrics, let currentLine = lyrics.last(where: { $0.timestamp <= time }) else {
            activeLine = nil
            return
        }

        withAnimation(.easeInOut.speed(0.85)) {
            activeLine = currentLine
        }
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
                .onChange(of: activeLine) { _, newActiveLine in
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
    }
}

struct ImmersiveLyricsView: View {
    let lyrics: [LyricLine]
    @Binding var activeLine: LyricLine?
    @Binding var currentTime: Double

    var body: some View {
        if let activeLine {
            Text(activeLine.text)
                .font(.system(size: 52).bold())
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText(countsDown: true))
                .frame(maxHeight: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
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

// MARK: Lyric Data

struct LyricLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let timestamp: Double
    let isMainLyric: Bool
}
