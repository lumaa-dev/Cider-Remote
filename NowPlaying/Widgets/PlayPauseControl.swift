// Made by Lumaa

import SwiftUI
import WidgetKit
import AppIntents

@available(iOS 18.0, *)
struct PlayPauseControl: ControlWidget {
    static let kind: String = "sh.cider.CiderRemote.PlayPauseControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: Self.Provider()) { device in
            ControlWidgetToggle(
                device.name,
                isOn: device.isPlaying,
                action: TogglePlayIntent(device: device),
                valueLabel: { isPlaying in
                    Label(isPlaying ? "Playing" : "Paused", systemImage: isPlaying ? "play.fill" : "pause.fill")
                        .controlWidgetActionHint(isPlaying ? "Play track" : "Pause track")
                }
            )
            .tint(Color.cider)
        }
        .displayName("Play/Pause a device")
        .description("Play or pause any selected Cider device")
        .promptsForUserConfiguration()
    }

    struct Configuration: ControlConfigurationIntent {
        static var title: LocalizedStringResource = "Select a Device"
        static var description: IntentDescription?  = IntentDescription(stringLiteral: "Select the Cider instance to use the play/pause action.")

        @Parameter(title: "Device")
        var device: DeviceEntity

        init(device: DeviceEntity) {
            self.device = device
        }

        init() {}
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: PlayPauseControl.Configuration) -> DeviceEntity {
            return configuration.device
        }

        func currentValue(configuration: PlayPauseControl.Configuration) async throws -> DeviceEntity {
            return try await self.fetchPlaying(configuration)
        }

        private func fetchPlaying(_ configuration: PlayPauseControl.Configuration) async throws -> DeviceEntity {
            var device = configuration.device

            let (status, data) = try await device.sendRequest(endpoint: "playback/is-playing", method: "GET")
            if status == 200 {
                if let jsonDict = data as? [String: Any] {
                    let j = jsonDict["is_playing"] as? Int == 1
                    print(j ? "[Control] - playing" : "[Control - paused]")
                    device.isPlaying = j

                    return device
                } else {
                    device.isPlaying = false
                    return device
                }
            } else {
                device.isPlaying = false
                return device
            }
        }
    }
}
