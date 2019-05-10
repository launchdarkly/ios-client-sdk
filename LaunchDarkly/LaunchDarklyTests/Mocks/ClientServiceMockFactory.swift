//
//  ClientServiceMockFactory.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 11/13/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

@testable import LaunchDarkly
import UIKit

final class ClientServiceMockFactory: ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching {
        return KeyedValueCachingMock()
    }

    var makeFeatureFlagCacheReturnValue = FeatureFlagCachingMock()
    var makeFeatureFlagCacheCallCount = 0
    func makeFeatureFlagCache() -> FeatureFlagCaching {
        makeFeatureFlagCacheCallCount += 1
        return makeFeatureFlagCacheReturnValue
    }

    func makeCacheConverter() -> CacheConverting {
        return CacheConvertingMock()
    }

    var makeDeprecatedCacheModelReturnValue: DeprecatedCacheMock?
    var makeDeprecatedCacheModelReturnedValues = [DeprecatedCacheModel: DeprecatedCacheMock]()
    var makeDeprecatedCacheModelCallCount = 0
    var makeDeprecatedCacheModelReceivedModels = [DeprecatedCacheModel]()
    func makeDeprecatedCacheModel(_ model: DeprecatedCacheModel) -> DeprecatedCache {
        makeDeprecatedCacheModelCallCount += 1
        makeDeprecatedCacheModelReceivedModels.append(model)
        var returnedCacheMock = makeDeprecatedCacheModelReturnValue
        if returnedCacheMock == nil {
            returnedCacheMock = DeprecatedCacheMock()
            returnedCacheMock?.model = model
        }
        makeDeprecatedCacheModelReturnedValues[model] = returnedCacheMock!
        return returnedCacheMock!
    }

    func makeDarklyServiceProvider(config: LDConfig, user: LDUser) -> DarklyServiceProvider {
        return DarklyServiceMock(config: config, user: user)
    }

    var makeFlagSynchronizerCallCount = 0
    var makeFlagSynchronizerReceivedParameters: (streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider)? = nil
    var onFlagSyncComplete: FlagSyncCompleteClosure? = nil
    func makeFlagSynchronizer(streamingMode: LDStreamingMode,
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

    func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, service: DarklyServiceProvider) -> LDFlagSynchronizing {
        return makeFlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, service: service, onSyncComplete: nil)
    }

    func makeFlagChangeNotifier() -> FlagChangeNotifying {
        return FlagChangeNotifyingMock()
    }

    var makeEventReporterCallCount = 0
    var makeEventReporterReceivedParameters: (config: LDConfig, service: DarklyServiceProvider)? = nil
    var onEventSyncComplete: EventSyncCompleteClosure? = nil
    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) -> EventReporting {
        makeEventReporterCallCount += 1
        makeEventReporterReceivedParameters = (config: config, service: service)
        onEventSyncComplete = onSyncComplete

        let reporterMock = EventReportingMock()
        reporterMock.config = config
        return reporterMock
    }

    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> EventReporting {
        return makeEventReporter(config: config, service: service, onSyncComplete: nil)
    }

    var makeStreamingProviderCallCount = 0
    var makeStreamingProviderReceivedArguments: (url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?)?
    func makeStreamingProvider(url: URL, httpHeaders: [String: String]) -> DarklyStreamingProvider {
        makeStreamingProviderCallCount += 1
        makeStreamingProviderReceivedArguments = (url, httpHeaders, nil, nil)
        return DarklyStreamingProviderMock()
    }

    func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?) -> DarklyStreamingProvider {
        makeStreamingProviderCallCount += 1
        makeStreamingProviderReceivedArguments = (url, httpHeaders, connectMethod, connectBody)
        return DarklyStreamingProviderMock()
    }

    var makeEnvironmentReporterReturnValue: EnvironmentReportingMock = EnvironmentReportingMock()
    func makeEnvironmentReporter() -> EnvironmentReporting {
        // the code generator is not generating the default, not sure why not //sourcery: defaultMockValue = .UIApplicationDidEnterBackground
        // the code generator is not generating the default, not sure why not //sourcery: defaultMockValue = .UIApplicationWillEnterForeground
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
