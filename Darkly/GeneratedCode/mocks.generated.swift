// Generated using Sourcery 0.9.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

//swiftlint:disable vertical_whitespace


import DarklyEventSource
@testable import Darkly


// MARK: - DarklyStreamingProviderMock
final class DarklyStreamingProviderMock: DarklyStreamingProvider {

    // MARK: onMessageEvent
    var onMessageEventCallCount = 0
    var onMessageEventReceivedHandler: LDEventSourceEventHandler?
    func onMessageEvent(_ handler: LDEventSourceEventHandler?) {
        onMessageEventCallCount += 1
        onMessageEventReceivedHandler = handler
    }

    // MARK: close
    var closeCallCount = 0
    func close() {
        closeCallCount += 1
    }
}

// MARK: - FlagCollectionCachingMock
final class FlagCollectionCachingMock: FlagCollectionCaching {

    // MARK: retrieveFlags
    var retrieveFlagsCallCount = 0
    var retrieveFlagsReturnValue: [String: UserFlags] = [:]
    func retrieveFlags() -> [String: UserFlags] {
        retrieveFlagsCallCount += 1
        return retrieveFlagsReturnValue
    }

    // MARK: storeFlags
    var storeFlagsCallCount = 0
    var storeFlagsReceivedFlags: [String: UserFlags]?
    func storeFlags(_ flags: [String: UserFlags]) {
        storeFlagsCallCount += 1
        storeFlagsReceivedFlags = flags
    }
}

// MARK: - KeyedValueCachingMock
final class KeyedValueCachingMock: KeyedValueCaching {

    // MARK: set
    var setCallCount = 0
    var setReceivedArguments: (value: Any?, forKey: String)?
    func set(_ value: Any?, forKey: String) {
        setCallCount += 1
        setReceivedArguments = (value: value, forKey: forKey)
    }

    // MARK: dictionary
    var dictionaryCallCount = 0
    var dictionaryReceivedForKey: String?
    var dictionaryReturnValue: [String: Any]? = nil
    func dictionary(forKey: String) -> [String: Any]? {
        dictionaryCallCount += 1
        dictionaryReceivedForKey = forKey
        return dictionaryReturnValue
    }

    // MARK: removeObject
    var removeObjectCallCount = 0
    var removeObjectReceivedForKey: String?
    func removeObject(forKey: String) {
        removeObjectCallCount += 1
        removeObjectReceivedForKey = forKey
    }
}

// MARK: - LDEventReportingMock
final class LDEventReportingMock: LDEventReporting {

    // MARK: config
    var configSetCount = 0
    var config: LDConfig = LDConfig.stub {
        didSet { configSetCount += 1 }
    }

    // MARK: isOnline
    var isOnlineSetCount = 0
    var isOnline: Bool = false {
        didSet { isOnlineSetCount += 1 }
    }

    // MARK: isReportingActive
    var isReportingActiveSetCount = 0
    var isReportingActive: Bool = false {
        didSet { isReportingActiveSetCount += 1 }
    }

    // MARK: service
    var serviceSetCount = 0
    var service: DarklyServiceProvider = DarklyServiceMock() {
        didSet { serviceSetCount += 1 }
    }

    // MARK: record
    var recordCallCount = 0
    var recordReceivedArguments: (event: Darkly.LDEvent, completion: CompletionClosure?)?
    func record(_ event: Darkly.LDEvent, completion: CompletionClosure?) {
        recordCallCount += 1
        recordReceivedArguments = (event: event, completion: completion)
    }

    // MARK: reportEvents
    var reportEventsCallCount = 0
    func reportEvents() {
        reportEventsCallCount += 1
    }
}

// MARK: - LDFlagMaintainingMock
final class LDFlagMaintainingMock: LDFlagMaintaining {

    // MARK: featureFlags
    var featureFlagsSetCount = 0
    var featureFlags: [String: Any] = [:] {
        didSet { featureFlagsSetCount += 1 }
    }

    // MARK: flagValueSource
    var flagValueSourceSetCount = 0
    var flagValueSource: LDFlagValueSource = .cache {
        didSet { flagValueSourceSetCount += 1 }
    }

    // MARK: replaceStore
    var replaceStoreCallCount = 0
    var replaceStoreReceivedArguments: (newFlags: [String: Any]?, source: LDFlagValueSource, completion: CompletionClosure?)?
    func replaceStore(newFlags: [String: Any]?, source: LDFlagValueSource, completion: CompletionClosure?) {
        replaceStoreCallCount += 1
        replaceStoreReceivedArguments = (newFlags: newFlags, source: source, completion: completion)
    }

    // MARK: updateStore
    var updateStoreCallCount = 0
    var updateStoreReceivedArguments: (newFlags: [String: Any], source: LDFlagValueSource, completion: CompletionClosure?)?
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource, completion: CompletionClosure?) {
        updateStoreCallCount += 1
        updateStoreReceivedArguments = (newFlags: newFlags, source: source, completion: completion)
    }

    // MARK: deleteFlag
    var deleteFlagCallCount = 0
    var deleteFlagReceivedArguments: (name: String, completion: CompletionClosure?)?
    func deleteFlag(name: String, completion: CompletionClosure?) {
        deleteFlagCallCount += 1
        deleteFlagReceivedArguments = (name: name, completion: completion)
    }
}

// MARK: - LDFlagSynchronizingMock
final class LDFlagSynchronizingMock: LDFlagSynchronizing {

    // MARK: streamingMode
    var streamingModeSetCount = 0
    var streamingMode: LDStreamingMode = .streaming {
        didSet { streamingModeSetCount += 1 }
    }

    // MARK: isOnline
    var isOnlineSetCount = 0
    var isOnline: Bool = false {
        didSet { isOnlineSetCount += 1 }
    }

    // MARK: pollingInterval
    var pollingIntervalSetCount = 0
    var pollingInterval: TimeInterval = 0 {
        didSet { pollingIntervalSetCount += 1 }
    }

    // MARK: service
    var serviceSetCount = 0
    var service: DarklyServiceProvider = DarklyServiceMock() {
        didSet { serviceSetCount += 1 }
    }

    // MARK: onSync
    var onSyncSetCount = 0
    var onSync: FlagsReceivedClosure? {
        didSet { onSyncSetCount += 1 }
    }
}

// MARK: - UserFlagCachingMock
final class UserFlagCachingMock: UserFlagCaching {

    // MARK: cacheFlags
    var cacheFlagsCallCount = 0
    var cacheFlagsReceivedUser: LDUser?
    func cacheFlags(for user: LDUser) {
        cacheFlagsCallCount += 1
        cacheFlagsReceivedUser = user
    }

    // MARK: retrieveFlags
    var retrieveFlagsCallCount = 0
    var retrieveFlagsReceivedUser: LDUser?
    var retrieveFlagsReturnValue: UserFlags? = nil
    func retrieveFlags(for user: LDUser) -> UserFlags? {
        retrieveFlagsCallCount += 1
        retrieveFlagsReceivedUser = user
        return retrieveFlagsReturnValue
    }
}
