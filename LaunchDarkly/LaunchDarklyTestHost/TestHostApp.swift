import SwiftUI

/// The application the unit tests run in on tvOS and watchOS, which a device needs: it runs no test bundle on its own.
@main
struct TestHostApp: App {
    var body: some Scene {
        WindowGroup {
            Color.clear
            #if os(tvOS)
                .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            #endif
        }
    }
}
