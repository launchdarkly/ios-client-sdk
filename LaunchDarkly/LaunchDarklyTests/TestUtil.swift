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
        persistEvents: Bool = true,
        commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.tests.commitQueue"),
        readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
        writeLog: @escaping (EventLogFile, Data) -> Int32? = { $0.writeAll($1) }
    ) -> EventStore {
        let directory = temporaryDirectory()
        return unlocked(EventStore(directory: directory,
                                   capacity: capacity,
                                   persistEvents: persistEvents,
                                   logger: .disabled,
                                   commitQueue: commitQueue,
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

    /// Another store on `directory`, standing in for the next run of the application, or for another process.
    ///
    /// Unlocked on a Mac too. Tests open it while the first store is still alive, and a locked log would rightly be
    /// left to the live instance holding it; the locking itself has tests of its own.
    static func sharing(_ directory: URL,
                        persistEvents: Bool = true,
                        processName: String = ProcessInfo.processInfo.processName,
                        readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) }) -> EventStore {
        unlocked(EventStore(directory: directory,
                            capacity: 100,
                            persistEvents: persistEvents,
                            processName: processName,
                            logger: .disabled,
                            readFile: readFile))
    }

    private static func unlocked(_ store: EventStore) -> EventStore {
        #if os(macOS) || targetEnvironment(macCatalyst)
        store.locksOpenLog = false
        #endif
        return store
    }

    /// Removes the store's directory, including any batch still waiting to be delivered. A store told to keep events
    /// off the disk has no directory, and so nothing to remove.
    func deleteEverything() {
        guard let directory
        else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}
