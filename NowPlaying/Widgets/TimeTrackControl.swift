// Made by Lumaa

import SwiftUI
import WidgetKit
import AppIntents

@available(iOS 18.0, *)
struct TimeTrackControl: ControlWidget {
    static let kind: String = "sh.cider.CiderRemote.TimeTrackControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, intent: Self.TimeTrackConfiguration.self) { config in
            let device = config.device ?? .placeholder

            ControlWidgetButton(
                "\(config.action?.localizedStringResource ?? TimeTrack.skip.localizedStringResource)",
                action: TimeTrackIntent(device: device, timeAction: config.action ?? .skip)
            ) { bool in
                Label(device.name, systemImage: config.action?.systemImage ?? "questionmark.app.dashed")
            }
            .tint(Color.cider)
        }
        .displayName("Skip/Go back a track")
        .description("Skip or go back a track on any selected Cider device")
        .promptsForUserConfiguration()
    }

    struct TimeTrackConfiguration: ControlConfigurationIntent {
        static var title: LocalizedStringResource = "Select a Device & an action"
        static var description: IntentDescription?  = IntentDescription(stringLiteral: "Select the Cider instance, and the action to perform.")

        @Parameter(title: "Device")
        var device: DeviceEntity?

        @Parameter(title: "Action")
        var action: TimeTrack?

        init(device: DeviceEntity, timeAction: TimeTrack = .skip) {
            self.device = device
            self.action = timeAction
        }

        init() {}
    }
}
