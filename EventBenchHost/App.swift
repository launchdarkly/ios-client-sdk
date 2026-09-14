import UIKit

/// Empty host so `LaunchDarklyTests` can run on a physical device.
///
/// Xcode will not tool-host XCTest on iOS hardware; the test bundle has to be injected into an app. This one exists
/// only for that, and is not a product.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
