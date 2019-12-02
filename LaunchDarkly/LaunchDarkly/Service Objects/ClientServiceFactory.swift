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
    func makeFeatureFlagCache() -> FeatureFlagCaching
    func makeCacheConverter() -> CacheConverting
    func makeDeprecatedCacheModel(_ model: DeprecatedCacheModel) -> DeprecatedCache
    func makeDarklyServiceProvider(config: LDConfig, user: LDUser) -> DarklyServiceProvider
    func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider) -> LDFlagSynchronizing
    func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                              pollingInterval: TimeInterval,
                              useReport: Bool,
                              service: DarklyServiceProvider,
                              onSyncComplete: FlagSyncCompleteClosure?) -> LDFlagSynchronizing
    func makeFlagChangeNotifier() -> FlagChangeNotifying
    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> EventReporting
    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) -> EventReporting
    func makeStreamingProvider(url: URL, httpHeaders: [String: String]) -> DarklyStreamingProvider
    func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?) -> DarklyStreamingProvider
    func makeEnvironmentReporter() -> EnvironmentReporting
    func makeThrottler(maxDelay: TimeInterval, environmentReporter: EnvironmentReporting) -> Throttling
    func makeErrorNotifier() -> ErrorNotifying
    func makeConnectionInformation() -> ConnectionInformation
}

final class ClientServiceFactory: ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching {
        return UserDefaults.standard
    }

    func makeFeatureFlagCache() -> FeatureFlagCaching {
        return UserEnvironmentFlagCache(withKeyedValueCache: makeKeyedValueCache())
    }

    func makeCacheConverter() -> CacheConverting {
        return CacheConverter(serviceFactory: self)
    }

    func makeDeprecatedCacheModel(_ model: DeprecatedCacheModel) -> DeprecatedCache {
        switch model {
        case .version2: return DeprecatedCacheModelV2(keyedValueCache: makeKeyedValueCache())
        case .version3: return DeprecatedCacheModelV3(keyedValueCache: makeKeyedValueCache())
        case .version4: return DeprecatedCacheModelV4(keyedValueCache: makeKeyedValueCache())
        case .version5: return DeprecatedCacheModelV5(keyedValueCache: makeKeyedValueCache())
        case .version6: return DeprecatedCacheModelV6(keyedValueCache: makeKeyedValueCache())
        }
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
    
    func makeConnectionInformation() -> ConnectionInformation {
        return ConnectionInformation(currentConnectionMode: .offline, lastConnectionFailureReason: .none)
    }
}
