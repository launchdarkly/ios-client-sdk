import Foundation

@testable import LaunchDarkly

/// Written by hand rather than generated, because the SDK calls it from whichever thread records, commits or delivers
/// events while a test reads the counts. Every property is guarded by `lock`; callbacks run outside it.
final class DiagnosticCachingMock: DiagnosticCaching {
    private let lock = NSLock()

    private var _getDiagnosticIdCallCount = 0
    private var _getDiagnosticIdCallback: (() throws -> Void)?
    private var _getDiagnosticIdReturnValue: DiagnosticId!

    private var _getCurrentStatsAndResetCallCount = 0
    private var _getCurrentStatsAndResetCallback: (() throws -> Void)?
    private var _getCurrentStatsAndResetReturnValue: DiagnosticStats!

    private var _incrementDroppedEventCountCallCount = 0
    private var _incrementDroppedEventCountCallback: (() throws -> Void)?
    private var _droppedEventCount = 0

    private var _recordEventsInLastBatchCallCount = 0
    private var _recordEventsInLastBatchCallback: (() throws -> Void)?
    private var _recordEventsInLastBatchReceivedEventsInLastBatch: Int?

    private var _addStreamInitCallCount = 0
    private var _addStreamInitCallback: (() throws -> Void)?
    private var _addStreamInitReceivedStreamInit: DiagnosticStreamInit?

    private func synchronized<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var getDiagnosticIdCallCount: Int {
        get { synchronized { _getDiagnosticIdCallCount } }
        set { synchronized { _getDiagnosticIdCallCount = newValue } }
    }
    var getDiagnosticIdCallback: (() throws -> Void)? {
        get { synchronized { _getDiagnosticIdCallback } }
        set { synchronized { _getDiagnosticIdCallback = newValue } }
    }
    var getDiagnosticIdReturnValue: DiagnosticId! {
        get { synchronized { _getDiagnosticIdReturnValue } }
        set { synchronized { _getDiagnosticIdReturnValue = newValue } }
    }
    func getDiagnosticId() -> DiagnosticId {
        let (callback, returnValue) = synchronized { () -> ((() throws -> Void)?, DiagnosticId?) in
            _getDiagnosticIdCallCount += 1
            return (_getDiagnosticIdCallback, _getDiagnosticIdReturnValue)
        }
        try! callback?()
        return returnValue!
    }

    var getCurrentStatsAndResetCallCount: Int {
        get { synchronized { _getCurrentStatsAndResetCallCount } }
        set { synchronized { _getCurrentStatsAndResetCallCount = newValue } }
    }
    var getCurrentStatsAndResetCallback: (() throws -> Void)? {
        get { synchronized { _getCurrentStatsAndResetCallback } }
        set { synchronized { _getCurrentStatsAndResetCallback = newValue } }
    }
    var getCurrentStatsAndResetReturnValue: DiagnosticStats! {
        get { synchronized { _getCurrentStatsAndResetReturnValue } }
        set { synchronized { _getCurrentStatsAndResetReturnValue = newValue } }
    }
    func getCurrentStatsAndReset() -> DiagnosticStats {
        let (callback, returnValue) = synchronized { () -> ((() throws -> Void)?, DiagnosticStats?) in
            _getCurrentStatsAndResetCallCount += 1
            return (_getCurrentStatsAndResetCallback, _getCurrentStatsAndResetReturnValue)
        }
        try! callback?()
        return returnValue!
    }

    var incrementDroppedEventCountCallCount: Int {
        get { synchronized { _incrementDroppedEventCountCallCount } }
        set { synchronized { _incrementDroppedEventCountCallCount = newValue } }
    }
    var incrementDroppedEventCountCallback: (() throws -> Void)? {
        get { synchronized { _incrementDroppedEventCountCallback } }
        set { synchronized { _incrementDroppedEventCountCallback = newValue } }
    }
    /// Every event counted, across all the calls.
    var droppedEventCount: Int {
        synchronized { _droppedEventCount }
    }
    func incrementDroppedEventCount(by count: Int) {
        let callback = synchronized { () -> (() throws -> Void)? in
            _incrementDroppedEventCountCallCount += 1
            _droppedEventCount += count
            return _incrementDroppedEventCountCallback
        }
        try! callback?()
    }

    var recordEventsInLastBatchCallCount: Int {
        get { synchronized { _recordEventsInLastBatchCallCount } }
        set { synchronized { _recordEventsInLastBatchCallCount = newValue } }
    }
    var recordEventsInLastBatchCallback: (() throws -> Void)? {
        get { synchronized { _recordEventsInLastBatchCallback } }
        set { synchronized { _recordEventsInLastBatchCallback = newValue } }
    }
    var recordEventsInLastBatchReceivedEventsInLastBatch: Int? {
        get { synchronized { _recordEventsInLastBatchReceivedEventsInLastBatch } }
        set { synchronized { _recordEventsInLastBatchReceivedEventsInLastBatch = newValue } }
    }
    func recordEventsInLastBatch(eventsInLastBatch: Int) {
        let callback = synchronized { () -> (() throws -> Void)? in
            _recordEventsInLastBatchCallCount += 1
            _recordEventsInLastBatchReceivedEventsInLastBatch = eventsInLastBatch
            return _recordEventsInLastBatchCallback
        }
        try! callback?()
    }

    var addStreamInitCallCount: Int {
        get { synchronized { _addStreamInitCallCount } }
        set { synchronized { _addStreamInitCallCount = newValue } }
    }
    var addStreamInitCallback: (() throws -> Void)? {
        get { synchronized { _addStreamInitCallback } }
        set { synchronized { _addStreamInitCallback = newValue } }
    }
    var addStreamInitReceivedStreamInit: DiagnosticStreamInit? {
        get { synchronized { _addStreamInitReceivedStreamInit } }
        set { synchronized { _addStreamInitReceivedStreamInit = newValue } }
    }
    func addStreamInit(streamInit: DiagnosticStreamInit) {
        let callback = synchronized { () -> (() throws -> Void)? in
            _addStreamInitCallCount += 1
            _addStreamInitReceivedStreamInit = streamInit
            return _addStreamInitCallback
        }
        try! callback?()
    }
}
