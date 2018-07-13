//
//  LDConfigStub.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/29/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

@testable import LaunchDarkly

extension LDConfig {
    static var stub: LDConfig { return stub(environmentReporter: EnvironmentReportingMock()) }

    static func stub(environmentReporter: EnvironmentReportingMock) -> LDConfig {
        var config = LDConfig(environmentReporter: environmentReporter)
        config.baseUrl = DarklyServiceMock.Constants.mockBaseUrl
        config.eventsUrl = DarklyServiceMock.Constants.mockEventsUrl
        config.streamUrl = DarklyServiceMock.Constants.mockStreamUrl

        config.pollIntervalMillis = 1000

        config.enableBackgroundUpdates = true

        return config
    }
}
