// Made by Lumaa

import UIKit

/// The device in-use by the user to run Cider Remote
class UserDevice: ObservableObject {
    static let shared: UserDevice = .init()

    var orientation: UIDeviceOrientation {
        UIDevice.current.orientation
    }

    var horizontalOrientation: HorizontalOrientation {
        switch self.orientation {
            case .unknown:
                return .portrait
            case .portrait:
                return .portrait
            case .portraitUpsideDown:
                return .portraitDown
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            case .faceUp:
                return self.horizontalOrientation // return same as previous orientation
            case .faceDown:
                return self.horizontalOrientation
            @unknown default:
                return .portrait
        }
    }

    var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    init() {}

    enum HorizontalOrientation {
        case portrait
        case portraitDown
        case landscapeLeft
        case landscapeRight
    }
}
