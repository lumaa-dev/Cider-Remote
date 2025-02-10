// Made by Lumaa

import ActivityKit
import WidgetKit
import SwiftUI

struct NowPlayingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NowPlayingAttributes.self) { context in
            expandView(using: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform")
                        .font(.body)
                        .foregroundStyle(Color.pink)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    expandView(using: context, dynamicIsland: true)
                }
            } compactLeading: {
                Image(systemName: "waveform")
                    .font(.body)
                    .foregroundStyle(Color.pink)
//                if let artwork = context.state.getArtwork() {
//                    Image(uiImage: artwork)
//                        .resizable()
//                        .frame(width: 10, height: 10, alignment: .center)
//                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
//                } else {
//                    RoundedRectangle(cornerRadius: 5.0)
//                        .fill(Material.thin)
//                        .frame(width: 10, height: 10, alignment: .center)
//                }
            } compactTrailing: {
                Image("Logo")
                    .resizable()
                    .scaledToFill()
            } minimal: {
//                if let artwork = context.state.getArtwork() {
//                    Image(uiImage: artwork)
//                        .resizable()
//                        .frame(width: 10, height: 10, alignment: .center)
//                        .clipShape(RoundedRectangle(cornerRadius: 5.0))
//                } else {
//                    RoundedRectangle(cornerRadius: 5.0)
//                        .fill(Material.thin)
//                        .frame(width: 10, height: 10, alignment: .center)
//                }
                Image("Logo")
                    .resizable()
                    .scaledToFill()
            }
            .keylineTint(Color.pink)
        }
    }

    @ViewBuilder
    private func expandView(using context: ActivityViewContext<NowPlayingAttributes>, dynamicIsland: Bool = false) -> some View {
        HStack {
            ZStack {
                Image(uiImage: /*UIImage(data: context.state.trackInfo.artworkData) ?? */UIImage.logo) // TEMPORARY SOLUTION
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 3.0))
//                if let artwork = context.state.getArtwork() {
//                    Image(uiImage: artwork)
//                        .resizable()
//                        .frame(width: 30, height: 30, alignment: .center)
//                        .clipShape(RoundedRectangle(cornerRadius: 3.0))
//                } else {
//                    RoundedRectangle(cornerRadius: 3.0)
//                        .fill(Material.thin)
//                        .frame(width: 30, height: 30, alignment: .center)
//                        .shadow(color: .black, radius: 5.0)
//                }
            }
//            .overlay(alignment: .bottomTrailing) {
//                if !dynamicIsland {
//                    Image("Logo")
//                        .resizable()
//                        .frame(width: 15, height: 15, alignment: .bottomTrailing)
//                }
//            }

            VStack(alignment: .leading) {
                Text(context.state.trackInfo.title)
                    .font(.body.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(context.state.trackInfo.artist)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(Color.gray)
            }
            .padding(.horizontal)

            Spacer()

            // TODO: Button to pause/play using AppIntent
            Image(systemName: "waveform")
                .font(.title2)
        }
        .padding(.horizontal)
        .padding(.vertical, 7.5)
    }

    struct NowPlayingAttributes: ActivityAttributes {
        public struct ContentState: Codable, Hashable {
            public func hash(into hasher: inout Hasher) {
                hasher.combine(trackInfo.id)
            }

            var trackInfo: Track

            func getArtwork() -> UIImage? {
                return self.trackInfo.getArtwork()
            }
        }
    }
}
