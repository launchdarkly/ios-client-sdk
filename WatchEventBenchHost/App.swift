import SwiftUI

/// Empty host that lets XCTest execute the event benchmark on watchOS hardware.
@main
struct WatchEventBenchHostApp: App {
    var body: some Scene {
        WindowGroup {
            Color.clear
        }
    }
}
