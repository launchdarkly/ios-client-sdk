//
//  ClientServiceFactory.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
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
    func makeDarklyServiceProvider(config: LDConfig, user: LDUser) -> DarklyServiceProvider
    mutating func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider) -> LDFlagSynchronizing
    mutating func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                                       pollingInterval: TimeInterval,
                                       useReport: Bool,
                                       service: DarklyServiceProvider,
                                       onSyncComplete: FlagSyncCompleteClosure?) -> LDFlagSynchronizing
    func makeFlagChangeNotifier() -> FlagChangeNotifying
    mutating func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> EventReporting
    mutating func makeEventReporter(config: LDConfig, service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) -> EventReporting
    mutating func makeStreamingProvider(url: URL, httpHeaders: [String: String]) -> DarklyStreamingProvider
    mutating func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?) -> DarklyStreamingProvider
    func makeEnvironmentReporter() -> EnvironmentReporting
    func makeThrottler(maxDelay: TimeInterval, environmentReporter: EnvironmentReporting) -> Throttling
    func makeErrorNotifier() -> ErrorNotifying
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

    func makeDarklyServiceProvider(config: LDConfig, user: LDUser) -> DarklyServiceProvider {
        return DarklyService(config: config, user: user, serviceFactory: self)
    }

    func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider) -> LDFlagSynchronizing {
        return makeFlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, service: service, onSyncComplete: nil)
    }

    func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                              pollingInterval: TimeInterval,
                              useReport: Bool,
                              service: DarklyServiceProvider,
                              onSyncComplete: FlagSyncCompleteClosure?) -> LDFlagSynchronizing {
        return FlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, service: service, onSyncComplete: onSyncComplete)
    }

    func makeFlagChangeNotifier() -> FlagChangeNotifying {
        return FlagChangeNotifier()
    }

    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> EventReporting {
        return makeEventReporter(config: config, service: service, onSyncComplete: nil)
    }

    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure? = nil) -> EventReporting {
        return EventReporter(config: config, service: service, onSyncComplete: onSyncComplete)
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

    func makeThrottler(maxDelay: TimeInterval, environmentReporter: EnvironmentReporting) -> Throttling {
        return Throttler(maxDelay: maxDelay, environmentReporter: environmentReporter)
    }

    func makeErrorNotifier() -> ErrorNotifying {
        return ErrorNotifier()
    }
}
