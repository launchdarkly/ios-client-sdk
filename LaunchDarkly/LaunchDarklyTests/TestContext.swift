import Foundation
import OSLog
@testable import LaunchDarkly

class TestContext {
    var config: LDConfig!
    var context: LDContext!
    var subject: LDClient!
    let serviceFactoryMock: ClientServiceMockFactory
    // mock getters based on setting up the context & subject
    var serviceMock: DarklyServiceMock! {
        subject.service as? DarklyServiceMock
    }
    var featureFlagCachingMock: FeatureFlagCachingMock! {
        subject.flagCache as? FeatureFlagCachingMock
    }
    var flagStoreMock: FlagMaintainingMock! {
        subject.flagStore as? FlagMaintainingMock
    }
    var flagSynchronizerMock: LDFlagSynchronizingMock! {
        subject.flagSynchronizer as? LDFlagSynchronizingMock
    }
    var eventReporterMock: EventReportingMock! {
        subject.eventReporter as? EventReportingMock
    }
    var changeNotifierMock: FlagChangeNotifyingMock! {
        subject.flagChangeNotifier as? FlagChangeNotifyingMock
    }
    var environmentReporterMock: EnvironmentReportingMock! {
        subject.environmentReporter as? EnvironmentReportingMock
    }
    var makeFlagSynchronizerStreamingMode: LDStreamingMode? {
        serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.streamingMode
    }
    var makeFlagSynchronizerPollingInterval: TimeInterval? {
        serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.pollingInterval
    }
    var makeFlagSynchronizerService: DarklyServiceProvider? {
        serviceFactoryMock.makeFlagSynchronizerReceivedParameters?.service
    }
    var onSyncComplete: FlagSyncCompleteClosure? {
        serviceFactoryMock.onFlagSyncComplete
    }
    var recordedEvent: LaunchDarkly.Event? {
        eventReporterMock.recordReceivedEvent
    }
    var throttlerMock: ThrottlingMock? {
        subject.throttler as? ThrottlingMock
    }

    private(set) var cachedFlags: [String: [String: [LDFlagKey: FeatureFlag]]] = [:]

    init(newConfig: LDConfig? = nil,
         startOnline: Bool = false,
         streamingMode: LDStreamingMode = .streaming,
         enableBackgroundUpdates: Bool = true) {
        config = newConfig ?? LDConfig.stub(mobileKey: LDConfig.Constants.mockMobileKey, autoEnvAttributes: .disabled, isDebugBuild: false)
        config.startOnline = startOnline
        config.streamingMode = streamingMode
        config.enableBackgroundUpdates = enableBackgroundUpdates
        config.eventFlushInterval = 300.0   // 5 min...don't want this to trigger

        context = LDContext.stub()

        serviceFactoryMock = ClientServiceMockFactory(config: config)
        serviceFactoryMock.makeFlagChangeNotifierReturnValue = FlagChangeNotifier(logger: OSLog(subsystem: "com.launchdarkly", category: "tests"))

        serviceFactoryMock.makeFeatureFlagCacheCallback = {
            let mobileKey = self.serviceFactoryMock.makeFeatureFlagCacheReceivedParameters!.mobileKey
            let mockCache = FeatureFlagCachingMock()
            mockCache.getCachedDataCallback = {
                let arguments = mockCache.getCachedDataReceivedArguments
                let cacheKey = arguments?.cacheKey
                let flags = cacheKey.map { self.cachedFlags[mobileKey]?[$0] ?? [:] } ?? [:]
                mockCache.getCachedDataReturnValue = (items: StoredItems(items: flags), etag: nil, lastUpdated: nil)
            }
            self.serviceFactoryMock.makeFeatureFlagCacheReturnValue = mockCache
        }
    }

    func withContext(_ context: LDContext?) -> TestContext {
        self.context = context
        return self
    }

    func withCached(flags: [LDFlagKey: FeatureFlag]?) -> TestContext {
        withCached(contextKey: context.fullyQualifiedHashedKey(), flags: flags)
    }

    func withCached(contextKey: String, flags: [LDFlagKey: FeatureFlag]?) -> TestContext {
        var forEnv = cachedFlags[config.mobileKey] ?? [:]
        forEnv[contextKey] = flags
        cachedFlags[config.mobileKey] = forEnv
        return self
    }

    func start(runMode: LDClientRunMode = .foreground, completion: (() -> Void)? = nil) {
        LDClient.start(serviceFactory: serviceFactoryMock, config: config, context: context) {
            self.subject = LDClient.get()
            if runMode == .background {
                self.subject.setRunMode(.background)
            }
            completion?()
        }
        subject = LDClient.get()
    }

    func start(runMode: LDClientRunMode = .foreground, timeOut: TimeInterval, timeOutCompletion: ((_ timedOut: Bool) -> Void)? = nil) {
        LDClient.start(serviceFactory: serviceFactoryMock, config: config, context: context, startWaitSeconds: timeOut) { timedOut in
            self.subject = LDClient.get()
            if runMode == .background {
                self.subject.setRunMode(.background)
            }
            timeOutCompletion?(timedOut)
        }
        subject = LDClient.get()
    }
}

struct DefaultFlagValues {
    static let bool = false
    static let int = 5
    static let double = 2.71828
    static let string = "default string value"
    static let array: LDValue = [-1, -2]
    static let dictionary: LDValue = ["sub-flag-x": true, "sub-flag-y": 1, "sub-flag-z": 42.42]
}
