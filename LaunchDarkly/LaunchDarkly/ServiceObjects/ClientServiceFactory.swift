//
//  ClientServiceFactory.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import LDSwiftEventSource

protocol ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching
    func makeFeatureFlagCache(maxCachedUsers: Int) -> FeatureFlagCaching
    func makeCacheConverter(maxCachedUsers: Int) -> CacheConverting
    func makeDeprecatedCacheModel(_ model: DeprecatedCacheModel) -> DeprecatedCache
    func makeDarklyServiceProvider(config: LDConfig, user: LDUser) -> DarklyServiceProvider
    func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider) -> LDFlagSynchronizing
    func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                              pollingInterval: TimeInterval,
                              useReport: Bool,
                              service: DarklyServiceProvider,
                              onSyncComplete: FlagSyncCompleteClosure?) -> LDFlagSynchronizing
    func makeFlagChangeNotifier() -> FlagChangeNotifying
    func makeEventReporter(service: DarklyServiceProvider) -> EventReporting
    func makeEventReporter(service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) -> EventReporting
    func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String, connectBody: Data?, handler: EventHandler, delegate: RequestHeaderTransform?, errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider
    func makeEnvironmentReporter() -> EnvironmentReporting
    func makeThrottler(environmentReporter: EnvironmentReporting) -> Throttling
    func makeErrorNotifier() -> ErrorNotifying
    func makeConnectionInformation() -> ConnectionInformation
    func makeDiagnosticCache(sdkKey: String) -> DiagnosticCaching
    func makeDiagnosticReporter(service: DarklyServiceProvider) -> DiagnosticReporting
    func makeFlagStore() -> FlagMaintaining
}

final class ClientServiceFactory: ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching {
        UserDefaults.standard
    }

    func makeFeatureFlagCache(maxCachedUsers: Int) -> FeatureFlagCaching {
        UserEnvironmentFlagCache(withKeyedValueCache: makeKeyedValueCache(), maxCachedUsers: maxCachedUsers)
    }

    func makeCacheConverter(maxCachedUsers: Int) -> CacheConverting {
        CacheConverter(serviceFactory: self, maxCachedUsers: maxCachedUsers)
    }

    func makeDeprecatedCacheModel(_ model: DeprecatedCacheModel) -> DeprecatedCache {
        switch model {
        case .version2: return DeprecatedCacheModelV2(keyedValueCache: makeKeyedValueCache())
        case .version3: return DeprecatedCacheModelV3(keyedValueCache: makeKeyedValueCache())
        case .version4: return DeprecatedCacheModelV4(keyedValueCache: makeKeyedValueCache())
        case .version5: return DeprecatedCacheModelV5(keyedValueCache: makeKeyedValueCache())
        }
    }

    func makeDarklyServiceProvider(config: LDConfig, user: LDUser) -> DarklyServiceProvider {
        DarklyService(config: config, user: user, serviceFactory: self)
    }

    func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider) -> LDFlagSynchronizing {
        makeFlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, service: service, onSyncComplete: nil)
    }

    func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                              pollingInterval: TimeInterval,
                              useReport: Bool,
                              service: DarklyServiceProvider,
                              onSyncComplete: FlagSyncCompleteClosure?) -> LDFlagSynchronizing {
        FlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, service: service, onSyncComplete: onSyncComplete)
    }

    func makeFlagChangeNotifier() -> FlagChangeNotifying {
        FlagChangeNotifier()
    }

    func makeEventReporter(service: DarklyServiceProvider) -> EventReporting {
        makeEventReporter(service: service, onSyncComplete: nil)
    }

    func makeEventReporter(service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure? = nil) -> EventReporting {
        EventReporter(service: service, onSyncComplete: onSyncComplete)
    }

    func makeStreamingProvider(url: URL, 
                               httpHeaders: [String: String], 
                               connectMethod: String,
                               connectBody: Data?, 
                               handler: EventHandler, 
                               delegate: RequestHeaderTransform?,
                               errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider {
        var config: EventSource.Config = EventSource.Config(handler: handler, url: url)
        config.headerTransform = { delegate?(url, $0) ?? $0 }
        config.headers = httpHeaders
        config.method = connectMethod
        if let errorHandler = errorHandler {
            config.connectionErrorHandler = errorHandler
        }
        if let body = connectBody {
            config.body = body
        }
        return EventSource(config: config)
    }

    func makeEnvironmentReporter() -> EnvironmentReporting {
        EnvironmentReporter()
    }

    func makeThrottler(environmentReporter: EnvironmentReporting) -> Throttling {
        Throttler(environmentReporter: environmentReporter)
    }

    func makeErrorNotifier() -> ErrorNotifying {
        ErrorNotifier()
    }
    
    func makeConnectionInformation() -> ConnectionInformation {
        ConnectionInformation(currentConnectionMode: .offline, lastConnectionFailureReason: .none)
    }

    func makeDiagnosticCache(sdkKey: String) -> DiagnosticCaching {
        DiagnosticCache(sdkKey: sdkKey)
    }

    func makeDiagnosticReporter(service: DarklyServiceProvider) -> DiagnosticReporting {
        DiagnosticReporter(service: service)
    }

    func makeFlagStore() -> FlagMaintaining {
        FlagStore()
    }
}
