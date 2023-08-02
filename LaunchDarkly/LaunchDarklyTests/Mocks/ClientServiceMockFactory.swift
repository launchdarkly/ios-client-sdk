import Foundation
import LDSwiftEventSource
@testable import LaunchDarkly

final class ClientServiceMockFactory: ClientServiceCreating {
    var makeKeyedValueCacheReturnValue = KeyedValueCachingMock()
    var makeKeyedValueCacheCallCount = 0
    var makeKeyedValueCacheReceivedCacheKey: String? = nil
    func makeKeyedValueCache(cacheKey: String?) -> KeyedValueCaching {
        makeKeyedValueCacheCallCount += 1
        makeKeyedValueCacheReceivedCacheKey = cacheKey
        return makeKeyedValueCacheReturnValue
    }

    var makeFeatureFlagCacheReturnValue = FeatureFlagCachingMock()
    var makeFeatureFlagCacheCallback: (() -> Void)?
    var makeFeatureFlagCacheCallCount = 0
    var makeFeatureFlagCacheReceivedParameters: (mobileKey: MobileKey, maxCachedContexts: Int)? = nil
    func makeFeatureFlagCache(mobileKey: MobileKey, maxCachedContexts: Int = 5) -> FeatureFlagCaching {
        makeFeatureFlagCacheCallCount += 1
        makeFeatureFlagCacheReceivedParameters = (mobileKey: mobileKey, maxCachedContexts: maxCachedContexts)
        makeFeatureFlagCacheCallback?()
        return makeFeatureFlagCacheReturnValue
    }

    var makeCacheConverterReturnValue = CacheConvertingMock()
    func makeCacheConverter() -> CacheConverting {
        return makeCacheConverterReturnValue
    }

    func makeDarklyServiceProvider(config: LDConfig, context: LDContext, envReporter: EnvironmentReporting) -> DarklyServiceProvider {
        DarklyServiceMock(config: config, context: context)
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

    var makeFlagChangeNotifierReturnValue: FlagChangeNotifying = FlagChangeNotifyingMock()
    func makeFlagChangeNotifier() -> FlagChangeNotifying {
        return makeFlagChangeNotifierReturnValue
    }

    var makeEventReporterCallCount = 0
    var makeEventReporterReceivedService: DarklyServiceProvider? = nil
    var onEventSyncComplete: EventSyncCompleteClosure? = nil
    func makeEventReporter(service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) -> EventReporting {
        makeEventReporterCallCount += 1
        makeEventReporterReceivedService = service
        onEventSyncComplete = onSyncComplete

        return EventReportingMock()
    }

    func makeEventReporter(service: DarklyServiceProvider) -> EventReporting {
        return makeEventReporter(service: service, onSyncComplete: nil)
    }

    var makeStreamingProviderCallCount = 0
    var makeStreamingProviderReceivedArguments: (url: URL,
                                                 httpHeaders: [String: String],
                                                 connectMethod: String?,
                                                 connectBody: Data?,
                                                 handler: EventHandler,
                                                 delegate: RequestHeaderTransform?,
                                                 errorHandler: ConnectionErrorHandler?)?
    func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String, connectBody: Data?, handler: EventHandler, delegate: RequestHeaderTransform?, errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider {
        makeStreamingProviderCallCount += 1
        makeStreamingProviderReceivedArguments = (url, httpHeaders, connectMethod, connectBody, handler, delegate, errorHandler)
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
    var makeDiagnosticReporterReceivedService: DarklyServiceProvider? = nil
    func makeDiagnosticReporter(service: DarklyServiceProvider, environmentReporter: EnvironmentReporting) -> DiagnosticReporting {
        makeDiagnosticReporterCallCount += 1
        makeDiagnosticReporterReceivedService = service
        return DiagnosticReportingMock()
    }

    var makeEnvironmentReporterReturnValue: EnvironmentReportingMock = EnvironmentReportingMock()
    func makeEnvironmentReporter(config: LDConfig) -> EnvironmentReporting {
        return makeEnvironmentReporterReturnValue
    }

    func makeThrottler(environmentReporter: EnvironmentReporting) -> Throttling {
        let throttlingMock = ThrottlingMock()
        throttlingMock.runThrottledCallback = {
            throttlingMock.runThrottledReceivedRunClosure?()
        }
        return throttlingMock
    }

    func makeConnectionInformation() -> ConnectionInformation {
        ConnectionInformation(currentConnectionMode: .offline, lastConnectionFailureReason: .none)
    }

    var makeFlagStoreReturnValue = FlagMaintainingMock()
    func makeFlagStore() -> FlagMaintaining {
        return makeFlagStoreReturnValue
    }
}
