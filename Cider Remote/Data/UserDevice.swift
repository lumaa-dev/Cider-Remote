// Made by Lumaa

import UIKit

/// The device in-use by the user to run Cider Remote
class UserDevice: ObservableObject {
    static let shared: UserDevice = .init()

    var orientation: UIDeviceOrientation {
        UIDevice.current.orientation
    }

    var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    init() {}
}
