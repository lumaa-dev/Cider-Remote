// Made by Lumaa

import UIKit

/// The device in-use by the user to run Cider Remote
class UserDevice: ObservableObject {
    static let shared: UserDevice = .init()

    var orientation: UIDeviceOrientation {
        UIDevice.current.orientation
    }

    private var deviceHOrientation: HorizontalOrientation {
        get throws {
            switch self.orientation {
                case .unknown, .portrait:
                    return .portrait
                case .portraitUpsideDown:
                    return .portraitDown
                case .landscapeLeft:
                    return .landscapeLeft
                case .landscapeRight:
                    return .landscapeRight
                case .faceUp, .faceDown:
                    throw DeviceError(message: "Orientation is unavailable horizontally")
                @unknown default:
                    return .portrait
            }
        }
    }

    private var prevOrientation: HorizontalOrientation = .portrait
    private var _horizontalOrientation: HorizontalOrientation = .portrait

    var horizontalOrientation: HorizontalOrientation {
        get {
            prevOrientation = _horizontalOrientation
            switch self.orientation {
                case .unknown, .portrait, .portraitUpsideDown:
                    _horizontalOrientation = .portrait
                    return .portrait
                case .landscapeLeft:
                    _horizontalOrientation = .landscapeLeft
                    return .landscapeLeft
                case .landscapeRight:
                    _horizontalOrientation = .landscapeRight
                    return .landscapeRight
                case .faceUp, .faceDown:
                    _horizontalOrientation = self.prevOrientation
                    return self.prevOrientation
                @unknown default:
                    _horizontalOrientation = self.prevOrientation
                    return self.prevOrientation
            }
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
