//
//  ClientServiceFactory.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

protocol ClientServiceCreating {
    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig, user: LDUser) -> DarklyServiceProvider
    func makeFlagSynchronizer(mobileKey: String, streamingMode: LDStreamingMode, pollingInterval: TimeInterval, service: DarklyServiceProvider, store: LDFlagMaintaining) -> LDFlagSynchronizing
    func makeEventReporter(mobileKey: String, config: LDConfig, service: DarklyServiceProvider) -> LDEventReporting
}

struct ClientServiceFactory: ClientServiceCreating {
    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig, user: LDUser) -> DarklyServiceProvider {
        return DarklyService(mobileKey: mobileKey, config: config, user: user)
    }

    func makeFlagSynchronizer(mobileKey: String, streamingMode: LDStreamingMode, pollingInterval: TimeInterval, service: DarklyServiceProvider, store: LDFlagMaintaining) -> LDFlagSynchronizing {
        return LDFlagSynchronizer(mobileKey: mobileKey, streamingMode: streamingMode, pollingInterval: pollingInterval, service: service, store: store)
    }

    func makeEventReporter(mobileKey: String, config: LDConfig, service: DarklyServiceProvider) -> LDEventReporting {
        return LDEventReporter(mobileKey: mobileKey, config: config, service: service)
    }
}
