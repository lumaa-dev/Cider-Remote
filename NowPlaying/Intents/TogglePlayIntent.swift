// Made by Lumaa

import Foundation
import AppIntents

struct TogglePlayIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause a Cider instance"
    static var description: IntentDescription = IntentDescription(stringLiteral: "Allows you press play or press pause in an active Cider instance")

    @Parameter(title: "Device", requestDisambiguationDialog: IntentDialog(stringLiteral: "What Cider device do you want to use?"))
    var device: DeviceEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle play/pause on \(\.$device)")
    }

    func perform() async throws -> some IntentResult {
        let (statusCode, _) = try await device.sendRequest(endpoint: "playback/active")

        if statusCode == 200 {
            (_, _) = try await device.sendRequest(endpoint: "playback/playpause", method: "POST")
            return .result()
        }
        return .result()
    }
}
