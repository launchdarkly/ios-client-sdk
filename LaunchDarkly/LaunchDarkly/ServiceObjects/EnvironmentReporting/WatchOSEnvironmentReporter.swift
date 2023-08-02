#if os(watchOS)
import Foundation
import WatchKit

class WatchOSEnvironmentReporter: EnvironmentReporterChainBase {
    override var deviceModel: String { WKInterfaceDevice.current().model }
    override var systemVersion: String { WKInterfaceDevice.current().systemVersion }
}
#endif
