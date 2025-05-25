// Made by Lumaa

import Foundation
import AppIntents

struct TogglePlayIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause a Cider instance"
    static var description: IntentDescription = IntentDescription(stringLiteral: "Allows you press play or press pause in an active Cider instance")

    @Parameter(title: "Device", requestDisambiguationDialog: IntentDialog(stringLiteral: "What Cider device do you want to use?"))
    var device: DeviceEntity

    init() {}

    init(device: DeviceEntity) {
        self.device = device
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle play/pause on \(\.$device)")
    }

    func perform() async throws -> some IntentResult {
        let (statusCode, _) = try await device.sendRequest(endpoint: "playback/active")

        if statusCode == 200 {
            (_, _) = try await device.sendRequest(endpoint: "playback/playpause", method: "POST")
            return .result()
        } else {
            print("[AppIntent] - No toggle \(statusCode)")
        }
        return .result()
    }
}

/// This is the exact same as ``TogglePlayIntent`` but used in the ``NowPlayingLiveActivity``
struct TogglePlayButtonIntent: AppIntent {
    static var title: LocalizedStringResource = "Play/Pause a Cider instance"
    static var description: IntentDescription = IntentDescription(stringLiteral: "Allows you press play or press pause in an active Cider instance")

    static var isDiscoverable: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle play/pause on Cider")
    }

    func perform() async throws -> some IntentResult {
        let devices: [DeviceEntity] = try await DeviceQuery().suggestedEntities()

        for device in devices {
            let (statusCode, _) = try await device.sendRequest(endpoint: "playback/active")

            if statusCode == 200 {
                (_, _) = try await device.sendRequest(endpoint: "playback/playpause", method: "POST")
                return .result()
            } else {
                print("[AppIntent] - No toggle \(statusCode)")
            }
        }

        return .result()
    }
}
