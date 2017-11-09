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

    // MARK: record
    var recordCallCount = 0
    var recordReceivedArguments: (event: Darkly.LDEvent, completion: (() -> Void)?)?
    func record(_ event: Darkly.LDEvent, completion: (() -> Void)?) {
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

    // MARK: replaceStore
    var replaceStoreCallCount = 0
    var replaceStoreReceivedArguments: (newFlags: [String: Any]?, source: LDFlagValueSource, completion: (() -> Void)?)?
    func replaceStore(newFlags: [String: Any]?, source: LDFlagValueSource, completion: (() -> Void)?) {
        replaceStoreCallCount += 1
        replaceStoreReceivedArguments = (newFlags: newFlags, source: source, completion: completion)
    }

    // MARK: updateStore
    var updateStoreCallCount = 0
    var updateStoreReceivedArguments: (newFlags: [String: Any], source: LDFlagValueSource, completion: (() -> Void)?)?
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource, completion: (() -> Void)?) {
        updateStoreCallCount += 1
        updateStoreReceivedArguments = (newFlags: newFlags, source: source, completion: completion)
    }

    // MARK: deleteFlag
    var deleteFlagCallCount = 0
    var deleteFlagReceivedArguments: (name: String, completion: (() -> Void)?)?
    func deleteFlag(name: String, completion: (() -> Void)?) {
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
}
