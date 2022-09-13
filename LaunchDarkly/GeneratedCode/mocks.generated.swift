// Generated using Sourcery 1.2.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import Foundation
@_implementationOnly import LDSwiftEventSource
@testable import LaunchDarkly

// swiftlint:disable large_tuple

// MARK: - CacheConvertingMock
final class CacheConvertingMock: CacheConverting {

    var convertCacheDataCallCount = 0
    var convertCacheDataCallback: (() throws -> Void)?
    var convertCacheDataReceivedArguments: (serviceFactory: ClientServiceCreating, keysToConvert: [MobileKey], maxCachedUsers: Int)?
    func convertCacheData(serviceFactory: ClientServiceCreating, keysToConvert: [MobileKey], maxCachedUsers: Int) {
        convertCacheDataCallCount += 1
        convertCacheDataReceivedArguments = (serviceFactory: serviceFactory, keysToConvert: keysToConvert, maxCachedUsers: maxCachedUsers)
        try! convertCacheDataCallback?()
    }
}

// MARK: - DarklyStreamingProviderMock
final class DarklyStreamingProviderMock: DarklyStreamingProvider {

    var startCallCount = 0
    var startCallback: (() throws -> Void)?
    func start() {
        startCallCount += 1
        try! startCallback?()
    }

    var stopCallCount = 0
    var stopCallback: (() throws -> Void)?
    func stop() {
        stopCallCount += 1
        try! stopCallback?()
    }
}

// MARK: - DiagnosticCachingMock
final class DiagnosticCachingMock: DiagnosticCaching {

    var lastStatsSetCount = 0
    var setLastStatsCallback: (() throws -> Void)?
    var lastStats: DiagnosticStats? = nil {
        didSet {
            lastStatsSetCount += 1
            try! setLastStatsCallback?()
        }
    }

    var getDiagnosticIdCallCount = 0
    var getDiagnosticIdCallback: (() throws -> Void)?
    var getDiagnosticIdReturnValue: DiagnosticId!
    func getDiagnosticId() -> DiagnosticId {
        getDiagnosticIdCallCount += 1
        try! getDiagnosticIdCallback?()
        return getDiagnosticIdReturnValue
    }

    var getCurrentStatsAndResetCallCount = 0
    var getCurrentStatsAndResetCallback: (() throws -> Void)?
    var getCurrentStatsAndResetReturnValue: DiagnosticStats!
    func getCurrentStatsAndReset() -> DiagnosticStats {
        getCurrentStatsAndResetCallCount += 1
        try! getCurrentStatsAndResetCallback?()
        return getCurrentStatsAndResetReturnValue
    }

    var incrementDroppedEventCountCallCount = 0
    var incrementDroppedEventCountCallback: (() throws -> Void)?
    func incrementDroppedEventCount() {
        incrementDroppedEventCountCallCount += 1
        try! incrementDroppedEventCountCallback?()
    }

    var recordEventsInLastBatchCallCount = 0
    var recordEventsInLastBatchCallback: (() throws -> Void)?
    var recordEventsInLastBatchReceivedEventsInLastBatch: Int?
    func recordEventsInLastBatch(eventsInLastBatch: Int) {
        recordEventsInLastBatchCallCount += 1
        recordEventsInLastBatchReceivedEventsInLastBatch = eventsInLastBatch
        try! recordEventsInLastBatchCallback?()
    }

    var addStreamInitCallCount = 0
    var addStreamInitCallback: (() throws -> Void)?
    var addStreamInitReceivedStreamInit: DiagnosticStreamInit?
    func addStreamInit(streamInit: DiagnosticStreamInit) {
        addStreamInitCallCount += 1
        addStreamInitReceivedStreamInit = streamInit
        try! addStreamInitCallback?()
    }
}

// MARK: - DiagnosticReportingMock
final class DiagnosticReportingMock: DiagnosticReporting {

    var setModeCallCount = 0
    var setModeCallback: (() throws -> Void)?
    var setModeReceivedArguments: (runMode: LDClientRunMode, online: Bool)?
    func setMode(_ runMode: LDClientRunMode, online: Bool) {
        setModeCallCount += 1
        setModeReceivedArguments = (runMode: runMode, online: online)
        try! setModeCallback?()
    }
}

// MARK: - EnvironmentReportingMock
final class EnvironmentReportingMock: EnvironmentReporting {

    var isDebugBuildSetCount = 0
    var setIsDebugBuildCallback: (() throws -> Void)?
    var isDebugBuild: Bool = true {
        didSet {
            isDebugBuildSetCount += 1
            try! setIsDebugBuildCallback?()
        }
    }

    var deviceTypeSetCount = 0
    var setDeviceTypeCallback: (() throws -> Void)?
    var deviceType: String = Constants.deviceType {
        didSet {
            deviceTypeSetCount += 1
            try! setDeviceTypeCallback?()
        }
    }

    var deviceModelSetCount = 0
    var setDeviceModelCallback: (() throws -> Void)?
    var deviceModel: String = Constants.deviceModel {
        didSet {
            deviceModelSetCount += 1
            try! setDeviceModelCallback?()
        }
    }

    var systemVersionSetCount = 0
    var setSystemVersionCallback: (() throws -> Void)?
    var systemVersion: String = Constants.systemVersion {
        didSet {
            systemVersionSetCount += 1
            try! setSystemVersionCallback?()
        }
    }

    var systemNameSetCount = 0
    var setSystemNameCallback: (() throws -> Void)?
    var systemName: String = Constants.systemName {
        didSet {
            systemNameSetCount += 1
            try! setSystemNameCallback?()
        }
    }

    var operatingSystemSetCount = 0
    var setOperatingSystemCallback: (() throws -> Void)?
    var operatingSystem: OperatingSystem = .iOS {
        didSet {
            operatingSystemSetCount += 1
            try! setOperatingSystemCallback?()
        }
    }

    var backgroundNotificationSetCount = 0
    var setBackgroundNotificationCallback: (() throws -> Void)?
    var backgroundNotification: Notification.Name? = EnvironmentReporter().backgroundNotification {
        didSet {
            backgroundNotificationSetCount += 1
            try! setBackgroundNotificationCallback?()
        }
    }

    var foregroundNotificationSetCount = 0
    var setForegroundNotificationCallback: (() throws -> Void)?
    var foregroundNotification: Notification.Name? = EnvironmentReporter().foregroundNotification {
        didSet {
            foregroundNotificationSetCount += 1
            try! setForegroundNotificationCallback?()
        }
    }

    var vendorUUIDSetCount = 0
    var setVendorUUIDCallback: (() throws -> Void)?
    var vendorUUID: String? = Constants.vendorUUID {
        didSet {
            vendorUUIDSetCount += 1
            try! setVendorUUIDCallback?()
        }
    }

    var sdkVersionSetCount = 0
    var setSdkVersionCallback: (() throws -> Void)?
    var sdkVersion: String = Constants.sdkVersion {
        didSet {
            sdkVersionSetCount += 1
            try! setSdkVersionCallback?()
        }
    }

    var shouldThrottleOnlineCallsSetCount = 0
    var setShouldThrottleOnlineCallsCallback: (() throws -> Void)?
    var shouldThrottleOnlineCalls: Bool = true {
        didSet {
            shouldThrottleOnlineCallsSetCount += 1
            try! setShouldThrottleOnlineCallsCallback?()
        }
    }
}

// MARK: - EventReportingMock
final class EventReportingMock: EventReporting {

    var isOnlineSetCount = 0
    var setIsOnlineCallback: (() throws -> Void)?
    var isOnline: Bool = false {
        didSet {
            isOnlineSetCount += 1
            try! setIsOnlineCallback?()
        }
    }

    var lastEventResponseDateSetCount = 0
    var setLastEventResponseDateCallback: (() throws -> Void)?
    var lastEventResponseDate: Date? = nil {
        didSet {
            lastEventResponseDateSetCount += 1
            try! setLastEventResponseDateCallback?()
        }
    }

    var recordCallCount = 0
    var recordCallback: (() throws -> Void)?
    var recordReceivedEvent: Event?
    func record(_ event: Event) {
        recordCallCount += 1
        recordReceivedEvent = event
        try! recordCallback?()
    }

    var recordFlagEvaluationEventsCallCount = 0
    var recordFlagEvaluationEventsCallback: (() throws -> Void)?
    var recordFlagEvaluationEventsReceivedArguments: (flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool)?
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: LDValue, defaultValue: LDValue, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool) {
        recordFlagEvaluationEventsCallCount += 1
        recordFlagEvaluationEventsReceivedArguments = (flagKey: flagKey, value: value, defaultValue: defaultValue, featureFlag: featureFlag, user: user, includeReason: includeReason)
        try! recordFlagEvaluationEventsCallback?()
    }

    var flushCallCount = 0
    var flushCallback: (() throws -> Void)?
    var flushReceivedCompletion: CompletionClosure?
    func flush(completion: CompletionClosure?) {
        flushCallCount += 1
        flushReceivedCompletion = completion
        try! flushCallback?()
    }
}

// MARK: - FeatureFlagCachingMock
final class FeatureFlagCachingMock: FeatureFlagCaching {

    var keyedValueCacheSetCount = 0
    var setKeyedValueCacheCallback: (() throws -> Void)?
    var keyedValueCache: KeyedValueCaching = KeyedValueCachingMock() {
        didSet {
            keyedValueCacheSetCount += 1
            try! setKeyedValueCacheCallback?()
        }
    }

    var retrieveFeatureFlagsCallCount = 0
    var retrieveFeatureFlagsCallback: (() throws -> Void)?
    var retrieveFeatureFlagsReceivedUserKey: String?
    var retrieveFeatureFlagsReturnValue: StoredItems?
    func retrieveFeatureFlags(userKey: String) -> StoredItems? {
        retrieveFeatureFlagsCallCount += 1
        retrieveFeatureFlagsReceivedUserKey = userKey
        try! retrieveFeatureFlagsCallback?()
        return retrieveFeatureFlagsReturnValue
    }

    var storeFeatureFlagsCallCount = 0
    var storeFeatureFlagsCallback: (() throws -> Void)?
    var storeFeatureFlagsReceivedArguments: (storedItems: StoredItems, userKey: String, lastUpdated: Date)?
    func storeFeatureFlags(_ storedItems: StoredItems, userKey: String, lastUpdated: Date) {
        storeFeatureFlagsCallCount += 1
        storeFeatureFlagsReceivedArguments = (storedItems: storedItems, userKey: userKey, lastUpdated: lastUpdated)
        try! storeFeatureFlagsCallback?()
    }
}

// MARK: - FlagChangeNotifyingMock
final class FlagChangeNotifyingMock: FlagChangeNotifying {

    var addFlagChangeObserverCallCount = 0
    var addFlagChangeObserverCallback: (() throws -> Void)?
    var addFlagChangeObserverReceivedObserver: FlagChangeObserver?
    func addFlagChangeObserver(_ observer: FlagChangeObserver) {
        addFlagChangeObserverCallCount += 1
        addFlagChangeObserverReceivedObserver = observer
        try! addFlagChangeObserverCallback?()
    }

    var addFlagsUnchangedObserverCallCount = 0
    var addFlagsUnchangedObserverCallback: (() throws -> Void)?
    var addFlagsUnchangedObserverReceivedObserver: FlagsUnchangedObserver?
    func addFlagsUnchangedObserver(_ observer: FlagsUnchangedObserver) {
        addFlagsUnchangedObserverCallCount += 1
        addFlagsUnchangedObserverReceivedObserver = observer
        try! addFlagsUnchangedObserverCallback?()
    }

    var addConnectionModeChangedObserverCallCount = 0
    var addConnectionModeChangedObserverCallback: (() throws -> Void)?
    var addConnectionModeChangedObserverReceivedObserver: ConnectionModeChangedObserver?
    func addConnectionModeChangedObserver(_ observer: ConnectionModeChangedObserver) {
        addConnectionModeChangedObserverCallCount += 1
        addConnectionModeChangedObserverReceivedObserver = observer
        try! addConnectionModeChangedObserverCallback?()
    }

    var removeObserverCallCount = 0
    var removeObserverCallback: (() throws -> Void)?
    var removeObserverReceivedOwner: LDObserverOwner?
    func removeObserver(owner: LDObserverOwner) {
        removeObserverCallCount += 1
        removeObserverReceivedOwner = owner
        try! removeObserverCallback?()
    }

    var notifyConnectionModeChangedObserversCallCount = 0
    var notifyConnectionModeChangedObserversCallback: (() throws -> Void)?
    var notifyConnectionModeChangedObserversReceivedConnectionMode: ConnectionInformation.ConnectionMode?
    func notifyConnectionModeChangedObservers(connectionMode: ConnectionInformation.ConnectionMode) {
        notifyConnectionModeChangedObserversCallCount += 1
        notifyConnectionModeChangedObserversReceivedConnectionMode = connectionMode
        try! notifyConnectionModeChangedObserversCallback?()
    }

    var notifyUnchangedCallCount = 0
    var notifyUnchangedCallback: (() throws -> Void)?
    func notifyUnchanged() {
        notifyUnchangedCallCount += 1
        try! notifyUnchangedCallback?()
    }

    var notifyObserversCallCount = 0
    var notifyObserversCallback: (() throws -> Void)?
    var notifyObserversReceivedArguments: (oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag])?
    func notifyObservers(oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag]) {
        notifyObserversCallCount += 1
        notifyObserversReceivedArguments = (oldFlags: oldFlags, newFlags: newFlags)
        try! notifyObserversCallback?()
    }
}

// MARK: - KeyedValueCachingMock
final class KeyedValueCachingMock: KeyedValueCaching {

    var setCallCount = 0
    var setCallback: (() throws -> Void)?
    var setReceivedArguments: (value: Data, forKey: String)?
    func set(_ value: Data, forKey: String) {
        setCallCount += 1
        setReceivedArguments = (value: value, forKey: forKey)
        try! setCallback?()
    }

    var dataCallCount = 0
    var dataCallback: (() throws -> Void)?
    var dataReceivedForKey: String?
    var dataReturnValue: Data?
    func data(forKey: String) -> Data? {
        dataCallCount += 1
        dataReceivedForKey = forKey
        try! dataCallback?()
        return dataReturnValue
    }

    var dictionaryCallCount = 0
    var dictionaryCallback: (() throws -> Void)?
    var dictionaryReceivedForKey: String?
    var dictionaryReturnValue: [String: Any]?
    func dictionary(forKey: String) -> [String: Any]? {
        dictionaryCallCount += 1
        dictionaryReceivedForKey = forKey
        try! dictionaryCallback?()
        return dictionaryReturnValue
    }

    var removeObjectCallCount = 0
    var removeObjectCallback: (() throws -> Void)?
    var removeObjectReceivedForKey: String?
    func removeObject(forKey: String) {
        removeObjectCallCount += 1
        removeObjectReceivedForKey = forKey
        try! removeObjectCallback?()
    }

    var removeAllCallCount = 0
    var removeAllCallback: (() throws -> Void)?
    func removeAll() {
        removeAllCallCount += 1
        try! removeAllCallback?()
    }

    var keysCallCount = 0
    var keysCallback: (() throws -> Void)?
    var keysReturnValue: [String]!
    func keys() -> [String] {
        keysCallCount += 1
        try! keysCallback?()
        return keysReturnValue
    }
}

// MARK: - LDFlagSynchronizingMock
final class LDFlagSynchronizingMock: LDFlagSynchronizing {

    var isOnlineSetCount = 0
    var setIsOnlineCallback: (() throws -> Void)?
    var isOnline: Bool = false {
        didSet {
            isOnlineSetCount += 1
            try! setIsOnlineCallback?()
        }
    }

    var streamingModeSetCount = 0
    var setStreamingModeCallback: (() throws -> Void)?
    var streamingMode: LDStreamingMode = .streaming {
        didSet {
            streamingModeSetCount += 1
            try! setStreamingModeCallback?()
        }
    }

    var pollingIntervalSetCount = 0
    var setPollingIntervalCallback: (() throws -> Void)?
    var pollingInterval: TimeInterval = 60_000 {
        didSet {
            pollingIntervalSetCount += 1
            try! setPollingIntervalCallback?()
        }
    }
}

// MARK: - ThrottlingMock
final class ThrottlingMock: Throttling {

    var runThrottledCallCount = 0
    var runThrottledCallback: (() throws -> Void)?
    var runThrottledReceivedRunClosure: RunClosure?
    func runThrottled(_ runClosure: @escaping RunClosure) {
        runThrottledCallCount += 1
        runThrottledReceivedRunClosure = runClosure
        try! runThrottledCallback?()
    }

    var cancelThrottledRunCallCount = 0
    var cancelThrottledRunCallback: (() throws -> Void)?
    func cancelThrottledRun() {
        cancelThrottledRunCallCount += 1
        try! cancelThrottledRunCallback?()
    }
}
