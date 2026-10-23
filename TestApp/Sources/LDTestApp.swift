import SwiftUI

@main
struct LDTestApp: App {
    @StateObject private var controller = ClientController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .onAppear { controller.start() }
        }
        #if os(macOS)
        .defaultSize(width: 520, height: 760)
        #endif
    }
}
