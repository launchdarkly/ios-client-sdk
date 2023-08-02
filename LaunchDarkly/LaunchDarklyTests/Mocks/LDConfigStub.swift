import Foundation
@testable import LaunchDarkly

extension LDConfig {

    struct Constants {
        static let mockMobileKey = "mockMobileKey"
        static let alternateMobileKey = "alternateMobileKey"
    }

    static var stub: LDConfig {
        stub(mobileKey: Constants.mockMobileKey, autoEnvAttributes: .disabled, isDebugBuild: true)
    }

    static func stub(mobileKey: String, autoEnvAttributes: AutoEnvAttributes, isDebugBuild: Bool) -> LDConfig {
        var config = LDConfig(mobileKey: mobileKey, autoEnvAttributes: autoEnvAttributes, isDebugBuild: isDebugBuild)
        config.baseUrl = DarklyServiceMock.Constants.mockBaseUrl
        config.eventsUrl = DarklyServiceMock.Constants.mockEventsUrl
        config.streamUrl = DarklyServiceMock.Constants.mockStreamUrl

        config.flagPollingInterval = 1.0

        return config
    }
}
