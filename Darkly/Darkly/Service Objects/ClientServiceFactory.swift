//
//  ClientServiceFactory.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation
import DarklyEventSource

protocol ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching
    func makeCacheConverter() -> UserCacheConverting
    func makeCacheConverter(keyStore: KeyedValueCaching) -> UserCacheConverting
    func makeFlagCollectionCache(keyStore: KeyedValueCaching) -> FlagCollectionCaching
    func makeUserFlagCache() -> UserFlagCaching
    func makeUserFlagCache(flagCollectionStore: FlagCollectionCaching) -> UserFlagCaching
    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig, user: LDUser) -> DarklyServiceProvider
    mutating func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                                       pollingInterval: TimeInterval,
                                       useReport: Bool,
                                       service: DarklyServiceProvider,
                                       onSyncComplete: SyncCompleteClosure?) -> LDFlagSynchronizing
    func makeFlagChangeNotifier() -> FlagChangeNotifying
    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> EventReporting
    mutating func makeStreamingProvider(url: URL, httpHeaders: [String: String]) -> DarklyStreamingProvider
    mutating func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?) -> DarklyStreamingProvider
    func makeEnvironmentReporter() -> EnvironmentReporting
    func makeThrottler(maxDelay: TimeInterval) -> Throttling
}

struct ClientServiceFactory: ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching {
        return UserDefaults.standard
    }

    func makeCacheConverter() -> UserCacheConverting {
        return makeCacheConverter(keyStore: makeKeyedValueCache())
    }

    func makeCacheConverter(keyStore: KeyedValueCaching) -> UserCacheConverting {
        return UserCacheConverter(keyStore: keyStore, flagCollectionCache: makeFlagCollectionCache(keyStore: keyStore))
    }

    func makeFlagCollectionCache(keyStore: KeyedValueCaching) -> FlagCollectionCaching {
        return FlagCollectionCache(keyStore: keyStore)
    }

    func makeUserFlagCache() -> UserFlagCaching {
        return UserFlagCache(flagCollectionStore: makeFlagCollectionCache(keyStore: makeKeyedValueCache()))
    }

    func makeUserFlagCache(flagCollectionStore: FlagCollectionCaching) -> UserFlagCaching {
        return UserFlagCache(flagCollectionStore: flagCollectionStore)
    }

    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig, user: LDUser) -> DarklyServiceProvider {
        return DarklyService(mobileKey: mobileKey, config: config, user: user, serviceFactory: self)
    }

    func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                              pollingInterval: TimeInterval,
                              useReport: Bool,
                              service: DarklyServiceProvider,
                              onSyncComplete: SyncCompleteClosure?) -> LDFlagSynchronizing {
        return FlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, service: service, onSyncComplete: onSyncComplete)
    }

    func makeFlagChangeNotifier() -> FlagChangeNotifying {
        return FlagChangeNotifier()
    }

    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> EventReporting {
        return EventReporter(config: config, service: service)
    }

    func makeStreamingProvider(url: URL, httpHeaders: [String: String]) -> DarklyStreamingProvider {
        return LDEventSource(url: url, httpHeaders: httpHeaders)
    }

    func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?) -> DarklyStreamingProvider {
        return LDEventSource(url: url, httpHeaders: httpHeaders, connectMethod: connectMethod, connectBody: connectBody)
    }

    func makeEnvironmentReporter() -> EnvironmentReporting {
        return EnvironmentReporter()
    }

    func makeThrottler(maxDelay: TimeInterval) -> Throttling {
        return Throttler(maxDelay: maxDelay)
    }
}
