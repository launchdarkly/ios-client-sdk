import Foundation
import LaunchDarkly

/// What the app is built against: the mobile keys and which LaunchDarkly environment they talk to.
///
/// All come from `Config/Secrets.xcconfig` through the Info.plist. A launch argument overrides any of them, so a script
/// starting several instances can point them somewhere else without a rebuild: `-LDMobileKey mob-...`,
/// `-LDSecondaryMobileKey mob-...` or `-LDEnvironment staging`.
struct TestAppConfiguration {
    // The staging hosts mirror the production ones under the ld-stg domain.
    private static let stagingDomain = "ld-stg.launchdarkly.com"

    let mobileKey: String
    /// Empty unless the build gives a second key, in which case the client starts both environments.
    let secondaryMobileKey: String
    let isStaging: Bool

    static let current = TestAppConfiguration(
        mobileKey: value(for: "LDMobileKey"),
        secondaryMobileKey: value(for: "LDSecondaryMobileKey"),
        isStaging: value(for: "LDEnvironment").caseInsensitiveCompare("staging") == .orderedSame
    )

    var environmentName: String { isStaging ? "staging" : "production" }

    var isMissingMobileKey: Bool { mobileKey.isEmpty }

    /// The SDK refuses a secondary key equal to the primary one, so that counts as no second environment.
    var hasSecondaryEnvironment: Bool { !secondaryMobileKey.isEmpty && secondaryMobileKey != mobileKey }

    var environments: [TestEnvironment] { hasSecondaryEnvironment ? TestEnvironment.allCases : [.primary] }

    func mobileKey(for environment: TestEnvironment) -> String {
        switch environment {
        case .primary: return mobileKey
        case .secondary: return secondaryMobileKey
        }
    }

    /// Points the endpoints at staging where the build asks for it, and leaves the production defaults otherwise.
    func applyEndpoints(to config: inout LDConfig) {
        guard isStaging
        else { return }
        config.baseUrl = URL(string: "https://app.\(Self.stagingDomain)")!
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

/// One of the environments the client is started with: the primary one always, the secondary one where the build gives
/// it a key. Each has its own `LDClient`, event store and directory.
enum TestEnvironment: String, CaseIterable, Identifiable {
    case primary
    case secondary

    var id: String { rawValue }

    /// The name the SDK knows the environment by, for `LDClient.get(environment:)`.
    var sdkName: String {
        switch self {
        case .primary: return LDConfig.Constants.primaryEnvironmentName
        case .secondary: return "secondary"
        }
    }

    var title: String { rawValue.capitalized }
}
