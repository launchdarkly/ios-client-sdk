//
//  LDConfigStub.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 9/29/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

@testable import LaunchDarkly

extension LDConfig {

    struct Constants {
        static let mockMobileKey = "mockMobileKey"
        static let alternateMobileKey = "alternateMobileKey"
    }

    static var stub: LDConfig {
        return stub(mobileKey: Constants.mockMobileKey, environmentReporter: EnvironmentReportingMock())
    }

    static func stub(mobileKey: String, environmentReporter: EnvironmentReportingMock) -> LDConfig {
        var config = LDConfig(mobileKey: mobileKey, environmentReporter: environmentReporter)
        config.baseUrl = DarklyServiceMock.Constants.mockBaseUrl
        config.eventsUrl = DarklyServiceMock.Constants.mockEventsUrl
        config.streamUrl = DarklyServiceMock.Constants.mockStreamUrl

        config.flagPollingInterval = 1.0

        config.enableBackgroundUpdates = true

        return config
    }
}
