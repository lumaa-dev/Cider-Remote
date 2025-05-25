// Made by Lumaa

import Foundation
import AppIntents

enum PlaybackEnum: String, AppEnum {
    case toggle = "playback/playpause"
    case play = "playback/play"
    case pause = "playback/pause"

    static var caseDisplayRepresentations: [PlaybackEnum : DisplayRepresentation] {
        [
            .toggle: DisplayRepresentation(stringLiteral: "Toggle"),
            .play: DisplayRepresentation(stringLiteral: "Play"),
            .pause: DisplayRepresentation(stringLiteral: "Pause")
        ]
    }
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Action"
}
