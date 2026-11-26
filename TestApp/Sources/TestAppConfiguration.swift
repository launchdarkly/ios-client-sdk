import Foundation
import LaunchDarkly

/// What the app is built against: the mobile keys and which LaunchDarkly environment they talk to.
///
/// All come from `Config/Secrets.xcconfig` through the Info.plist. A launch argument overrides any of them, so a script
/// starting several instances can point them somewhere else without a rebuild: `-LDMobileKey mob-...`,
/// `-LDSecondaryMobileKey mob-...`, `-LDDeferredMobileKey mob-...`, `-LDPayloadFilter ios-flags` or `-LDEnvironment staging`.
struct TestAppConfiguration {
    // The staging hosts mirror the production ones under the ld-stg domain.
    private static let stagingDomain = "ld-stg.launchdarkly.com"

    let mobileKey: String
    /// Empty unless the build gives a second key, in which case the client starts both environments.
    let secondaryMobileKey: String
    /// Empty unless the build gives a third key, for an environment the client starts deferred: it requests no flags
    /// until the app starts it.
    let deferredMobileKey: String
    /// Empty for every flag. The app gives it to every environment, so each one needs a filter with this key.
    let payloadFilter: String
    let isStaging: Bool

    static let current = TestAppConfiguration(
        mobileKey: value(for: "LDMobileKey"),
        secondaryMobileKey: value(for: "LDSecondaryMobileKey"),
        deferredMobileKey: value(for: "LDDeferredMobileKey"),
        payloadFilter: value(for: "LDPayloadFilter"),
        isStaging: value(for: "LDEnvironment").caseInsensitiveCompare("staging") == .orderedSame
    )

    var environmentName: String { isStaging ? "staging" : "production" }

    var isMissingMobileKey: Bool { mobileKey.isEmpty }

    /// The SDK refuses a secondary key equal to another environment's, so that counts as no such environment.
    var hasSecondaryEnvironment: Bool { !secondaryMobileKey.isEmpty && secondaryMobileKey != mobileKey }

    var hasDeferredEnvironment: Bool {
        !deferredMobileKey.isEmpty && deferredMobileKey != mobileKey
            && !(hasSecondaryEnvironment && deferredMobileKey == secondaryMobileKey)
    }

    var environments: [TestEnvironment] {
        TestEnvironment.allCases.filter { environment in
            switch environment {
            case .primary: return true
            case .secondary: return hasSecondaryEnvironment
            case .deferred: return hasDeferredEnvironment
            }
        }
    }

    var hasSeveralEnvironments: Bool { environments.count > 1 }

    func mobileKey(for environment: TestEnvironment) -> String {
        switch environment {
        case .primary: return mobileKey
        case .secondary: return secondaryMobileKey
        case .deferred: return deferredMobileKey
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

/// One of the environments the client is started with: the primary one always, the secondary and deferred ones where
/// the build gives them a key. Each has its own `LDClient`, event store and directory.
enum TestEnvironment: String, CaseIterable, Identifiable {
    case primary
    case secondary
    /// Started without its flags: its client serves the cached ones until the app calls `LDClient.start(environment:)`.
    case deferred

    var id: String { rawValue }

    /// The name the SDK knows the environment by, for `LDClient.get(environment:)`.
    var sdkName: String {
        switch self {
        case .primary: return LDConfig.Constants.primaryEnvironmentName
        case .secondary: return "secondary"
        case .deferred: return "deferred"
        }
    }

    var title: String { rawValue.capitalized }
}
