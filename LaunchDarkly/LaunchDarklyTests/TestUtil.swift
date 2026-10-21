import XCTest
import Foundation

@testable import LaunchDarkly

func symmetricAssertEqual<T: Equatable>(_ exp1: @autoclosure () throws -> T,
                                        _ exp2: @autoclosure () throws -> T,
                                        _ message: @autoclosure () -> String = "") {
    XCTAssertEqual(try exp1(), try exp2(), message())
    XCTAssertEqual(try exp2(), try exp1(), message())
}

func symmetricAssertNotEqual<T: Equatable>(_ exp1: @autoclosure () throws -> T,
                                           _ exp2: @autoclosure () throws -> T,
                                           _ message: @autoclosure () -> String = "") {
    XCTAssertNotEqual(try exp1(), try exp2(), message())
    XCTAssertNotEqual(try exp2(), try exp1(), message())
}

func encodeToLDValue<T: Encodable>(_ value: T, userInfo: [CodingUserInfoKey: Any] = [:]) -> LDValue? {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(date.millisSince1970)
    }
    encoder.userInfo = userInfo
    return try? JSONDecoder().decode(LDValue.self, from: encoder.encode(value))
}

func encodesToObject<T: Encodable>(_ value: T, userInfo: [CodingUserInfoKey: Any] = [:], asserts: ([String: LDValue]) -> Void) {
    valueIsObject(encodeToLDValue(value, userInfo: userInfo), asserts: asserts)
}

func valueIsObject(_ value: LDValue?, asserts: ([String: LDValue]) -> Void) {
    guard case .object(let dict) = value
    else {
        XCTFail("expected value to be object got \(String(describing: value))")
        return
    }
    asserts(dict)
}

func valueIsArray(_ value: LDValue?, asserts: ([LDValue]) -> Void) {
    guard case .array(let arr) = value
    else {
        XCTFail("expected value to be array got \(String(describing: value))")
        return
    }
    asserts(arr)
}

extension EventStore {
    /// A store in a directory of its own under the temporary directory, so that tests neither see each other's events
    /// nor leave any in the directory a real client would use.
    ///
    /// Unlocked, like every store from `sharing`.
    static func temporary(
        capacity: Int = 100,
        byteCapacity: Int = LDConfig.Defaults.eventCapacityBytes,
        persistEvents: Bool = true,
        readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
        writeLog: @escaping (EventLogFile, Data) -> Int32? = { $0.writeAll($1) }
    ) -> EventStore {
        let directory = temporaryDirectory()
        return unlocked(EventStore(directory: directory,
                                   capacity: capacity,
                                   byteCapacity: byteCapacity,
                                   persistEvents: persistEvents,
                                   logger: .disabled,
                                   readFile: readFile,
                                   writeLog: writeLog))
    }

    /// A directory of a test's own under the temporary directory.
    ///
    /// Handed in where the test has to look at the place a store would have written, which a store told to keep events
    /// off the disk will not tell it: that store has no directory at all.
    static func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    /// Another store on `directory`, standing in for another process: it shares the batches, and leaves alone the log a
    /// live store appends to. `nextRun` is the next run of the application.
    ///
    /// Unlocked on a Mac too, like every store from `temporary`; the locking itself has tests of its own.
    static func sharing(_ directory: URL,
                        byteCapacity: Int = LDConfig.Defaults.eventCapacityBytes,
                        persistEvents: Bool = true,
                        readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) }) -> EventStore {
        unlocked(EventStore(directory: directory,
                            capacity: 100,
                            byteCapacity: byteCapacity,
                            persistEvents: persistEvents,
                            logger: .disabled,
                            readFile: readFile))
    }

    private static func unlocked(_ store: EventStore) -> EventStore {
        #if os(macOS) || targetEnvironment(macCatalyst)
        store.locksOpenLog = false
        #endif
        return store
    }

    /// The next run of the application, had the process ended where it stands: a store on a copy of this one's
    /// directory, which holds what reached the disk and nothing that was still in memory. No live process holds the
    /// logs in the copy, as none would once the process was gone, so recovery takes them.
    func nextRun(readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) }) -> EventStore {
        let original = directory!
        let copy = original.deletingLastPathComponent()
            .appendingPathComponent("\(original.lastPathComponent)\(EventStore.nextRunSuffix)\(UUID().uuidString)",
                                    isDirectory: true)
        try? FileManager.default.copyItem(at: original, to: copy)
        return EventStore.sharing(copy, readFile: readFile)
    }

    private static let nextRunSuffix = "-next-run-"

    /// Every event in the store's directory, read straight from the files rather than through a store: the batches,
    /// then the logs still open. What the next run of the application would find there.
    var payloadsOnDisk: [Data] {
        let files = ((try? FileManager.default.contentsOfDirectory(atPath: directory!.path)) ?? []).sorted()
        let batches = files.filter { $0.hasPrefix("ready-") }
        let logs = files.filter { $0.hasPrefix(DiskEventLog.prefix) }
        var payloads: [Data] = []
        for name in batches + logs {
            guard let file = try? Data(contentsOf: directory!.appendingPathComponent(name))
            else { continue }
            _ = EventLogFormat.forEachFrame(in: file) { type, payload in
                if type == EventLogFormat.eventFrame {
                    payloads.append(payload)
                }
            }
        }
        return payloads
    }

    /// Removes the store's directory, including any batch still waiting to be delivered, and any copy `nextRun` made of
    /// it. A store told to keep events off the disk has no directory, and so nothing to remove.
    func deleteEverything() {
        guard let directory
        else { return }
        let parent = directory.deletingLastPathComponent()
        let copies = ((try? FileManager.default.contentsOfDirectory(atPath: parent.path)) ?? [])
            .filter { $0.hasPrefix(directory.lastPathComponent + EventStore.nextRunSuffix) }
        for copy in copies {
            try? FileManager.default.removeItem(at: parent.appendingPathComponent(copy))
        }
        try? FileManager.default.removeItem(at: directory)
    }
}
