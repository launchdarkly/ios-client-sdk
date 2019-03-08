//
//  ClientServiceMockFactory.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

@testable import LaunchDarkly
import UIKit

struct ClientServiceMockFactory: ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching {
        return KeyedValueCachingMock()
    }

    func makeCacheConverter() -> UserCacheConverting {
        return makeCacheConverter(keyStore: KeyedValueCachingMock())
    }

    func makeCacheConverter(keyStore: KeyedValueCaching) -> UserCacheConverting {
        return UserCacheConverter(keyStore: keyStore, flagCollectionCache: FlagCollectionCachingMock())
    }

    func makeFlagCollectionCache(keyStore: KeyedValueCaching) -> FlagCollectionCaching {
        return FlagCollectionCachingMock()
    }

    var userFlagCache = UserFlagCachingMock()
    func makeUserFlagCache() -> UserFlagCaching {
        return userFlagCache
    }

    func makeUserFlagCache(flagCollectionStore: FlagCollectionCaching) -> UserFlagCaching {
        return userFlagCache
    }

    func makeFlagCache(maxCachedValues: Int) -> UserFlagCache {
        return UserFlagCache(flagCollectionStore: FlagCollectionCachingMock())
    }

    func makeFlagCache() -> UserFlagCache {
        return UserFlagCache(flagCollectionStore: FlagCollectionCachingMock())
    }

    func makeDarklyServiceProvider(config: LDConfig, user: LDUser) -> DarklyServiceProvider {
        return DarklyServiceMock(config: config, user: user)
    }

    var makeFlagSynchronizerCallCount = 0
    var makeFlagSynchronizerReceivedParameters: (streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider)? = nil
    var onFlagSyncComplete: FlagSyncCompleteClosure? = nil
    mutating func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                                       pollingInterval: TimeInterval,
                                       useReport: Bool,
                                       service: DarklyServiceProvider,
                                       onSyncComplete: FlagSyncCompleteClosure?) -> LDFlagSynchronizing {
        makeFlagSynchronizerCallCount += 1
        makeFlagSynchronizerReceivedParameters = (streamingMode, pollingInterval, useReport, service)
        onFlagSyncComplete = onSyncComplete

        let flagSynchronizingMock = LDFlagSynchronizingMock()
        flagSynchronizingMock.streamingMode = streamingMode
        flagSynchronizingMock.pollingInterval = pollingInterval
        return flagSynchronizingMock
    }

    mutating func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider) -> LDFlagSynchronizing {
        return makeFlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, service: service, onSyncComplete: nil)
    }

    func makeFlagChangeNotifier() -> FlagChangeNotifying {
        return FlagChangeNotifyingMock()
    }

    var makeEventReporterCallCount = 0
    var makeEventReporterReceivedParameters: (config: LDConfig, service: DarklyServiceProvider)? = nil
    var onEventSyncComplete: EventSyncCompleteClosure? = nil
    mutating func makeEventReporter(config: LDConfig, service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) -> EventReporting {
        makeEventReporterCallCount += 1
        makeEventReporterReceivedParameters = (config: config, service: service)
        onEventSyncComplete = onSyncComplete

        let reporterMock = EventReportingMock()
        reporterMock.config = config
        return reporterMock
    }

    mutating func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> EventReporting {
        return makeEventReporter(config: config, service: service, onSyncComplete: nil)
    }

    var makeStreamingProviderCallCount = 0
    var makeStreamingProviderReceivedArguments: (url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?)?
    mutating func makeStreamingProvider(url: URL, httpHeaders: [String: String]) -> DarklyStreamingProvider {
        makeStreamingProviderCallCount += 1
        makeStreamingProviderReceivedArguments = (url, httpHeaders, nil, nil)
        return DarklyStreamingProviderMock()
    }

    mutating func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?) -> DarklyStreamingProvider {
        makeStreamingProviderCallCount += 1
        makeStreamingProviderReceivedArguments = (url, httpHeaders, connectMethod, connectBody)
        return DarklyStreamingProviderMock()
    }

    var makeEnvironmentReporterReturnValue: EnvironmentReportingMock = EnvironmentReportingMock()
    func makeEnvironmentReporter() -> EnvironmentReporting {
        // the code generator is not generating the default, not sure why not //sourcery: DefaultMockValue = .UIApplicationDidEnterBackground
        // the code generator is not generating the default, not sure why not //sourcery: DefaultMockValue = .UIApplicationWillEnterForeground
        makeEnvironmentReporterReturnValue.backgroundNotification = UIApplication.didEnterBackgroundNotification
        makeEnvironmentReporterReturnValue.foregroundNotification = UIApplication.willEnterForegroundNotification
        return makeEnvironmentReporterReturnValue
    }

    func makeThrottler(maxDelay: TimeInterval, environmentReporter: EnvironmentReporting) -> Throttling {
        let throttlingMock = ThrottlingMock()
        throttlingMock.maxDelay = maxDelay
        return throttlingMock
    }

    func makeErrorNotifier() -> ErrorNotifying {
        return ErrorNotifyingMock()
    }
}
