//
//  ClientServiceMockFactory.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

@testable import Darkly

struct ClientServiceMockFactory: ClientServiceCreating {
    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig, user: LDUser) -> DarklyServiceProvider { return DarklyServiceMock(config: config) }

    func makeFlagSynchronizer(mobileKey: String, streamingMode: LDStreamingMode, pollingInterval: TimeInterval, service: DarklyServiceProvider, store: LDFlagMaintaining) -> LDFlagSynchronizing {
        let synchronizerMock = LDFlagSynchronizingMock()
        synchronizerMock.streamingMode = streamingMode
        synchronizerMock.pollingInterval = pollingInterval
        return synchronizerMock
    }

    func makeEventReporter(mobileKey: String, config: LDConfig, service: DarklyServiceProvider) -> LDEventReporting {
        let reporterMock = LDEventReportingMock()
        reporterMock.config = config
        return reporterMock
    }

    func makeFlagStore() -> LDFlagMaintaining {
        return LDFlagMaintainingMock()
    }
}
