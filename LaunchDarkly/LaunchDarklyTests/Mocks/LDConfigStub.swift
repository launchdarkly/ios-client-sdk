//
//  LDConfigStub.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
@testable import LaunchDarkly

extension LDConfig {

    struct Constants {
        static let mockMobileKey = "mockMobileKey"
        static let alternateMobileKey = "alternateMobileKey"
    }

    static var stub: LDConfig {
        stub(mobileKey: Constants.mockMobileKey, environmentReporter: EnvironmentReportingMock())
    }

    static func stub(mobileKey: String, environmentReporter: EnvironmentReportingMock) -> LDConfig {
        var config = LDConfig(mobileKey: mobileKey, environmentReporter: environmentReporter)
        config.baseUrl = DarklyServiceMock.Constants.mockBaseUrl
        config.eventsUrl = DarklyServiceMock.Constants.mockEventsUrl
        config.streamUrl = DarklyServiceMock.Constants.mockStreamUrl

        config.flagPollingInterval = 1.0

        return config
    }
}
