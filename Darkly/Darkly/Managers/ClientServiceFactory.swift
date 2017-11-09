//
//  ClientServiceFactory.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

protocol ClientServiceCreating {
    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig) -> DarklyServiceProvider
    func makeFlagSynchronizer(mobileKey: String, pollingInterval: TimeInterval, user: LDUser, service: DarklyServiceProvider, store: LDFlagMaintaining) -> LDFlagSynchronizing
    func makeEventReporter(mobileKey: String, config: LDConfig, service: DarklyServiceProvider) -> LDEventReporting
    func makeFlagStore() -> LDFlagMaintaining
}

struct ClientServiceFactory: ClientServiceCreating {
    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig) -> DarklyServiceProvider {
        return DarklyService(mobileKey: mobileKey, config: config)
    }

    func makeFlagSynchronizer(mobileKey: String, pollingInterval: TimeInterval, user: LDUser, service: DarklyServiceProvider, store: LDFlagMaintaining) -> LDFlagSynchronizing {
        return LDFlagSynchronizer(mobileKey: mobileKey, pollingInterval: pollingInterval, user: user, service: service, store: store)
    }

    func makeEventReporter(mobileKey: String, config: LDConfig, service: DarklyServiceProvider) -> LDEventReporting {
        return LDEventReporter(mobileKey: mobileKey, config: config, service: service)
    }

    func makeFlagStore() -> LDFlagMaintaining {
        return LDFlagStore()
    }
}
