//
//  ClientServiceMockFactory.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import LDSwiftEventSource
@testable import LaunchDarkly

final class ClientServiceMockFactory: ClientServiceCreating {
    func makeKeyedValueCache() -> KeyedValueCaching {
        KeyedValueCachingMock()
    }

    var makeFeatureFlagCacheReturnValue = FeatureFlagCachingMock()
    var makeFeatureFlagCacheCallCount = 0
    func makeFeatureFlagCache(maxCachedUsers: Int = 5) -> FeatureFlagCaching {
        makeFeatureFlagCacheCallCount += 1
        return makeFeatureFlagCacheReturnValue
    }

    func makeCacheConverter(maxCachedUsers: Int = 5) -> CacheConverting {
        CacheConvertingMock()
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
        DarklyServiceMock(config: config, user: user)
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
        makeFlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, service: service, onSyncComplete: nil)
    }

    func makeFlagChangeNotifier() -> FlagChangeNotifying {
        FlagChangeNotifyingMock()
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
    var makeStreamingProviderReceivedArguments: (url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?, handler: EventHandler, errorHandler: ConnectionErrorHandler?)?
    func makeStreamingProvider(url: URL, httpHeaders: [String: String], handler: EventHandler, errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider {
        makeStreamingProviderCallCount += 1
        makeStreamingProviderReceivedArguments = (url, httpHeaders, nil, nil, handler, errorHandler)
        return DarklyStreamingProviderMock()
    }

    func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String?, connectBody: Data?, handler: EventHandler, errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider {
        makeStreamingProviderCallCount += 1
        makeStreamingProviderReceivedArguments = (url, httpHeaders, connectMethod, connectBody, handler, errorHandler)
        return DarklyStreamingProviderMock()
    }

    var makeDiagnosticCacheCallCount = 0
    var makeDiagnosticCacheReceivedSdkKey: String? = nil
    func makeDiagnosticCache(sdkKey: String) -> DiagnosticCaching {
        makeDiagnosticCacheCallCount += 1
        makeDiagnosticCacheReceivedSdkKey = sdkKey
        return DiagnosticCachingMock()
    }

    var makeDiagnosticReporterCallCount = 0
    var makeDiagnosticReporterReceivedParameters: (service: DarklyServiceProvider, runMode: LDClientRunMode)? = nil
    func makeDiagnosticReporter(service: DarklyServiceProvider, runMode: LDClientRunMode) -> DiagnosticReporting {
        makeDiagnosticReporterCallCount += 1
        makeDiagnosticReporterReceivedParameters = (service: service, runMode: runMode)
        return DiagnosticReportingMock()
    }

    var makeEnvironmentReporterReturnValue: EnvironmentReportingMock = EnvironmentReportingMock()
    func makeEnvironmentReporter() -> EnvironmentReporting {
        return makeEnvironmentReporterReturnValue
    }

    func makeThrottler(maxDelay: TimeInterval, environmentReporter: EnvironmentReporting) -> Throttling {
        let throttlingMock = ThrottlingMock()
        throttlingMock.maxDelay = maxDelay
        return throttlingMock
    }

    func makeErrorNotifier() -> ErrorNotifying {
        ErrorNotifyingMock()
    }
    
    func makeConnectionInformation() -> ConnectionInformation {
        ConnectionInformation(currentConnectionMode: .offline, lastConnectionFailureReason: .none)
    }
}
