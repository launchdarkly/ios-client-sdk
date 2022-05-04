import Foundation
import LDSwiftEventSource

protocol ClientServiceCreating {
    func makeKeyedValueCache(cacheKey: String?) -> KeyedValueCaching
    func makeFeatureFlagCache(mobileKey: String, maxCachedUsers: Int) -> FeatureFlagCaching
    func makeCacheConverter() -> CacheConverting
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
    func makeConnectionInformation() -> ConnectionInformation
    func makeDiagnosticCache(sdkKey: String) -> DiagnosticCaching
    func makeDiagnosticReporter(service: DarklyServiceProvider) -> DiagnosticReporting
    func makeFlagStore() -> FlagMaintaining
}

final class ClientServiceFactory: ClientServiceCreating {
    func makeKeyedValueCache(cacheKey: String?) -> KeyedValueCaching {
        UserDefaults(suiteName: cacheKey)!
    }

    func makeFeatureFlagCache(mobileKey: MobileKey, maxCachedUsers: Int) -> FeatureFlagCaching {
        FeatureFlagCache(serviceFactory: self, mobileKey: mobileKey, maxCachedUsers: maxCachedUsers)
    }

    func makeCacheConverter() -> CacheConverting {
        CacheConverter()
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
