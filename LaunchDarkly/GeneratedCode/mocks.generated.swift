// Generated using Sourcery 1.2.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
import LDSwiftEventSource
@testable import LaunchDarkly

// swiftlint:disable large_tuple

// MARK: - CacheConvertingMock
final class CacheConvertingMock: CacheConverting {

    var convertCacheDataCallCount = 0
    var convertCacheDataCallback: (() -> Void)?
    var convertCacheDataReceivedArguments: (user: LDUser, config: LDConfig)?
    func convertCacheData(for user: LDUser, and config: LDConfig) {
        convertCacheDataCallCount += 1
        convertCacheDataReceivedArguments = (user: user, config: config)
        convertCacheDataCallback?()
    }
}

// MARK: - DarklyStreamingProviderMock
final class DarklyStreamingProviderMock: DarklyStreamingProvider {

    var startCallCount = 0
    var startCallback: (() -> Void)?
    func start() {
        startCallCount += 1
        startCallback?()
    }

    var stopCallCount = 0
    var stopCallback: (() -> Void)?
    func stop() {
        stopCallCount += 1
        stopCallback?()
    }
}

// MARK: - DiagnosticCachingMock
final class DiagnosticCachingMock: DiagnosticCaching {

    var lastStatsSetCount = 0
    var setLastStatsCallback: (() -> Void)?
    var lastStats: DiagnosticStats? = nil {
        didSet {
            lastStatsSetCount += 1
            setLastStatsCallback?()
        }
    }

    var getDiagnosticIdCallCount = 0
    var getDiagnosticIdCallback: (() -> Void)?
    var getDiagnosticIdReturnValue: DiagnosticId!
    func getDiagnosticId() -> DiagnosticId {
        getDiagnosticIdCallCount += 1
        getDiagnosticIdCallback?()
        return getDiagnosticIdReturnValue
    }

    var getCurrentStatsAndResetCallCount = 0
    var getCurrentStatsAndResetCallback: (() -> Void)?
    var getCurrentStatsAndResetReturnValue: DiagnosticStats!
    func getCurrentStatsAndReset() -> DiagnosticStats {
        getCurrentStatsAndResetCallCount += 1
        getCurrentStatsAndResetCallback?()
        return getCurrentStatsAndResetReturnValue
    }

    var incrementDroppedEventCountCallCount = 0
    var incrementDroppedEventCountCallback: (() -> Void)?
    func incrementDroppedEventCount() {
        incrementDroppedEventCountCallCount += 1
        incrementDroppedEventCountCallback?()
    }

    var recordEventsInLastBatchCallCount = 0
    var recordEventsInLastBatchCallback: (() -> Void)?
    var recordEventsInLastBatchReceivedEventsInLastBatch: Int?
    func recordEventsInLastBatch(eventsInLastBatch: Int) {
        recordEventsInLastBatchCallCount += 1
        recordEventsInLastBatchReceivedEventsInLastBatch = eventsInLastBatch
        recordEventsInLastBatchCallback?()
    }

    var addStreamInitCallCount = 0
    var addStreamInitCallback: (() -> Void)?
    var addStreamInitReceivedStreamInit: DiagnosticStreamInit?
    func addStreamInit(streamInit: DiagnosticStreamInit) {
        addStreamInitCallCount += 1
        addStreamInitReceivedStreamInit = streamInit
        addStreamInitCallback?()
    }
}

// MARK: - DiagnosticReportingMock
final class DiagnosticReportingMock: DiagnosticReporting {

    var setModeCallCount = 0
    var setModeCallback: (() -> Void)?
    var setModeReceivedArguments: (runMode: LDClientRunMode, online: Bool)?
    func setMode(_ runMode: LDClientRunMode, online: Bool) {
        setModeCallCount += 1
        setModeReceivedArguments = (runMode: runMode, online: online)
        setModeCallback?()
    }
}

// MARK: - EnvironmentReportingMock
final class EnvironmentReportingMock: EnvironmentReporting {

    var isDebugBuildSetCount = 0
    var setIsDebugBuildCallback: (() -> Void)?
    var isDebugBuild: Bool = true {
        didSet {
            isDebugBuildSetCount += 1
            setIsDebugBuildCallback?()
        }
    }

    var deviceTypeSetCount = 0
    var setDeviceTypeCallback: (() -> Void)?
    var deviceType: String = Constants.deviceType {
        didSet {
            deviceTypeSetCount += 1
            setDeviceTypeCallback?()
        }
    }

    var deviceModelSetCount = 0
    var setDeviceModelCallback: (() -> Void)?
    var deviceModel: String = Constants.deviceModel {
        didSet {
            deviceModelSetCount += 1
            setDeviceModelCallback?()
        }
    }

    var systemVersionSetCount = 0
    var setSystemVersionCallback: (() -> Void)?
    var systemVersion: String = Constants.systemVersion {
        didSet {
            systemVersionSetCount += 1
            setSystemVersionCallback?()
        }
    }

    var systemNameSetCount = 0
    var setSystemNameCallback: (() -> Void)?
    var systemName: String = Constants.systemName {
        didSet {
            systemNameSetCount += 1
            setSystemNameCallback?()
        }
    }

    var operatingSystemSetCount = 0
    var setOperatingSystemCallback: (() -> Void)?
    var operatingSystem: OperatingSystem = .iOS {
        didSet {
            operatingSystemSetCount += 1
            setOperatingSystemCallback?()
        }
    }

    var backgroundNotificationSetCount = 0
    var setBackgroundNotificationCallback: (() -> Void)?
    var backgroundNotification: Notification.Name? = EnvironmentReporter().backgroundNotification {
        didSet {
            backgroundNotificationSetCount += 1
            setBackgroundNotificationCallback?()
        }
    }

    var foregroundNotificationSetCount = 0
    var setForegroundNotificationCallback: (() -> Void)?
    var foregroundNotification: Notification.Name? = EnvironmentReporter().foregroundNotification {
        didSet {
            foregroundNotificationSetCount += 1
            setForegroundNotificationCallback?()
        }
    }

    var vendorUUIDSetCount = 0
    var setVendorUUIDCallback: (() -> Void)?
    var vendorUUID: String? = Constants.vendorUUID {
        didSet {
            vendorUUIDSetCount += 1
            setVendorUUIDCallback?()
        }
    }

    var sdkVersionSetCount = 0
    var setSdkVersionCallback: (() -> Void)?
    var sdkVersion: String = Constants.sdkVersion {
        didSet {
            sdkVersionSetCount += 1
            setSdkVersionCallback?()
        }
    }

    var shouldThrottleOnlineCallsSetCount = 0
    var setShouldThrottleOnlineCallsCallback: (() -> Void)?
    var shouldThrottleOnlineCalls: Bool = true {
        didSet {
            shouldThrottleOnlineCallsSetCount += 1
            setShouldThrottleOnlineCallsCallback?()
        }
    }
}

// MARK: - EventReportingMock
final class EventReportingMock: EventReporting {

    var isOnlineSetCount = 0
    var setIsOnlineCallback: (() -> Void)?
    var isOnline: Bool = false {
        didSet {
            isOnlineSetCount += 1
            setIsOnlineCallback?()
        }
    }

    var lastEventResponseDateSetCount = 0
    var setLastEventResponseDateCallback: (() -> Void)?
    var lastEventResponseDate: Date? = nil {
        didSet {
            lastEventResponseDateSetCount += 1
            setLastEventResponseDateCallback?()
        }
    }

    var recordCallCount = 0
    var recordCallback: (() -> Void)?
    var recordReceivedEvent: Event?
    func record(_ event: Event) {
        recordCallCount += 1
        recordReceivedEvent = event
        recordCallback?()
    }

    var recordFlagEvaluationEventsCallCount = 0
    var recordFlagEvaluationEventsCallback: (() -> Void)?
    var recordFlagEvaluationEventsReceivedArguments: (flagKey: LDFlagKey, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool)?
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool) {
        recordFlagEvaluationEventsCallCount += 1
        recordFlagEvaluationEventsReceivedArguments = (flagKey: flagKey, value: value, defaultValue: defaultValue, featureFlag: featureFlag, user: user, includeReason: includeReason)
        recordFlagEvaluationEventsCallback?()
    }

    var flushCallCount = 0
    var flushCallback: (() -> Void)?
    var flushReceivedCompletion: CompletionClosure?
    func flush(completion: CompletionClosure?) {
        flushCallCount += 1
        flushReceivedCompletion = completion
        flushCallback?()
    }
}

// MARK: - FeatureFlagCachingMock
final class FeatureFlagCachingMock: FeatureFlagCaching {

    var maxCachedUsersSetCount = 0
    var setMaxCachedUsersCallback: (() -> Void)?
    var maxCachedUsers: Int = 5 {
        didSet {
            maxCachedUsersSetCount += 1
            setMaxCachedUsersCallback?()
        }
    }

    var retrieveFeatureFlagsCallCount = 0
    var retrieveFeatureFlagsCallback: (() -> Void)?
    var retrieveFeatureFlagsReceivedArguments: (userKey: String, mobileKey: String)?
    var retrieveFeatureFlagsReturnValue: [LDFlagKey: FeatureFlag]?
    func retrieveFeatureFlags(forUserWithKey userKey: String, andMobileKey mobileKey: String) -> [LDFlagKey: FeatureFlag]? {
        retrieveFeatureFlagsCallCount += 1
        retrieveFeatureFlagsReceivedArguments = (userKey: userKey, mobileKey: mobileKey)
        retrieveFeatureFlagsCallback?()
        return retrieveFeatureFlagsReturnValue
    }

    var storeFeatureFlagsCallCount = 0
    var storeFeatureFlagsCallback: (() -> Void)?
    var storeFeatureFlagsReceivedArguments: (featureFlags: [LDFlagKey: FeatureFlag], userKey: String, mobileKey: String, lastUpdated: Date, storeMode: FlagCachingStoreMode)?
    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag], userKey: String, mobileKey: String, lastUpdated: Date, storeMode: FlagCachingStoreMode) {
        storeFeatureFlagsCallCount += 1
        storeFeatureFlagsReceivedArguments = (featureFlags: featureFlags, userKey: userKey, mobileKey: mobileKey, lastUpdated: lastUpdated, storeMode: storeMode)
        storeFeatureFlagsCallback?()
    }
}

// MARK: - FlagChangeNotifyingMock
final class FlagChangeNotifyingMock: FlagChangeNotifying {

    var addFlagChangeObserverCallCount = 0
    var addFlagChangeObserverCallback: (() -> Void)?
    var addFlagChangeObserverReceivedObserver: FlagChangeObserver?
    func addFlagChangeObserver(_ observer: FlagChangeObserver) {
        addFlagChangeObserverCallCount += 1
        addFlagChangeObserverReceivedObserver = observer
        addFlagChangeObserverCallback?()
    }

    var addFlagsUnchangedObserverCallCount = 0
    var addFlagsUnchangedObserverCallback: (() -> Void)?
    var addFlagsUnchangedObserverReceivedObserver: FlagsUnchangedObserver?
    func addFlagsUnchangedObserver(_ observer: FlagsUnchangedObserver) {
        addFlagsUnchangedObserverCallCount += 1
        addFlagsUnchangedObserverReceivedObserver = observer
        addFlagsUnchangedObserverCallback?()
    }

    var addConnectionModeChangedObserverCallCount = 0
    var addConnectionModeChangedObserverCallback: (() -> Void)?
    var addConnectionModeChangedObserverReceivedObserver: ConnectionModeChangedObserver?
    func addConnectionModeChangedObserver(_ observer: ConnectionModeChangedObserver) {
        addConnectionModeChangedObserverCallCount += 1
        addConnectionModeChangedObserverReceivedObserver = observer
        addConnectionModeChangedObserverCallback?()
    }

    var removeObserverCallCount = 0
    var removeObserverCallback: (() -> Void)?
    var removeObserverReceivedOwner: LDObserverOwner?
    func removeObserver(owner: LDObserverOwner) {
        removeObserverCallCount += 1
        removeObserverReceivedOwner = owner
        removeObserverCallback?()
    }

    var notifyConnectionModeChangedObserversCallCount = 0
    var notifyConnectionModeChangedObserversCallback: (() -> Void)?
    var notifyConnectionModeChangedObserversReceivedConnectionMode: ConnectionInformation.ConnectionMode?
    func notifyConnectionModeChangedObservers(connectionMode: ConnectionInformation.ConnectionMode) {
        notifyConnectionModeChangedObserversCallCount += 1
        notifyConnectionModeChangedObserversReceivedConnectionMode = connectionMode
        notifyConnectionModeChangedObserversCallback?()
    }

    var notifyUnchangedCallCount = 0
    var notifyUnchangedCallback: (() -> Void)?
    func notifyUnchanged() {
        notifyUnchangedCallCount += 1
        notifyUnchangedCallback?()
    }

    var notifyObserversCallCount = 0
    var notifyObserversCallback: (() -> Void)?
    var notifyObserversReceivedArguments: (oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag])?
    func notifyObservers(oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag]) {
        notifyObserversCallCount += 1
        notifyObserversReceivedArguments = (oldFlags: oldFlags, newFlags: newFlags)
        notifyObserversCallback?()
    }
}

// MARK: - KeyedValueCachingMock
final class KeyedValueCachingMock: KeyedValueCaching {

    var setCallCount = 0
    var setCallback: (() -> Void)?
    var setReceivedArguments: (value: Any?, forKey: String)?
    func set(_ value: Any?, forKey: String) {
        setCallCount += 1
        setReceivedArguments = (value: value, forKey: forKey)
        setCallback?()
    }

    var dictionaryCallCount = 0
    var dictionaryCallback: (() -> Void)?
    var dictionaryReceivedForKey: String?
    var dictionaryReturnValue: [String: Any]? = nil
    func dictionary(forKey: String) -> [String: Any]? {
        dictionaryCallCount += 1
        dictionaryReceivedForKey = forKey
        dictionaryCallback?()
        return dictionaryReturnValue
    }

    var removeObjectCallCount = 0
    var removeObjectCallback: (() -> Void)?
    var removeObjectReceivedForKey: String?
    func removeObject(forKey: String) {
        removeObjectCallCount += 1
        removeObjectReceivedForKey = forKey
        removeObjectCallback?()
    }
}

// MARK: - LDFlagSynchronizingMock
final class LDFlagSynchronizingMock: LDFlagSynchronizing {

    var isOnlineSetCount = 0
    var setIsOnlineCallback: (() -> Void)?
    var isOnline: Bool = false {
        didSet {
            isOnlineSetCount += 1
            setIsOnlineCallback?()
        }
    }

    var streamingModeSetCount = 0
    var setStreamingModeCallback: (() -> Void)?
    var streamingMode: LDStreamingMode = .streaming {
        didSet {
            streamingModeSetCount += 1
            setStreamingModeCallback?()
        }
    }

    var pollingIntervalSetCount = 0
    var setPollingIntervalCallback: (() -> Void)?
    var pollingInterval: TimeInterval = 60_000 {
        didSet {
            pollingIntervalSetCount += 1
            setPollingIntervalCallback?()
        }
    }
}

// MARK: - ThrottlingMock
final class ThrottlingMock: Throttling {

    var runThrottledCallCount = 0
    var runThrottledCallback: (() -> Void)?
    var runThrottledReceivedRunClosure: RunClosure?
    func runThrottled(_ runClosure: @escaping RunClosure) {
        runThrottledCallCount += 1
        runThrottledReceivedRunClosure = runClosure
        runThrottledCallback?()
    }

    var cancelThrottledRunCallCount = 0
    var cancelThrottledRunCallback: (() -> Void)?
    func cancelThrottledRun() {
        cancelThrottledRunCallCount += 1
        cancelThrottledRunCallback?()
    }
}
