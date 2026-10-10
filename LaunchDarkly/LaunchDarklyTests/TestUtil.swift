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
    /// Unlocked unless asked, whatever the platform. Tests stand in for the next run of the application with a second
    /// store while the first is still alive, and on a Mac a locked log would rightly be left to the live one.
    static func temporary(
        capacity: Int = 100,
        persistEvents: Bool = true,
        locksOpenLog: Bool = false,
        commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.tests.commitQueue"),
        readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
        writeLog: @escaping (Int32, Data) -> Int32? = EventStore.writeAll
    ) -> EventStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return EventStore(directory: directory,
                          capacity: capacity,
                          persistEvents: persistEvents,
                          locksOpenLog: locksOpenLog,
                          logger: .disabled,
                          commitQueue: commitQueue,
                          readFile: readFile,
                          writeLog: writeLog)
    }

    /// Removes the store's directory, including any batch still waiting to be delivered.
    func deleteEverything() {
        try? FileManager.default.removeItem(at: directory)
    }
}
