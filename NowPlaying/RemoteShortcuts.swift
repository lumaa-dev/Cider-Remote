// Made by Lumaa

import Foundation
import AppIntents

struct RemoteShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: TogglePlayIntent(),
                phrases: [
                    "Pause on \(.applicationName)",
                    "Play on \(.applicationName)",
                    "Stop \(.applicationName)"
                ],
                shortTitle: "Play/Pause Remote",
                systemImageName: "playpause.fill"
            )
        ]
    }
}
