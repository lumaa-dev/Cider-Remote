// Made by Lumaa

import UIKit
import ActivityKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    func applicationWillTerminate(_ application: UIApplication) {
        print("App terminated")
        if let activity = Activity<NowPlayingLiveActivity.NowPlayingAttributes>.activities.first {
            Task {
                if #available(iOS 16.2, *) {
                    await activity.end(activity.content, dismissalPolicy: .immediate)
                } else {
                    await activity.end(using: activity.contentState, dismissalPolicy: .immediate)
                }
            }
        }
    }
}
