//
//  ClientServiceMockFactory.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

@testable import Darkly

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

    func makeDarklyServiceProvider(mobileKey: String, config: LDConfig, user: LDUser) -> DarklyServiceProvider {
        return DarklyServiceMock(config: config, user: user)
    }

    var makeFlagSynchronizerCallCount = 0
    var makeFlagSynchronizerReceivedParameters: (streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider)? = nil
    var onSyncComplete: SyncCompleteClosure? = nil
    mutating func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                                       pollingInterval: TimeInterval,
                                       useReport: Bool,
                                       service: DarklyServiceProvider,
                                       onSyncComplete: SyncCompleteClosure?) -> LDFlagSynchronizing {
        makeFlagSynchronizerCallCount += 1
        makeFlagSynchronizerReceivedParameters = (streamingMode, pollingInterval, useReport, service)
        self.onSyncComplete = onSyncComplete

        let flagSynchronizingMock = LDFlagSynchronizingMock()
        flagSynchronizingMock.streamingMode = streamingMode
        flagSynchronizingMock.pollingInterval = pollingInterval
        return flagSynchronizingMock
    }

    func makeFlagChangeNotifier() -> FlagChangeNotifying {
        return FlagChangeNotifyingMock()
    }

    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> LDEventReporting {
        let reporterMock = LDEventReportingMock()
        reporterMock.config = config
        return reporterMock
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
        return makeEnvironmentReporterReturnValue
    }

    func makeThrottler(maxDelay: TimeInterval) -> Throttling {
        let throttlingMock = ThrottlingMock()
        throttlingMock.maxDelay = maxDelay
        return throttlingMock
    }
}
