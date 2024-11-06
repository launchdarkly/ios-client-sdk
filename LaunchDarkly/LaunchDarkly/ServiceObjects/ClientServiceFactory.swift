import Foundation
import LDSwiftEventSource
import OSLog

protocol ClientServiceCreating {
    func makeKeyedValueCache(cacheKey: String?) -> KeyedValueCaching
    func makeFeatureFlagCache(mobileKey: String, maxCachedContexts: Int) -> FeatureFlagCaching
    func makeCacheConverter() -> CacheConverting
    func makeDarklyServiceProvider(config: LDConfig, context: LDContext, envReporter: EnvironmentReporting) -> DarklyServiceProvider
    func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, lastUpdated: Date?, service: DarklyServiceProvider) -> LDFlagSynchronizing
    func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                              pollingInterval: TimeInterval,
                              useReport: Bool,
                              lastUpdated: Date?,
                              service: DarklyServiceProvider,
                              onSyncComplete: FlagSyncCompleteClosure?) -> LDFlagSynchronizing
    func makeFlagChangeNotifier() -> FlagChangeNotifying
    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> EventReporting
    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure?) -> EventReporting
    func makeStreamingProvider(url: URL, httpHeaders: [String: String], connectMethod: String, connectBody: Data?, handler: EventHandler, delegate: RequestHeaderTransform?, errorHandler: ConnectionErrorHandler?) -> DarklyStreamingProvider
    func makeEnvironmentReporter(config: LDConfig) -> EnvironmentReporting
    func makeThrottler(environmentReporter: EnvironmentReporting) -> Throttling
    func makeConnectionInformation() -> ConnectionInformation
    func makeDiagnosticCache(sdkKey: String) -> DiagnosticCaching
    func makeDiagnosticReporter(config: LDConfig, service: DarklyServiceProvider, environmentReporter: EnvironmentReporting) -> DiagnosticReporting
    func makeFlagStore() -> FlagMaintaining
}

final class ClientServiceFactory: ClientServiceCreating {
    private let logger: OSLog

    init(logger: OSLog) {
        self.logger = logger
    }

    func makeKeyedValueCache(cacheKey: String?) -> KeyedValueCaching {
        UserDefaults(suiteName: cacheKey)!
    }

    func makeFeatureFlagCache(mobileKey: MobileKey, maxCachedContexts: Int) -> FeatureFlagCaching {
        FeatureFlagCache(serviceFactory: self, mobileKey: mobileKey, maxCachedContexts: maxCachedContexts)
    }

    func makeCacheConverter() -> CacheConverting {
        CacheConverter()
    }

    func makeDarklyServiceProvider(config: LDConfig, context: LDContext, envReporter: EnvironmentReporting) -> DarklyServiceProvider {
      DarklyService(config: config, context: context, envReporter: envReporter, serviceFactory: self)
    }

    func makeFlagSynchronizer(streamingMode: LDStreamingMode, pollingInterval: TimeInterval, useReport: Bool, lastUpdated: Date?, service: DarklyServiceProvider) -> LDFlagSynchronizing {
        makeFlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, lastUpdated: lastUpdated, service: service, onSyncComplete: nil)
    }

    func makeFlagSynchronizer(streamingMode: LDStreamingMode,
                              pollingInterval: TimeInterval,
                              useReport: Bool,
                              lastUpdated: Date?,
                              service: DarklyServiceProvider,
                              onSyncComplete: FlagSyncCompleteClosure?) -> LDFlagSynchronizing {
        FlagSynchronizer(streamingMode: streamingMode, pollingInterval: pollingInterval, useReport: useReport, lastUpdated: lastUpdated, service: service, onSyncComplete: onSyncComplete)
    }

    func makeFlagChangeNotifier() -> FlagChangeNotifying {
        FlagChangeNotifier(logger: logger)
    }

    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider) -> EventReporting {
        makeEventReporter(config: config, service: service, onSyncComplete: nil)
    }

    func makeEventReporter(config: LDConfig, service: DarklyServiceProvider, onSyncComplete: EventSyncCompleteClosure? = nil) -> EventReporting {
        if config.sendEvents {
            return EventReporter(service: service, onSyncComplete: onSyncComplete)
        } else {
            return NullEventReporter()
        }
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
        config.logger = self.logger
        if let errorHandler = errorHandler {
            config.connectionErrorHandler = errorHandler
        }
        if let body = connectBody {
            config.body = body
        }
        return EventSource(config: config)
    }

    func makeEnvironmentReporter(config: LDConfig) -> EnvironmentReporting {
        let builder = EnvironmentReporterBuilder()

        if let info = config.applicationInfo {
            builder.applicationInfo(info)
        }

        if config.autoEnvAttributes {
            builder.enableCollectionFromPlatform()
        }

        return builder.build()
    }

    func makeThrottler(environmentReporter: EnvironmentReporting) -> Throttling {
        Throttler(logger: logger)
    }

    func makeConnectionInformation() -> ConnectionInformation {
        ConnectionInformation(currentConnectionMode: .offline, lastConnectionFailureReason: .none)
    }

    func makeDiagnosticCache(sdkKey: String) -> DiagnosticCaching {
        DiagnosticCache(sdkKey: sdkKey)
    }

    func makeDiagnosticReporter(config: LDConfig, service: DarklyServiceProvider, environmentReporter: EnvironmentReporting) -> DiagnosticReporting {
        if config.sendEvents && !config.diagnosticOptOut {
            return DiagnosticReporter(service: service, environmentReporting: environmentReporter)
        } else {
            return NullDiagnosticReporter()
        }
    }

    func makeFlagStore() -> FlagMaintaining {
        FlagStore(logger: logger)
    }
}
