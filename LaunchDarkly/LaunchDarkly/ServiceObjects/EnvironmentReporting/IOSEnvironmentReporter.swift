#if os(iOS)
import Foundation
import UIKit

class IOSEnvironmentReporter: EnvironmentReporterChainBase {
    override var deviceModel: String { UIDevice.current.model }
    override var systemVersion: String { UIDevice.current.systemVersion }
}
#endif
