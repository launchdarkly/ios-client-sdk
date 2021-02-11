// Generated using Sourcery 0.16.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT


import Foundation
import LDSwiftEventSource
@testable import LaunchDarkly


// MARK: - CacheConvertingMock
final class CacheConvertingMock: CacheConverting {

    // MARK: convertCacheData
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

    // MARK: start
    var startCallCount = 0
    var startCallback: (() -> Void)?
    func start() {
        startCallCount += 1
        startCallback?()
    }

    // MARK: stop
    var stopCallCount = 0
    var stopCallback: (() -> Void)?
    func stop() {
        stopCallCount += 1
        stopCallback?()
    }
}

// MARK: - DiagnosticCachingMock
final class DiagnosticCachingMock: DiagnosticCaching {

    // MARK: lastStats
    var lastStatsSetCount = 0
    var setLastStatsCallback: (() -> Void)?
    var lastStats: DiagnosticStats? = nil {
        didSet {
            lastStatsSetCount += 1
            setLastStatsCallback?()
        }
    }

    // MARK: getDiagnosticId
    var getDiagnosticIdCallCount = 0
    var getDiagnosticIdCallback: (() -> Void)?
    var getDiagnosticIdReturnValue: DiagnosticId!
    func getDiagnosticId() -> DiagnosticId {
        getDiagnosticIdCallCount += 1
        getDiagnosticIdCallback?()
        return getDiagnosticIdReturnValue
    }

    // MARK: getCurrentStatsAndReset
    var getCurrentStatsAndResetCallCount = 0
    var getCurrentStatsAndResetCallback: (() -> Void)?
    var getCurrentStatsAndResetReturnValue: DiagnosticStats!
    func getCurrentStatsAndReset() -> DiagnosticStats {
        getCurrentStatsAndResetCallCount += 1
        getCurrentStatsAndResetCallback?()
        return getCurrentStatsAndResetReturnValue
    }

    // MARK: incrementDroppedEventCount
    var incrementDroppedEventCountCallCount = 0
    var incrementDroppedEventCountCallback: (() -> Void)?
    func incrementDroppedEventCount() {
        incrementDroppedEventCountCallCount += 1
        incrementDroppedEventCountCallback?()
    }

    // MARK: recordEventsInLastBatch
    var recordEventsInLastBatchCallCount = 0
    var recordEventsInLastBatchCallback: (() -> Void)?
    var recordEventsInLastBatchReceivedEventsInLastBatch: Int?
    func recordEventsInLastBatch(eventsInLastBatch: Int) {
        recordEventsInLastBatchCallCount += 1
        recordEventsInLastBatchReceivedEventsInLastBatch = eventsInLastBatch
        recordEventsInLastBatchCallback?()
    }

    // MARK: addStreamInit
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

    // MARK: service
    var serviceSetCount = 0
    var setServiceCallback: (() -> Void)?
    var service: DarklyServiceProvider = DarklyServiceMock() {
        didSet {
            serviceSetCount += 1
            setServiceCallback?()
        }
    }

    // MARK: runMode
    var runModeSetCount = 0
    var setRunModeCallback: (() -> Void)?
    var runMode: LDClientRunMode = .foreground {
        didSet {
            runModeSetCount += 1
            setRunModeCallback?()
        }
    }

    // MARK: isOnline
    var isOnlineSetCount = 0
    var setIsOnlineCallback: (() -> Void)?
    var isOnline: Bool = false {
        didSet {
            isOnlineSetCount += 1
            setIsOnlineCallback?()
        }
    }
}

// MARK: - EnvironmentReportingMock
final class EnvironmentReportingMock: EnvironmentReporting {

    // MARK: isDebugBuild
    var isDebugBuildSetCount = 0
    var setIsDebugBuildCallback: (() -> Void)?
    var isDebugBuild: Bool = true {
        didSet {
            isDebugBuildSetCount += 1
            setIsDebugBuildCallback?()
        }
    }

    // MARK: deviceType
    var deviceTypeSetCount = 0
    var setDeviceTypeCallback: (() -> Void)?
    var deviceType: String = Constants.deviceType {
        didSet {
            deviceTypeSetCount += 1
            setDeviceTypeCallback?()
        }
    }

    // MARK: deviceModel
    var deviceModelSetCount = 0
    var setDeviceModelCallback: (() -> Void)?
    var deviceModel: String = Constants.deviceModel {
        didSet {
            deviceModelSetCount += 1
            setDeviceModelCallback?()
        }
    }

    // MARK: systemVersion
    var systemVersionSetCount = 0
    var setSystemVersionCallback: (() -> Void)?
    var systemVersion: String = Constants.systemVersion {
        didSet {
            systemVersionSetCount += 1
            setSystemVersionCallback?()
        }
    }

    // MARK: systemName
    var systemNameSetCount = 0
    var setSystemNameCallback: (() -> Void)?
    var systemName: String = Constants.systemName {
        didSet {
            systemNameSetCount += 1
            setSystemNameCallback?()
        }
    }

    // MARK: operatingSystem
    var operatingSystemSetCount = 0
    var setOperatingSystemCallback: (() -> Void)?
    var operatingSystem: OperatingSystem = .iOS {
        didSet {
            operatingSystemSetCount += 1
            setOperatingSystemCallback?()
        }
    }

    // MARK: backgroundNotification
    var backgroundNotificationSetCount = 0
    var setBackgroundNotificationCallback: (() -> Void)?
    var backgroundNotification: Notification.Name? = EnvironmentReporter().backgroundNotification {
        didSet {
            backgroundNotificationSetCount += 1
            setBackgroundNotificationCallback?()
        }
    }

    // MARK: foregroundNotification
    var foregroundNotificationSetCount = 0
    var setForegroundNotificationCallback: (() -> Void)?
    var foregroundNotification: Notification.Name? = EnvironmentReporter().foregroundNotification {
        didSet {
            foregroundNotificationSetCount += 1
            setForegroundNotificationCallback?()
        }
    }

    // MARK: vendorUUID
    var vendorUUIDSetCount = 0
    var setVendorUUIDCallback: (() -> Void)?
    var vendorUUID: String? = Constants.vendorUUID {
        didSet {
            vendorUUIDSetCount += 1
            setVendorUUIDCallback?()
        }
    }

    // MARK: sdkVersion
    var sdkVersionSetCount = 0
    var setSdkVersionCallback: (() -> Void)?
    var sdkVersion: String = Constants.sdkVersion {
        didSet {
            sdkVersionSetCount += 1
            setSdkVersionCallback?()
        }
    }

    // MARK: shouldThrottleOnlineCalls
    var shouldThrottleOnlineCallsSetCount = 0
    var setShouldThrottleOnlineCallsCallback: (() -> Void)?
    var shouldThrottleOnlineCalls: Bool = true {
        didSet {
            shouldThrottleOnlineCallsSetCount += 1
            setShouldThrottleOnlineCallsCallback?()
        }
    }
}

// MARK: - ErrorNotifyingMock
final class ErrorNotifyingMock: ErrorNotifying {

    // MARK: addErrorObserver
    var addErrorObserverCallCount = 0
    var addErrorObserverCallback: (() -> Void)?
    var addErrorObserverReceivedObserver: ErrorObserver?
    func addErrorObserver(_ observer: ErrorObserver) {
        addErrorObserverCallCount += 1
        addErrorObserverReceivedObserver = observer
        addErrorObserverCallback?()
    }

    // MARK: removeObservers
    var removeObserversCallCount = 0
    var removeObserversCallback: (() -> Void)?
    var removeObserversReceivedOwner: LDObserverOwner?
    func removeObservers(for owner: LDObserverOwner) {
        removeObserversCallCount += 1
        removeObserversReceivedOwner = owner
        removeObserversCallback?()
    }

    // MARK: notifyObservers
    var notifyObserversCallCount = 0
    var notifyObserversCallback: (() -> Void)?
    var notifyObserversReceivedError: Error?
    func notifyObservers(of error: Error) {
        notifyObserversCallCount += 1
        notifyObserversReceivedError = error
        notifyObserversCallback?()
    }
}

// MARK: - EventReportingMock
final class EventReportingMock: EventReporting {

    // MARK: config
    var configSetCount = 0
    var setConfigCallback: (() -> Void)?
    var config: LDConfig = LDConfig.stub {
        didSet {
            configSetCount += 1
            setConfigCallback?()
        }
    }

    // MARK: isOnline
    var isOnlineSetCount = 0
    var setIsOnlineCallback: (() -> Void)?
    var isOnline: Bool = false {
        didSet {
            isOnlineSetCount += 1
            setIsOnlineCallback?()
        }
    }

    // MARK: service
    var serviceSetCount = 0
    var setServiceCallback: (() -> Void)?
    var service: DarklyServiceProvider = DarklyServiceMock() {
        didSet {
            serviceSetCount += 1
            setServiceCallback?()
        }
    }

    // MARK: lastEventResponseDate
    var lastEventResponseDateSetCount = 0
    var setLastEventResponseDateCallback: (() -> Void)?
    var lastEventResponseDate: Date? = nil {
        didSet {
            lastEventResponseDateSetCount += 1
            setLastEventResponseDateCallback?()
        }
    }

    // MARK: record
    var recordCallCount = 0
    var recordCallback: (() -> Void)?
    var recordReceivedEvent: Event?
    func record(_ event: Event) {
        recordCallCount += 1
        recordReceivedEvent = event
        recordCallback?()
    }

    // MARK: recordFlagEvaluationEvents
    var recordFlagEvaluationEventsCallCount = 0
    var recordFlagEvaluationEventsCallback: (() -> Void)?
    //swiftlint:disable:next large_tuple 
    var recordFlagEvaluationEventsReceivedArguments: (flagKey: LDFlagKey, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool)?
    func recordFlagEvaluationEvents(flagKey: LDFlagKey, value: Any?, defaultValue: Any?, featureFlag: FeatureFlag?, user: LDUser, includeReason: Bool) {
        recordFlagEvaluationEventsCallCount += 1
        recordFlagEvaluationEventsReceivedArguments = (flagKey: flagKey, value: value, defaultValue: defaultValue, featureFlag: featureFlag, user: user, includeReason: includeReason)
        recordFlagEvaluationEventsCallback?()
    }

    // MARK: flush
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

    // MARK: maxCachedUsers
    var maxCachedUsersSetCount = 0
    var setMaxCachedUsersCallback: (() -> Void)?
    var maxCachedUsers: Int = 5 {
        didSet {
            maxCachedUsersSetCount += 1
            setMaxCachedUsersCallback?()
        }
    }

    // MARK: retrieveFeatureFlags
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

    // MARK: storeFeatureFlags
    var storeFeatureFlagsCallCount = 0
    var storeFeatureFlagsCallback: (() -> Void)?
    //swiftlint:disable:next large_tuple 
    var storeFeatureFlagsReceivedArguments: (featureFlags: [LDFlagKey: FeatureFlag], user: LDUser, mobileKey: String, lastUpdated: Date, storeMode: FlagCachingStoreMode)?
    func storeFeatureFlags(_ featureFlags: [LDFlagKey: FeatureFlag], forUser user: LDUser, andMobileKey mobileKey: String, lastUpdated: Date, storeMode: FlagCachingStoreMode) {
        storeFeatureFlagsCallCount += 1
        storeFeatureFlagsReceivedArguments = (featureFlags: featureFlags, user: user, mobileKey: mobileKey, lastUpdated: lastUpdated, storeMode: storeMode)
        storeFeatureFlagsCallback?()
    }
}

// MARK: - FlagChangeNotifyingMock
final class FlagChangeNotifyingMock: FlagChangeNotifying {

    // MARK: addFlagChangeObserver
    var addFlagChangeObserverCallCount = 0
    var addFlagChangeObserverCallback: (() -> Void)?
    var addFlagChangeObserverReceivedObserver: FlagChangeObserver?
    func addFlagChangeObserver(_ observer: FlagChangeObserver) {
        addFlagChangeObserverCallCount += 1
        addFlagChangeObserverReceivedObserver = observer
        addFlagChangeObserverCallback?()
    }

    // MARK: addFlagsUnchangedObserver
    var addFlagsUnchangedObserverCallCount = 0
    var addFlagsUnchangedObserverCallback: (() -> Void)?
    var addFlagsUnchangedObserverReceivedObserver: FlagsUnchangedObserver?
    func addFlagsUnchangedObserver(_ observer: FlagsUnchangedObserver) {
        addFlagsUnchangedObserverCallCount += 1
        addFlagsUnchangedObserverReceivedObserver = observer
        addFlagsUnchangedObserverCallback?()
    }

    // MARK: addConnectionModeChangedObserver
    var addConnectionModeChangedObserverCallCount = 0
    var addConnectionModeChangedObserverCallback: (() -> Void)?
    var addConnectionModeChangedObserverReceivedObserver: ConnectionModeChangedObserver?
    func addConnectionModeChangedObserver(_ observer: ConnectionModeChangedObserver) {
        addConnectionModeChangedObserverCallCount += 1
        addConnectionModeChangedObserverReceivedObserver = observer
        addConnectionModeChangedObserverCallback?()
    }

    // MARK: removeObserver
    var removeObserverCallCount = 0
    var removeObserverCallback: (() -> Void)?
    var removeObserverReceivedArguments: (keys: [LDFlagKey], owner: LDObserverOwner)?
    func removeObserver(_ keys: [LDFlagKey], owner: LDObserverOwner) {
        removeObserverCallCount += 1
        removeObserverReceivedArguments = (keys: keys, owner: owner)
        removeObserverCallback?()
    }

    // MARK: notifyConnectionModeChangedObservers
    var notifyConnectionModeChangedObserversCallCount = 0
    var notifyConnectionModeChangedObserversCallback: (() -> Void)?
    var notifyConnectionModeChangedObserversReceivedConnectionMode: ConnectionInformation.ConnectionMode?
    func notifyConnectionModeChangedObservers(connectionMode: ConnectionInformation.ConnectionMode) {
        notifyConnectionModeChangedObserversCallCount += 1
        notifyConnectionModeChangedObserversReceivedConnectionMode = connectionMode
        notifyConnectionModeChangedObserversCallback?()
    }

    // MARK: notifyObservers
    var notifyObserversCallCount = 0
    var notifyObserversCallback: (() -> Void)?
    var notifyObserversReceivedArguments: (flagStore: FlagMaintaining, oldFlags: [LDFlagKey: FeatureFlag])?
    func notifyObservers(flagStore: FlagMaintaining, oldFlags: [LDFlagKey: FeatureFlag]) {
        notifyObserversCallCount += 1
        notifyObserversReceivedArguments = (flagStore: flagStore, oldFlags: oldFlags)
        notifyObserversCallback?()
    }
}

// MARK: - FlagMaintainingMock
final class FlagMaintainingMock: FlagMaintaining {

    // MARK: featureFlags
    var featureFlagsSetCount = 0
    var setFeatureFlagsCallback: (() -> Void)?
    var featureFlags: [LDFlagKey: FeatureFlag] = [:] {
        didSet {
            featureFlagsSetCount += 1
            setFeatureFlagsCallback?()
        }
    }

    // MARK: replaceStore
    var replaceStoreCallCount = 0
    var replaceStoreCallback: (() -> Void)?
    var replaceStoreReceivedArguments: (newFlags: [LDFlagKey: Any]?, completion: CompletionClosure?)?
    func replaceStore(newFlags: [LDFlagKey: Any]?, completion: CompletionClosure?) {
        replaceStoreCallCount += 1
        replaceStoreReceivedArguments = (newFlags: newFlags, completion: completion)
        replaceStoreCallback?()
    }

    // MARK: updateStore
    var updateStoreCallCount = 0
    var updateStoreCallback: (() -> Void)?
    var updateStoreReceivedArguments: (updateDictionary: [String: Any], completion: CompletionClosure?)?
    func updateStore(updateDictionary: [String: Any], completion: CompletionClosure?) {
        updateStoreCallCount += 1
        updateStoreReceivedArguments = (updateDictionary: updateDictionary, completion: completion)
        updateStoreCallback?()
    }

    // MARK: deleteFlag
    var deleteFlagCallCount = 0
    var deleteFlagCallback: (() -> Void)?
    var deleteFlagReceivedArguments: (deleteDictionary: [String: Any], completion: CompletionClosure?)?
    func deleteFlag(deleteDictionary: [String: Any], completion: CompletionClosure?) {
        deleteFlagCallCount += 1
        deleteFlagReceivedArguments = (deleteDictionary: deleteDictionary, completion: completion)
        deleteFlagCallback?()
    }
}

// MARK: - KeyedValueCachingMock
final class KeyedValueCachingMock: KeyedValueCaching {

    // MARK: set
    var setCallCount = 0
    var setCallback: (() -> Void)?
    var setReceivedArguments: (value: Any?, forKey: String)?
    func set(_ value: Any?, forKey: String) {
        setCallCount += 1
        setReceivedArguments = (value: value, forKey: forKey)
        setCallback?()
    }

    // MARK: dictionary
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

    // MARK: removeObject
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

    // MARK: isOnline
    var isOnlineSetCount = 0
    var setIsOnlineCallback: (() -> Void)?
    var isOnline: Bool = false {
        didSet {
            isOnlineSetCount += 1
            setIsOnlineCallback?()
        }
    }

    // MARK: streamingMode
    var streamingModeSetCount = 0
    var setStreamingModeCallback: (() -> Void)?
    var streamingMode: LDStreamingMode = .streaming {
        didSet {
            streamingModeSetCount += 1
            setStreamingModeCallback?()
        }
    }

    // MARK: pollingInterval
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

    // MARK: runThrottled
    var runThrottledCallCount = 0
    var runThrottledCallback: (() -> Void)?
    var runThrottledReceivedRunClosure: RunClosure?
    func runThrottled(_ runClosure: @escaping RunClosure) {
        runThrottledCallCount += 1
        runThrottledReceivedRunClosure = runClosure
        runThrottledCallback?()
    }

    // MARK: cancelThrottledRun
    var cancelThrottledRunCallCount = 0
    var cancelThrottledRunCallback: (() -> Void)?
    func cancelThrottledRun() {
        cancelThrottledRunCallCount += 1
        cancelThrottledRunCallback?()
    }
}
