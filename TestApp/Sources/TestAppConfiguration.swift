import Foundation
import LaunchDarkly

/// What the app is built against: the mobile key and which LaunchDarkly environment it talks to.
///
/// Both come from `Config/Secrets.xcconfig` through the Info.plist. A launch argument overrides either, so a script
/// starting several instances can point them somewhere else without a rebuild: `-LDMobileKey mob-...` or
/// `-LDEnvironment staging`.
struct TestAppConfiguration {
    // The staging hosts mirror the production ones under the ld-stg domain.
    private static let stagingDomain = "ld-stg.launchdarkly.com"

    let mobileKey: String
    let isStaging: Bool

    static let current = TestAppConfiguration(
        mobileKey: value(for: "LDMobileKey"),
        isStaging: value(for: "LDEnvironment").caseInsensitiveCompare("staging") == .orderedSame
    )

    var environmentName: String { isStaging ? "staging" : "production" }

    var isMissingMobileKey: Bool { mobileKey.isEmpty }

    /// Points the endpoints at staging where the build asks for it, and leaves the production defaults otherwise.
    func applyEndpoints(to config: inout LDConfig) {
        guard isStaging
        else { return }
        config.baseUrl = URL(string: "https://clientsdk.\(Self.stagingDomain)")!
        config.streamUrl = URL(string: "https://clientstream.\(Self.stagingDomain)")!
        config.eventsUrl = URL(string: "https://mobile.\(Self.stagingDomain)")!
    }

    private static func value(for key: String) -> String {
        if let overridden = UserDefaults.standard.string(forKey: key), !overridden.isEmpty {
            return overridden
        }
        return (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }
}
