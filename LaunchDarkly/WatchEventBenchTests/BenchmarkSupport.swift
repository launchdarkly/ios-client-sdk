import Foundation
import LDSwiftEventSource
@testable import LaunchDarkly_watchOS

extension EventStore {
    static func temporary(
        capacity: Int = 100,
        commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.tests.commitQueue")
    ) -> EventStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return EventStore(directory: directory, capacity: capacity, logger: .disabled, commitQueue: commitQueue)
    }

    func deleteEverything() {
        try? FileManager.default.removeItem(at: directory)
    }
}

#if canImport(SQLite3)
extension SQLiteEventStore {
    static func temporary(
        capacity: Int = 100,
        durability: SQLiteEventStore.Durability = .normal,
        commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.tests.commitQueue")
    ) -> SQLiteEventStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return SQLiteEventStore(
            directory: directory,
            capacity: capacity,
            durability: durability,
            logger: .disabled,
            commitQueue: commitQueue
        )
    }

    func deleteEverything() {
        try? FileManager.default.removeItem(at: directory)
    }
}
#endif

extension LDContext {
    static func stub(key: String? = nil) -> LDContext {
        var builder = LDContextBuilder(key: key ?? UUID().uuidString)
        builder.name("stub.context.name")
        builder.anonymous(false)
        builder.trySetValue("firstName", "stub.context.firstName")
        builder.trySetValue("lastName", "stub.context.lastName")
        builder.trySetValue("country", "stub.context.country")
        builder.trySetValue("ip", "stub.context.ipAddress")
        builder.trySetValue("email", "stub.context@email.com")
        builder.trySetValue("avatar", "stub.context.avatar")
        builder.trySetValue("stub.context.custom.keyA", "stub.context.custom.valueA")
        builder.trySetValue("stub.context.custom.keyB", true)
        builder.trySetValue("stub.context.custom.keyC", 1027)
        builder.trySetValue("stub.context.custom.keyD", 2.71828)
        builder.trySetValue("stub.context.custom.keyE", [0, 1, 2])
        builder.trySetValue("stub.context.custom.keyF", ["1": 1, "2": 2, "3": 3])
        return try! builder.build().get()
    }
}

extension LDConfig {
    static var stub: LDConfig {
        LDConfig(mobileKey: "mockMobileKey", autoEnvAttributes: .disabled, isDebugBuild: true)
    }
}

final class DarklyServiceMock: DarklyServiceProvider {
    var config: LDConfig
    var context: LDContext
    var diagnosticCache: DiagnosticCaching? { nil }

    init(config: LDConfig = .stub, context: LDContext = .stub()) {
        self.config = config
        self.context = context
    }

    func getFeatureFlags(useReport: Bool, completion: ServiceCompletionHandler?) {
        completion?((nil, nil, nil, nil))
    }

    func resetFlagResponseCache(etag: String?) {}

    func createEventSource(
        useReport: Bool,
        handler: EventHandler,
        errorHandler: ConnectionErrorHandler?
    ) -> DarklyStreamingProvider {
        fatalError("The event benchmark does not create an event source")
    }

    func publishEventData(_ eventData: Data, _ payloadId: String, completion: ServiceCompletionHandler?) {
        completion?((nil, nil, nil, nil))
    }

    func publishDiagnostic<T: DiagnosticEvent & Encodable>(
        diagnosticEvent: T,
        completion: ServiceCompletionHandler?
    ) {
        completion?((nil, nil, nil, nil))
    }
}
