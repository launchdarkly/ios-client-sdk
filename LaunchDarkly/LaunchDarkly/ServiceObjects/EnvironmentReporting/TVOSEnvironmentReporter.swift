#if os(tvOS)
import Foundation
import UIKit

class TVOSEnvironmentReporter: EnvironmentReporterChainBase {
    override var deviceModel: String { UIDevice.current.model }
    override var systemVersion: String { UIDevice.current.systemVersion }
}
#endif
