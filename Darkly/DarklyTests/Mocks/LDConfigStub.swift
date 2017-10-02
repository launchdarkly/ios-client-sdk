//
//  LDConfigStub.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 9/29/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

@testable import Darkly

extension LDConfig {
    static var stub: LDConfig {
        var config = LDConfig()
        config.baseUrl = DarklyServiceMock.Constants.mockBaseUrl
        config.eventsUrl = DarklyServiceMock.Constants.mockEventsUrl
        config.streamUrl = DarklyServiceMock.Constants.mockStreamUrl

        config.pollIntervalMillis = 1000

        return config
    }
}
