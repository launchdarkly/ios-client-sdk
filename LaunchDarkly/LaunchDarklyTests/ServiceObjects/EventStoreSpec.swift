import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class EventStoreSpec: QuickSpec {
    override func spec() {
        stagingSpec()
        recoverySpec()
        corruptionSpec()
        batchSpec()
        capacitySpec()
        byteCapacitySpec()
        batchSizeSpec()
        expirySpec()
        fallbackSpec()
        optOutSpec()
        multiProcessSpec()
        withoutPersistenceSpec()
        #if os(macOS) || targetEnvironment(macCatalyst)
        lockedInstancesSpec()
        #endif
    }

    #if os(macOS) || targetEnvironment(macCatalyst)
    private func lockedInstancesSpec() {
        // A Mac runs a second instance of an application over the same directory on request.
        describe("live instances holding their logs locked") {
            var first: EventStore!
            afterEach {
                first.deleteEverything()
            }

            func instance() -> EventStore {
                EventStore(directory: first.directory!, capacity: 100, logger: .disabled)
            }

            beforeEach {
                first = EventStore(directory: EventStore.temporary().directory!, capacity: 100, logger: .disabled)
            }

            it("gives each a log of its own, and leaves the first's alone") {
                _ = first.stage(EventStoreSpec.payload("first"))
                first.commit()

                let second = instance()
                second.preparePayloadsFromInterruptedLogs()
                expect(second.pendingBatches()).to(beEmpty())

                _ = second.stage(EventStoreSpec.payload("second"))
                second.commit()
                expect(second.openLogUrl!) != first.openLogUrl!

                _ = first.stage(EventStoreSpec.payload("first-again"))
                first.commit()
                let fromFirst = first.closeBatch()
                let fromSecond = second.closeBatch()
                expect(EventStoreSpec.keys(ofBody: fromFirst.flatMap { try? first.body(of: $0) })) == ["first", "first-again"]
                expect(EventStoreSpec.keys(ofBody: fromSecond.flatMap { try? second.body(of: $0) })) == ["second"]
            }

            it("leaves a log another process holds locked alone until the lock is let go") {
                var ended: EventStore? = instance()
                _ = ended?.stage(EventStoreSpec.payload("held"))
                ended?.commit()
                let log = ended!.openLogUrl!
                ended = nil
                // A descriptor of its own, as another live instance's would be, so nothing in this process knows of it.
                let held = EventLogFile.openLocked(log, flags: O_RDONLY)!

                first.preparePayloadsFromInterruptedLogs()
                expect(first.pendingBatches()).to(beEmpty())

                held.close()
                first.preparePayloadsFromInterruptedLogs()
                expect(EventStoreSpec.keys(ofBody: first.pendingBatches().first.flatMap { try? first.body(of: $0) })) == ["held"]
            }

            it("recovers the log an instance that has ended left open") {
                _ = first.stage(EventStoreSpec.payload("first"))
                first.commit()

                var ended: EventStore? = instance()
                _ = ended?.stage(EventStoreSpec.payload("from-the-ended-instance"))
                ended?.commit()
                // Going away closes its descriptor, which releases the lock, as the process dying would.
                ended = nil

                let next = instance()
                next.preparePayloadsFromInterruptedLogs()
                let batches = next.pendingBatches()
                expect(batches.count) == 1
                expect(EventStoreSpec.keys(ofBody: batches.first.flatMap { try? next.body(of: $0) })) == ["from-the-ended-instance"]
            }

            it("recovers the log a previous run left open, once nothing holds it") {
                _ = first.stage(EventStoreSpec.payload("left-open"))
                first.commit()
                let directory = first.directory!
                first = nil
                first = EventStore(directory: directory, capacity: 100, logger: .disabled)

                first.preparePayloadsFromInterruptedLogs()
                let batches = first.pendingBatches()
                expect(batches.count) == 1
                expect(EventStoreSpec.keys(ofBody: batches.first.flatMap { try? first.body(of: $0) })) == ["left-open"]
            }
        }
    }
    #endif

    private func multiProcessSpec() {
        describe("several processes sharing a directory") {
            var app: EventStore!
            afterEach {
                app.deleteEverything()
            }

            /// Another process of the same application, using the same directory. Unlocked, as on an iPhone or iPad,
            /// where the logs a live store has open are known without one.
            func otherProcess() -> EventStore {
                EventStore.sharing(app.directory!)
            }

            beforeEach {
                app = EventStore.sharing(EventStore.temporary().directory!)
            }

            it("leaves a log another process still has open where it is, so that process's later events reach it") {
                _ = app.stage(EventStoreSpec.payload("before"))
                app.commit()

                // Starting up, the other process recovers what no live process holds, and nothing else.
                let widget = otherProcess()
                widget.preparePayloadsFromInterruptedLogs()
                expect(widget.pendingBatches()).to(beEmpty())

                _ = app.stage(EventStoreSpec.payload("after"))
                app.commit()
                let batch = app.closeBatch()
                expect(batch?.eventCount) == 2
                expect(EventStoreSpec.keys(ofBody: batch.flatMap { try? app.body(of: $0) })) == ["before", "after"]
            }

            it("keeps each process's events in a log of its own") {
                let widget = otherProcess()
                _ = app.stage(EventStoreSpec.payload("from-app"))
                app.commit()
                _ = widget.stage(EventStoreSpec.payload("from-widget"))
                widget.commit()

                expect(app.openLogUrl!) != widget.openLogUrl!
                let fromApp = app.closeBatch()
                let fromWidget = widget.closeBatch()
                expect(EventStoreSpec.keys(ofBody: fromApp.flatMap { try? app.body(of: $0) })) == ["from-app"]
                expect(EventStoreSpec.keys(ofBody: fromWidget.flatMap { try? widget.body(of: $0) })) == ["from-widget"]
            }

            it("delivers a batch another process closed, since that process may never run again") {
                _ = app.stage(EventStoreSpec.payload("closed-by-app"))
                let closed = app.closeBatch()

                let widget = otherProcess()
                widget.preparePayloadsFromInterruptedLogs()
                expect(closed).toNot(beNil())
                expect(widget.pendingBatches().map(\.payloadId)) == [closed?.payloadId].compactMap { $0 }
            }

            it("recovers the log a process that has ended left open, whichever process it was") {
                var widget: EventStore? = otherProcess()
                _ = widget?.stage(EventStoreSpec.payload("left-open"))
                widget?.commit()
                // Going away closes its log, as the process ending would.
                widget = nil

                app.preparePayloadsFromInterruptedLogs()
                let batches = app.pendingBatches()
                expect(batches.count) == 1
                expect(EventStoreSpec.keys(ofBody: batches.first.flatMap { try? app.body(of: $0) })) == ["left-open"]
            }

            it("names a log for a UUID rather than for the process") {
                _ = app.stage(EventStoreSpec.payload("named"))
                app.commit()

                let logs = try FileManager.default.contentsOfDirectory(atPath: app.directory!.path)
                    .filter { $0.hasPrefix(DiskEventLog.prefix) }
                expect(logs.count) == 1
                expect(logs.first.flatMap { UUID(uuidString: String($0.dropFirst(DiskEventLog.prefix.count))) }).toNot(beNil())
                expect(try FileManager.default.contentsOfDirectory(atPath: app.directory!.path)
                    .filter { $0.hasPrefix(DiskEventLog.openingPrefix) }).to(beEmpty())
            }
        }
    }

    private func optOutSpec() {
        describe("a store the application did not ask to persist") {
            var store: EventStore!
            beforeEach {
                store = EventStore.temporary(persistEvents: false)
            }
            afterEach {
                store.deleteEverything()
            }

            it("writes nothing to the disk, so the directory is never even created") {
                // Given the directory rather than asked for it, because this store has none to give: it is told to
                // keep events off the disk, and so is built without anywhere to put them.
                let directory = EventStore.temporaryDirectory()
                let store = EventStore(directory: directory, capacity: 100, persistEvents: false, logger: .disabled)
                defer { try? FileManager.default.removeItem(at: directory) }

                _ = store.stage(EventStoreSpec.payload("held"))
                store.commit()

                expect(store.directory).to(beNil())
                expect(FileManager.default.fileExists(atPath: directory.path)) == false
                expect(EventStoreSpec.keys(of: EventStore.sharing(directory))).to(beEmpty())
            }

            it("delivers the events from memory, so opting out costs durability and nothing else") {
                _ = store.stage(EventStoreSpec.payload("held"))
                let batch = store.closeBatch()!

                expect(batch.eventCount) == 1
                expect(store.pendingEventCount) == 1
                expect(try store.body(of: batch)) == Data("[{\"kind\":\"custom\",\"key\":\"held\"}]".utf8)
            }

            it("asks the filesystem nothing, even about a batch it does not hold") {
                var reads = 0
                let directory = EventStore.temporaryDirectory()
                let store = EventStore(directory: directory,
                                       capacity: 100,
                                       persistEvents: false,
                                       logger: .disabled,
                                       readFile: { _ in
                                           reads += 1
                                           return Data()
                                       })
                defer { try? FileManager.default.removeItem(at: directory) }

                _ = store.stage(EventStoreSpec.payload("held"))
                let batch = store.closeBatch()
                expect(store.pendingBatches().map(\.payloadId)) == [batch?.payloadId]
                expect(EventStoreSpec.keys(ofBody: batch.flatMap { try? store.body(of: $0) })) == ["held"]
                batch.map(store.remove)

                // A batch this store never closed, which is what sends the paths that form a file URL down the branch
                // that would otherwise ask the filesystem about it.
                let stranger = EventBatch(payloadId: UUID().uuidString, eventCount: 1)
                expect(try store.body(of: stranger)).to(beNil())
                store.remove(stranger)

                expect(reads) == 0
                expect(store.directory).to(beNil())
                expect(FileManager.default.fileExists(atPath: directory.path)) == false
            }

            it("leaves alone what a run that did persist left behind, for the next run that persists") {
                let persisting = EventStore.temporary()
                defer { persisting.deleteEverything() }
                _ = persisting.stage(EventStoreSpec.payload("closed"))
                persisting.commit()
                expect(persisting.closeBatch()).toNot(beNil())
                _ = persisting.stage(EventStoreSpec.payload("open"))
                persisting.commit()

                let withoutPersistence = EventStore.sharing(persisting.directory!, persistEvents: false)
                withoutPersistence.preparePayloadsFromInterruptedLogs()
                expect(withoutPersistence.pendingBatches()).to(beEmpty())
                expect(withoutPersistence.pendingEventCount) == 0

                _ = withoutPersistence.stage(EventStoreSpec.payload("in-memory"))
                let own = withoutPersistence.closeBatch()
                expect(withoutPersistence.pendingBatches().map(\.payloadId)) == [own?.payloadId]

                let persistingAgain = persisting.nextRun()
                persistingAgain.preparePayloadsFromInterruptedLogs()
                let bodies = persistingAgain.pendingBatches().map { EventStoreSpec.keys(ofBody: try? persistingAgain.body(of: $0)) }
                expect(bodies) == [["closed"], ["open"]]
            }
        }
    }

    /// A store that can never write, because the directory it was given sits underneath a regular file and so cannot
    /// be created. Standing in for the full disk and the revoked permission, neither of which a test can arrange.
    private static func unwritableStore(capacity: Int = 100) -> EventStore {
        let blocker = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: blocker.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: blocker.path, contents: Data("not a directory".utf8))

        return EventStore(directory: blocker.appendingPathComponent("store", isDirectory: true),
                          capacity: capacity,
                          logger: .disabled)
    }

    /// A store reading the same directory as another, standing in for another process: it sees the batches, and leaves
    /// alone the log the live store appends to. `nextRun()` stands in for the next run of the application.
    private static func reader(sharing store: EventStore,
                               readFile: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) }) -> EventStore {
        EventStore.sharing(store.directory!, readFile: readFile)
    }

    /// The one `ready-` file in a store's directory.
    private static func onlyBatchFile(in store: EventStore) throws -> URL {
        try FileManager.default
            .contentsOfDirectory(at: store.directory!, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("ready-") }!
    }

    /// Renames a batch to the name a version that did not count them in the name gave it, which is what such a
    /// version leaves behind for this one to deliver.
    @discardableResult
    private static func asUncountedName(_ batch: URL) throws -> URL {
        let name = batch.lastPathComponent
        let renamed = batch.deletingLastPathComponent()
            .appendingPathComponent(String(name[..<name.lastIndex(of: "-")!]))
        try FileManager.default.moveItem(at: batch, to: renamed)
        return renamed
    }

    /// What a process out of file descriptors gets for a file that is perfectly intact.
    private static func readFailing(while failing: @escaping () -> Bool) -> (URL) throws -> Data {
        { url in
            guard !failing()
            else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(EMFILE)) }
            return try Data(contentsOf: url)
        }
    }

    /// Puts a read-only open of the same file behind the log's descriptor, so that cutting it back fails while the file
    /// itself can still be renamed or removed.
    private static func refuseTruncating(_ file: EventLogFile) {
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard fcntl(file.descriptor, F_GETPATH, &path) == 0
        else { return fail("could not find the log's path") }
        let readOnly = open(path, O_RDONLY)
        guard readOnly >= 0
        else { return fail("could not reopen the log") }
        _ = dup2(readOnly, file.descriptor)
        _ = close(readOnly)
    }

    private static func payload(_ key: String) -> Data {
        Data("{\"kind\":\"custom\",\"key\":\"\(key)\"}".utf8)
    }

    /// Where each frame of a log written by this version starts.
    private static func frameOffsets(in log: Data) -> [Int] {
        var offsets: [Int] = []
        var cursor = EventLogFormat.fileHeaderSize
        while cursor + EventLogFormat.frameHeaderSize <= log.count {
            offsets.append(cursor)
            cursor += EventLogFormat.frameHeaderSize + Int(EventLogFormat.readUInt32(log, at: cursor + 2))
        }
        return offsets
    }

    /// An event whose frame is exactly `frameBytes` long, padded out in a `data` field.
    private static func payload(framedIn frameBytes: Int, key: String) -> Data {
        let bare = "{\"kind\":\"custom\",\"key\":\"\(key)\",\"data\":\"\"}"
        let padding = frameBytes - EventLogFormat.frameHeaderSize - bare.utf8.count
        precondition(padding >= 0, "\(key) does not fit in \(frameBytes) bytes")
        return Data("{\"kind\":\"custom\",\"key\":\"\(key)\",\"data\":\"\(String(repeating: "x", count: padding))\"}".utf8)
    }

    private static func keys(of store: EventStore) -> [String] {
        keys(in: store.pendingEventPayloads())
    }

    private static func keys(in payloads: [Data]) -> [String] {
        payloads.compactMap {
            guard case .object(let fields) = try? JSONDecoder().decode(LDValue.self, from: $0),
                  case .string(let key) = fields["key"]
            else { return nil }
            return key
        }
    }

    private func stagingSpec() {
        describe("staging") {
            var store: EventStore!
            beforeEach {
                store = EventStore.temporary()
            }
            afterEach {
                store.deleteEverything()
            }

            it("keeps a staged event out of the log until it is committed") {
                _ = store.stage(EventStoreSpec.payload("staged-only"))

                expect(EventStoreSpec.keys(in: store.payloadsOnDisk)).to(beEmpty())
                expect(store.pendingEventCount) == 1
            }

            it("puts a committed event where another process would find it") {
                _ = store.stage(EventStoreSpec.payload("committed"))
                store.commit()

                expect(EventStoreSpec.keys(in: store.payloadsOnDisk)) == ["committed"]
            }

            it("never writes on its own, however much is staged") {
                // When to write is the caller's decision. 64 KB is well past what a store that wrote on its own would
                // let build up.
                let event = EventStoreSpec.payload(String(repeating: "p", count: 1_024))
                for _ in 0..<64 {
                    _ = store.stage(event)
                }

                expect(store.payloadsOnDisk).to(beEmpty())
                expect(store.pendingEventCount) == 64

                store.commit()

                expect(store.payloadsOnDisk.count) == 64
            }

            it("keeps events in the order they were recorded") {
                for index in 0..<5 {
                    _ = store.stage(EventStoreSpec.payload("event-\(index)"))
                }
                store.commit()

                expect(EventStoreSpec.keys(in: store.payloadsOnDisk)) == ["event-0", "event-1", "event-2", "event-3", "event-4"]
            }
        }
    }

    private func recoverySpec() {
        describe("recovering a log a previous run left open") {
            var store: EventStore!
            afterEach {
                store.deleteEverything()
            }

            it("delivers the events as a batch") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("survived"))
                store.commit()

                // Nothing closed the log, as nothing would if the process had died here.
                let next = store.nextRun()
                next.preparePayloadsFromInterruptedLogs()

                let batches = next.pendingBatches()
                expect(batches.count) == 1
                expect(batches.first?.eventCount) == 1
                expect(try next.body(of: batches[0])) == Data("[{\"kind\":\"custom\",\"key\":\"survived\"}]".utf8)
            }

            it("leaves nothing behind when the log held no events") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("only"))
                store.commit()
                let batch = store.closeBatch()
                store.remove(batch!)

                let next = store.nextRun()
                next.preparePayloadsFromInterruptedLogs()

                expect(next.pendingBatches()).to(beEmpty())
                expect(next.pendingEventCount) == 0
            }

            it("keeps this run's events out of it, even when this run commits before recovery is asked for") {
                store = EventStore.temporary()
                for index in 0..<2 {
                    _ = store.stage(EventStoreSpec.payload("previous-\(index)"))
                }
                store.commit()
                // The previous run died partway through writing its last frame.
                let log = store.openLogUrl!
                try Data(contentsOf: log).dropLast(3).write(to: log)

                let next = store.nextRun()
                _ = next.stage(EventStoreSpec.payload("this-run"))
                next.commit()
                next.preparePayloadsFromInterruptedLogs()
                _ = next.stage(EventStoreSpec.payload("later"))
                next.commit()
                _ = next.closeBatch()

                let bodies = next.pendingBatches().map { EventStoreSpec.keys(ofBody: try? next.body(of: $0)) }
                expect(bodies) == [["previous-0"], ["this-run", "later"]]
                expect(next.pendingEventCount) == 3
            }

            it("reads the log without holding up a commit") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("from-the-previous-run"))
                store.commit()

                let reading = DispatchSemaphore(value: 0)
                let release = DispatchSemaphore(value: 0)
                let next = store.nextRun(readFile: { url in
                    if url.lastPathComponent.hasPrefix(DiskEventLog.prefix) {
                        reading.signal()
                        _ = release.wait(timeout: .now() + 5)
                    }
                    return try Data(contentsOf: url)
                })
                let recovered = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    next.preparePayloadsFromInterruptedLogs()
                    recovered.signal()
                }
                expect(reading.wait(timeout: .now() + 5)) == .success

                // Recovery is partway through reading the log, which a commit does not wait for.
                let committed = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    _ = next.stage(EventStoreSpec.payload("this-run"))
                    next.commit()
                    committed.signal()
                }
                expect(committed.wait(timeout: .now() + 2)) == .success
                release.signal()
                expect(recovered.wait(timeout: .now() + 5)) == .success

                expect(next.pendingEventCount) == 2
                let batches = next.pendingBatches()
                expect(batches.count) == 1
                expect(EventStoreSpec.keys(ofBody: try next.body(of: batches[0]))) == ["from-the-previous-run"]
                expect(EventStoreSpec.keys(in: next.payloadsOnDisk)) == ["from-the-previous-run", "this-run"]
            }
        }
    }

    private static func keys(ofBody body: Data?) -> [String] {
        guard let body, case .array(let events)? = try? JSONDecoder().decode(LDValue.self, from: body)
        else { return [] }
        return events.compactMap {
            guard case .object(let fields) = $0, case .string(let key) = fields["key"]
            else { return nil }
            return key
        }
    }

    private func corruptionSpec() {
        describe("a damaged log") {
            var store: EventStore!
            afterEach {
                store.deleteEverything()
            }

            it("keeps every event before a frame the writer did not finish") {
                store = EventStore.temporary()
                for index in 0..<3 {
                    _ = store.stage(EventStoreSpec.payload("event-\(index)"))
                }
                store.commit()

                // A process killed partway through a write leaves the last frame short of its declared length.
                let log = store.openLogUrl!
                let whole = try Data(contentsOf: log)
                try whole.dropLast(8).write(to: log)

                expect(EventStoreSpec.keys(in: store.payloadsOnDisk)) == ["event-0", "event-1"]
            }

            context("where the storage changed a frame after it was written") {
                var log: URL!
                var second: Int!
                beforeEach {
                    store = EventStore.temporary()
                    for index in 0..<3 {
                        _ = store.stage(EventStoreSpec.payload("event-\(index)"))
                    }
                    store.commit()
                    log = store.openLogUrl!
                    second = EventStoreSpec.frameOffsets(in: try! Data(contentsOf: log))[1]
                }

                it("keeps every event before a payload with a flipped bit") {
                    var damaged = try Data(contentsOf: log)
                    damaged[second + EventLogFormat.frameHeaderSize + 3] ^= 0x04
                    try damaged.write(to: log)

                    expect(EventStoreSpec.keys(in: store.payloadsOnDisk)) == ["event-0"]
                }

                it("keeps every event before a zero-filled payload") {
                    var damaged = try Data(contentsOf: log)
                    let start = second + EventLogFormat.frameHeaderSize
                    let size = Int(EventLogFormat.readUInt32(damaged, at: second + 2))
                    damaged.replaceSubrange(start..<(start + size), with: Data(count: size))
                    try damaged.write(to: log)

                    expect(EventStoreSpec.keys(in: store.payloadsOnDisk)) == ["event-0"]
                }

                it("keeps every event before a size that still fits in the file") {
                    // A size that is merely wrong rather than impossible passes every bound a torn tail is caught by,
                    // and would have the reader start the next frame partway through this one's payload.
                    var damaged = try Data(contentsOf: log)
                    damaged[second + 5] -= 1
                    try damaged.write(to: log)

                    expect(EventStoreSpec.keys(in: store.payloadsOnDisk)) == ["event-0"]
                }
            }

            it("loses a batch whose first frame is damaged, rather than taking it for one with nothing to send") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("damaged"))
                let batch = store.closeBatch()!
                let file = try EventStoreSpec.onlyBatchFile(in: store)
                var damaged = try Data(contentsOf: file)
                damaged[EventLogFormat.fileHeaderSize + EventLogFormat.frameHeaderSize] ^= 0x01
                try damaged.write(to: file)

                expect { try store.body(of: batch) }.to(throwError(errorType: UnreadableBatch.self))
            }

            it("says how many events made it into the body of a batch damaged after its first frame") {
                store = EventStore.temporary()
                ["first", "second", "third"].forEach { _ = store.stage(EventStoreSpec.payload($0)) }
                let batch = store.closeBatch()!
                let file = try EventStoreSpec.onlyBatchFile(in: store)
                var damaged = try Data(contentsOf: file)
                damaged[damaged.count - 1] ^= 0x01
                try damaged.write(to: file)

                let payload = try store.payload(of: batch)
                expect(batch.eventCount) == 3
                expect(payload?.eventCount) == 2
                expect(EventStoreSpec.keys(ofBody: payload?.body)) == ["first", "second"]
            }

            it("sends no frames a failed write left behind where it could not be cut back") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("written"))
                let batch = store.closeBatch()!
                let file = try EventStoreSpec.onlyBatchFile(in: store)
                // Whole frames past the one the batch was closed holding, which memory delivers instead.
                var leftBehind = try Data(contentsOf: file)
                leftBehind.append(EventLogFormat.frame(for: EventStoreSpec.payload("from-memory")))
                try leftBehind.write(to: file)

                expect(EventStoreSpec.keys(ofBody: try? store.body(of: batch))) == ["written"]
                let next = store.nextRun()
                let listed = next.pendingBatches()
                expect(listed.map { $0.eventCount }) == [1]
                expect(EventStoreSpec.keys(ofBody: listed.first.flatMap { try? next.body(of: $0) })) == ["written"]
            }

            it("is kept for a later listing when a batch named without a count cannot be read") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("kept"))
                store.commit()
                _ = store.closeBatch()
                try EventStoreSpec.asUncountedName(EventStoreSpec.onlyBatchFile(in: store))

                var failing = true
                let next = EventStoreSpec.reader(sharing: store,
                                                 readFile: EventStoreSpec.readFailing(while: { failing }))
                expect(next.pendingBatches()).to(beEmpty())

                // A read can fail on an intact file, as it does in a process out of file descriptors, so the batch has
                // to still be there once reads work again.
                failing = false
                let batches = next.pendingBatches()
                expect(batches.count) == 1
                expect(EventStoreSpec.keys(ofBody: try next.body(of: batches[0]))) == ["kept"]
            }

            it("is listed even while reads are failing when its name counts it") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("kept"))
                _ = store.closeBatch()

                // The read a listing used to need is the one a process out of file descriptors cannot make. With the
                // count in the name there is nothing to read until the batch is sent, and a body that cannot be read
                // is a delivery to retry rather than a batch that is invisible until it can be.
                let next = EventStoreSpec.reader(sharing: store,
                                                 readFile: EventStoreSpec.readFailing(while: { true }))
                let batches = next.pendingBatches()
                expect(batches.count) == 1
                expect(batches[0].eventCount) == 1
                expect { try next.body(of: batches[0]) }.to(throwError())
            }

            it("is a failure to retry, not nothing to send, when a body cannot be read") {
                var failing = false
                store = EventStore.temporary(readFile: EventStoreSpec.readFailing(while: { failing }))
                _ = store.stage(EventStoreSpec.payload("kept"))
                let batch = store.closeBatch()!

                failing = true
                expect { try store.body(of: batch) }.to(throwError())
                // Still the store's to deliver: reporting nothing to send would have it dropped.
                expect(store.pendingBatches()) == [batch]

                failing = false
                expect(EventStoreSpec.keys(ofBody: try store.body(of: batch))) == ["kept"]
            }

            it("is closed off uncounted when a log a previous run left open cannot be read") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("from-the-previous-run"))
                store.commit()

                var failing = true
                let next = store.nextRun(readFile: EventStoreSpec.readFailing(while: { failing }))
                let leftOpen = next.directory!.appendingPathComponent(store.openLogUrl!.lastPathComponent)
                next.preparePayloadsFromInterruptedLogs()
                // Moved out from under the name recovery looks for, and not deleted.
                expect(FileManager.default.fileExists(atPath: leftOpen.path)) == false

                // The events that are intact are only waiting for a read that works to be counted and delivered.
                _ = next.stage(EventStoreSpec.payload("this-run"))
                next.commit()
                failing = false
                let batches = next.pendingBatches()
                expect(batches.count) == 1
                expect(EventStoreSpec.keys(ofBody: try next.body(of: batches[0]))) == ["from-the-previous-run"]
                expect(EventStoreSpec.keys(in: next.payloadsOnDisk)) == ["from-the-previous-run", "this-run"]
            }

            it("is discarded when a batch named without a count is in a format this version does not read") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("unreadable"))
                store.commit()
                _ = store.closeBatch()

                let batchUrl = try EventStoreSpec.asUncountedName(EventStoreSpec.onlyBatchFile(in: store))
                var corrupted = try Data(contentsOf: batchUrl)
                corrupted[4] = 0xFF
                corrupted[5] = 0xFF
                try corrupted.write(to: batchUrl)

                let next = EventStoreSpec.reader(sharing: store)
                expect(next.pendingBatches()).to(beEmpty())
                // A batch that can never be delivered is not left to occupy the device either.
                expect(FileManager.default.fileExists(atPath: batchUrl.path)) == false
            }
        }
    }

    private func batchSpec() {
        describe("batches") {
            var store: EventStore!
            beforeEach {
                store = EventStore.temporary()
            }
            afterEach {
                store.deleteEverything()
            }

            it("assembles the events into one request body") {
                _ = store.stage(EventStoreSpec.payload("first"))
                _ = store.stage(EventStoreSpec.payload("second"))

                let batch = store.closeBatch()
                expect(batch?.eventCount) == 2

                let body = try store.body(of: batch!)
                expect(body) == Data("[{\"kind\":\"custom\",\"key\":\"first\"},{\"kind\":\"custom\",\"key\":\"second\"}]".utf8)
            }

            it("assembles one event, and events held in memory, into the same body") {
                _ = store.stage(EventStoreSpec.payload("only"))
                expect(try store.body(of: store.closeBatch()!)) == Data("[{\"kind\":\"custom\",\"key\":\"only\"}]".utf8)

                let inMemory = EventStore.temporary(persistEvents: false)
                defer { inMemory.deleteEverything() }
                _ = inMemory.stage(EventStoreSpec.payload("first"))
                _ = inMemory.stage(EventStoreSpec.payload("second"))
                expect(try inMemory.body(of: inMemory.closeBatch()!))
                    == Data("[{\"kind\":\"custom\",\"key\":\"first\"},{\"kind\":\"custom\",\"key\":\"second\"}]".utf8)
            }

            it("frames an event as the Android SDK does") {
                // The checksum is zlib's CRC-32, so these bytes are what the Android SDK writes for the same event too.
                let frame = EventLogFormat.frame(for: Data("{\"kind\":\"custom\",\"key\":\"k\"}".utf8))
                expect(frame.prefix(EventLogFormat.frameHeaderSize)) == Data([0x00, 0x01, 0x00, 0x00, 0x00, 0x1B, 0xCB, 0x2B, 0x5E, 0x6F])
            }

            it("has nothing to close when nothing was recorded") {
                expect(store.closeBatch()).to(beNil())
            }

            it("holds a batch until it is removed, so a failed delivery can be retried") {
                _ = store.stage(EventStoreSpec.payload("retry-me"))
                let batch = store.closeBatch()!

                expect(store.pendingBatches()) == [batch]
                expect(store.pendingEventCount) == 1
                expect(try store.body(of: batch)).toNot(beNil())

                store.remove(batch)

                expect(store.pendingBatches()).to(beEmpty())
                expect(store.pendingEventCount) == 0
            }

            it("counts a closed batch from its name without reading the file back") {
                _ = store.stage(EventStoreSpec.payload("first"))
                _ = store.stage(EventStoreSpec.payload("second"))
                let batch = store.closeBatch()!

                // Nothing appends to a batch once it is closed, so the count its name carries still holds and
                // listing it has no reason to go to the disk. Damaging the file is how the test tells the two apart:
                // a listing that read would refuse this batch.
                let batchUrl = store.directory!.appendingPathComponent("ready-\(batch.payloadId).2")
                try Data("not an event log".utf8).write(to: batchUrl)

                // The store that closed it and one that did not both count it from the name alone.
                expect(store.pendingBatches()) == [batch]
                expect(EventStoreSpec.reader(sharing: store).pendingBatches()) == [batch]

                // The damage is found where the batch is read to be sent, and reads as a loss rather than as a failure
                // to retry, so the delivery removes it instead of trying it forever, and says it lost events.
                expect { try store.body(of: batch) }.to(throwError(errorType: UnreadableBatch.self))
            }

            it("reads a batch named without a count once and then remembers it") {
                _ = store.stage(EventStoreSpec.payload("left-by-a-previous-version"))
                let batch = store.closeBatch()!

                // A name without a count, which is what a recovery that could not read a log leaves behind for a
                // listing to count.
                let counted = store.directory!.appendingPathComponent("ready-\(batch.payloadId).1")
                let uncounted = store.directory!.appendingPathComponent("ready-\(batch.payloadId)")
                try FileManager.default.moveItem(at: counted, to: uncounted)

                let reader = EventStoreSpec.reader(sharing: store)
                expect(reader.pendingBatches()) == [batch]
                // Still deliverable under the name it has, which is not the one its count would give it.
                expect(try reader.body(of: batch)).toNot(beNil())
                reader.remove(batch)
                expect(FileManager.default.fileExists(atPath: uncounted.path)) == false
            }

            it("does not take a payload id ending in zero-led digits for a count") {
                _ = store.stage(EventStoreSpec.payload("left-by-a-previous-version"))
                let batch = store.closeBatch()!

                // Its last group fits an Int32 once the leading zeros are dropped.
                let payloadId = "6F9619FF-8B86-D011-B42D-000012345678"
                let counted = store.directory!.appendingPathComponent("ready-\(batch.payloadId).1")
                let uncounted = store.directory!.appendingPathComponent("ready-\(payloadId)")
                try FileManager.default.moveItem(at: counted, to: uncounted)

                expect(EventStoreSpec.reader(sharing: store).pendingBatches()) == [EventBatch(payloadId: payloadId, eventCount: 1)]
            }

            it("reads a name with a field after the count by position") {
                _ = store.stage(EventStoreSpec.payload("first"))
                _ = store.stage(EventStoreSpec.payload("second"))
                let batch = store.closeBatch()!

                // What a later version might add, which this one has no use for.
                let counted = store.directory!.appendingPathComponent("ready-\(batch.payloadId).2")
                let extended = store.directory!.appendingPathComponent("ready-\(batch.payloadId).2.v2-something")
                try FileManager.default.moveItem(at: counted, to: extended)

                expect(EventStoreSpec.reader(sharing: store).pendingBatches()) == [batch]
            }

            it("counts a batch whose count does not parse by reading it") {
                _ = store.stage(EventStoreSpec.payload("only"))
                let batch = store.closeBatch()!

                let counted = store.directory!.appendingPathComponent("ready-\(batch.payloadId).1")
                let unparseable = store.directory!.appendingPathComponent("ready-\(batch.payloadId).not-a-count")
                try FileManager.default.moveItem(at: counted, to: unparseable)

                expect(EventStoreSpec.reader(sharing: store).pendingBatches()) == [batch]
            }

            it("gives a batch its own payload id, so a retry is not read as a new delivery") {
                _ = store.stage(EventStoreSpec.payload("first"))
                let first = store.closeBatch()!
                _ = store.stage(EventStoreSpec.payload("second"))
                let second = store.closeBatch()!

                expect(first.payloadId).toNot(equal(second.payloadId))
            }

            it("keeps recording into a fresh log after one is closed") {
                _ = store.stage(EventStoreSpec.payload("before"))
                _ = store.closeBatch()
                _ = store.stage(EventStoreSpec.payload("after"))
                store.commit()

                expect(EventStoreSpec.keys(of: store)) == ["before", "after"]
                expect(store.pendingEventCount) == 2
            }

            it("treats a batch something else already removed as nothing to send, and removing it again as harmless") {
                _ = store.stage(EventStoreSpec.payload("delivered"))
                let batch = store.closeBatch()!
                _ = store.stage(EventStoreSpec.payload("still-pending"))
                let other = store.closeBatch()!

                // Delivered through a store reading the same directory, as the next run would.
                EventStoreSpec.reader(sharing: store).remove(batch)

                // Nothing, which a delivery takes as already delivered rather than as a failure to retry.
                expect(try store.body(of: batch)).to(beNil())
                store.remove(batch)

                expect(store.pendingBatches()) == [other]
                expect(store.pendingEventCount) == 1
            }

            it("keeps every batch it counted when the directory cannot be listed, and says the listing is incomplete") {
                _ = store.stage(EventStoreSpec.payload("first"))
                let first = store.closeBatch()!
                _ = store.stage(EventStoreSpec.payload("second"))
                let second = store.closeBatch()!
                _ = store.pendingBatches()

                let directory = store.directory!
                // Writable and searchable but not readable: its files can be created, renamed and read by name, and
                // the directory cannot be listed.
                let unlistable: [FileAttributeKey: Any] = [.posixPermissions: 0o300]
                let listable: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
                try FileManager.default.setAttributes(unlistable, ofItemAtPath: directory.path)
                defer { try? FileManager.default.setAttributes(listable, ofItemAtPath: directory.path) }

                _ = store.stage(EventStoreSpec.payload("third"))
                let third = store.closeBatch()!

                // Not empty: the batch just closed is still there to send, and nothing stops counting.
                let listing = store.listPendingBatches()
                expect(listing.isComplete) == false
                expect(listing.batches) == [first, second, third]
                expect(store.pendingEventCount) == 3
                expect(EventStoreSpec.keys(ofBody: try? store.body(of: third))) == ["third"]

                try FileManager.default.setAttributes(listable, ofItemAtPath: directory.path)
                expect(store.listPendingBatches()) == BatchListing(batches: [first, second, third], isComplete: true)
            }

            it("keeps a log it could not close open, and closes all of it the next time") {
                _ = store.stage(EventStoreSpec.payload("first"))
                store.commit()

                let directory = store.directory!
                // A directory with no write permission is one nothing in it can be renamed in.
                let readOnly: [FileAttributeKey: Any] = [.posixPermissions: 0o555]
                let writable: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
                try FileManager.default.setAttributes(readOnly, ofItemAtPath: directory.path)
                defer { try? FileManager.default.setAttributes(writable, ofItemAtPath: directory.path) }

                expect(store.closeBatch()).to(beNil())
                expect(store.holdsUnclosedEvents) == true
                expect(store.pendingEventCount) == 1

                try FileManager.default.setAttributes(writable, ofItemAtPath: directory.path)
                _ = store.stage(EventStoreSpec.payload("second"))
                store.commit()

                // One batch holding both, named for what it holds, and no log left behind for a later launch.
                let batch = store.closeBatch()!
                expect(batch.eventCount) == 2
                expect(EventStoreSpec.keys(ofBody: try? store.body(of: batch))) == ["first", "second"]
                expect(store.holdsUnclosedEvents) == false
                expect(store.pendingBatches()) == [batch]
                let logs = try FileManager.default.contentsOfDirectory(atPath: directory.path)
                    .filter { $0.hasPrefix(DiskEventLog.prefix) }
                expect(logs).to(beEmpty())
            }
        }
    }

    private func withoutPersistenceSpec() {
        describe("finding its directory") {
            for persistEvents in [false, true] {
                it(persistEvents ? "works out where its directory is once, when it first reaches for the disk"
                                 : "never works out where its directory is") {
                    let lock = UnfairLock()
                    var located = 0
                    let directory = FileManager.default.temporaryDirectory
                        .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
                        .appendingPathComponent(UUID().uuidString, isDirectory: true)
                    let store = EventStore(locatingDirectory: { lock.withLock { located += 1 }; return directory },
                                           capacity: 100,
                                           persistEvents: persistEvents,
                                           logger: .disabled)
                    defer { try? FileManager.default.removeItem(at: directory) }
                    expect(lock.withLock { located }) == 0
                    #if os(macOS) || targetEnvironment(macCatalyst)
                    if persistEvents {
                        store.locksOpenLog = false
                    }
                    #endif

                    store.preparePayloadsFromInterruptedLogs()
                    _ = store.stage(EventStoreSpec.payload("first"))
                    store.commit()
                    let batch = store.closeBatch()!
                    _ = store.stage(EventStoreSpec.payload("second"))
                    expect(store.pendingBatches().map(\.payloadId)) == [batch.payloadId]
                    expect(EventStoreSpec.keys(ofBody: try store.body(of: batch))) == ["first"]
                    store.startedSending(batch)
                    store.stoppedSending(batch)
                    store.remove(batch)
                    expect(store.pendingEventPayloads().count) == 1
                    expect(store.pendingEventCount) == 1

                    expect(lock.withLock { located }) == (persistEvents ? 1 : 0)
                }
            }
        }

        describe("the store without persistence") {
            it("lists its batches oldest first, as the store with a disk does") {
                let store = EventStore.temporary(persistEvents: false)
                var closed: [String] = []
                // Enough that hash order coming out right by chance is not a worry.
                for index in 0..<20 {
                    _ = store.stage(EventStoreSpec.payload("event-\(index)"), bypassingCapacity: false)
                    if let batch = store.closeBatch() {
                        closed.append(batch.payloadId)
                    }
                }

                expect(store.pendingBatches().map(\.payloadId)) == closed

                store.remove(EventBatch(payloadId: closed[3], eventCount: 1))
                closed.remove(at: 3)
                expect(store.pendingBatches().map(\.payloadId)) == closed
                expect(EventStoreSpec.keys(ofBody: try store.body(of: EventBatch(payloadId: closed[3], eventCount: 1)))) == ["event-4"]
            }
        }
    }

    private func capacitySpec() {
        describe("capacity") {
            var store: EventStore!
            afterEach {
                store.deleteEverything()
            }

            it("refuses events once it is reached") {
                store = EventStore.temporary(capacity: 2)

                expect(store.stage(EventStoreSpec.payload("first"))) == true
                expect(store.stage(EventStoreSpec.payload("second"))) == true
                expect(store.stage(EventStoreSpec.payload("third"))) == false
                expect(store.pendingEventCount) == 2
            }

            it("counts the events in a batch that has not been delivered yet") {
                store = EventStore.temporary(capacity: 1)

                expect(store.stage(EventStoreSpec.payload("first"))) == true
                _ = store.closeBatch()

                expect(store.stage(EventStoreSpec.payload("second"))) == false
            }

            it("does not count a batch while its request is out, and counts it again if the send is to be retried") {
                store = EventStore.temporary(capacity: 1)
                expect(store.stage(EventStoreSpec.payload("first"))) == true
                let batch = store.closeBatch()!

                store.startedSending(batch)
                expect(store.pendingEventCount) == 0
                expect(store.stage(EventStoreSpec.payload("while-sending"))) == true

                store.stoppedSending(batch)
                expect(store.pendingEventCount) == 2
                expect(store.stage(EventStoreSpec.payload("after-retryable"))) == false
            }

            it("takes a sent batch out of the count only once when it is delivered") {
                store = EventStore.temporary(capacity: 2)
                expect(store.stage(EventStoreSpec.payload("first"))) == true
                let batch = store.closeBatch()!
                expect(store.stage(EventStoreSpec.payload("second"))) == true

                store.startedSending(batch)
                store.remove(batch)
                expect(store.pendingEventCount) == 1
                store.stoppedSending(batch)
                expect(store.pendingEventCount) == 1
                _ = store.pendingBatches()
                expect(store.pendingEventCount) == 1
            }

            it("does the same without persistence") {
                store = EventStore.temporary(capacity: 1, persistEvents: false)
                expect(store.stage(EventStoreSpec.payload("first"))) == true
                let batch = store.closeBatch()!

                store.startedSending(batch)
                expect(store.pendingEventCount) == 0
                expect(store.stage(EventStoreSpec.payload("while-sending"))) == true
                store.stoppedSending(batch)
                expect(store.pendingEventCount) == 2
                expect(store.stage(EventStoreSpec.payload("after-retryable"))) == false
                store.startedSending(batch)
                store.remove(batch)
                expect(store.pendingEventCount) == 1
                store.stoppedSending(batch)
                expect(store.pendingEventCount) == 1
            }

            // As when another process delivered it and a listing dropped it before this one got to it: leaving it out
            // would take its events from the batches still counted, and admit that many more.
            for persistEvents in [true, false] {
                it("does not leave a batch already removed out of the count when its send starts, persisting: \(persistEvents)") {
                    store = EventStore.temporary(capacity: 2, persistEvents: persistEvents)
                    expect(store.stage(EventStoreSpec.payload("first"))) == true
                    let removed = store.closeBatch()!
                    expect(store.stage(EventStoreSpec.payload("second"))) == true
                    _ = store.closeBatch()
                    store.remove(removed)

                    store.startedSending(removed)
                    expect(store.pendingEventCount) == 1
                    expect(store.stage(EventStoreSpec.payload("third"))) == true
                    expect(store.stage(EventStoreSpec.payload("fourth"))) == false

                    store.stoppedSending(removed)
                    expect(store.pendingEventCount) == 2
                }
            }

            it("does not leave a batch another process delivered out of the count when its send starts") {
                store = EventStore.temporary(capacity: 2)
                expect(store.stage(EventStoreSpec.payload("first"))) == true
                let delivered = store.closeBatch()!
                expect(store.stage(EventStoreSpec.payload("second"))) == true
                _ = store.closeBatch()
                let other = EventStore.sharing(store.directory!)
                _ = other.pendingBatches()
                other.remove(delivered)
                _ = store.pendingBatches()

                store.startedSending(delivered)
                expect(store.pendingEventCount) == 1
                expect(store.stage(EventStoreSpec.payload("third"))) == true
                expect(store.stage(EventStoreSpec.payload("fourth"))) == false
            }

            // The bound `LDConfig.eventCapacity` documents: the reporter reads the disk in the background after starting,
            // so what an earlier run left only counts from that listing on.
            it("counts what an earlier run left undelivered from the first listing on") {
                let earlier = EventStore.temporary(capacity: 2)
                defer { earlier.deleteEverything() }
                _ = earlier.stage(EventStoreSpec.payload("earlier-1"))
                _ = earlier.stage(EventStoreSpec.payload("earlier-2"))
                expect(earlier.closeBatch()).toNot(beNil())
                store = EventStore(directory: earlier.directory!, capacity: 2, logger: .disabled)

                expect(store.stage(EventStoreSpec.payload("before-listing"))) == true

                store.preparePayloadsFromInterruptedLogs()
                expect(store.pendingBatches().count) == 1
                expect(store.pendingEventCount) == 3
                expect(store.stage(EventStoreSpec.payload("after-listing"))) == false
            }

            it("counts the events a commit is still writing, so a slow write does not make room") {
                let writing = DispatchSemaphore(value: 0)
                let resume = DispatchSemaphore(value: 0)
                var blocked = false
                store = EventStore.temporary(capacity: 2, writeLog: { file, bytes in
                    if !blocked {
                        blocked = true
                        writing.signal()
                        resume.wait()
                    }
                    return file.writeAll(bytes)
                })
                expect(store.stage(EventStoreSpec.payload("first"))) == true
                expect(store.stage(EventStoreSpec.payload("second"))) == true

                let committed = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    store.commit()
                    committed.signal()
                }
                writing.wait()

                expect(store.pendingEventCount) == 2
                expect(store.stage(EventStoreSpec.payload("third"))) == false

                resume.signal()
                committed.wait()

                expect(store.pendingEventCount) == 2
                expect(store.stage(EventStoreSpec.payload("fourth"))) == false
            }

            it("takes a summary even when it is full, since those evaluations were already counted") {
                store = EventStore.temporary(capacity: 1)

                expect(store.stage(EventStoreSpec.payload("first"))) == true
                expect(store.stage(EventStoreSpec.payload("summary"), bypassingCapacity: true)) == true
                // Kept, but not counted as an event.
                expect(store.pendingEventCount) == 1
            }

            // Written at every commit point, summaries would otherwise fill capacity during an outage, and full events
            // would be refused for the summaries of evaluations already counted.
            for persistEvents in [true, false] {
                it("leaves summaries out of the event count in every state, persisting: \(persistEvents)") {
                    store = EventStore.temporary(capacity: 2, persistEvents: persistEvents)
                    expect(store.stage(EventStoreSpec.payload("summary-1"), bypassingCapacity: true)) == true
                    expect(store.stage(EventStoreSpec.payload("event-1"))) == true
                    expect(store.pendingEventCount).to(equal(1), description: "staged")
                    store.commit()
                    expect(store.pendingEventCount).to(equal(1), description: "committed")

                    let batch = store.closeBatch()!
                    expect(batch.eventCount).to(equal(2), description: "the batch holds both frames")
                    expect(store.pendingEventCount).to(equal(1), description: "closed")
                    expect(store.pendingBatches()) == [batch]
                    expect(store.pendingEventCount).to(equal(1), description: "listed")

                    expect(store.stage(EventStoreSpec.payload("summary-2"), bypassingCapacity: true)) == true
                    expect(store.stage(EventStoreSpec.payload("event-2"))) == true
                    expect(store.stage(EventStoreSpec.payload("event-3"))).to(equal(false), description: "capacity still counts the events")

                    store.startedSending(batch)
                    expect(store.pendingEventCount).to(equal(1), description: "sending")
                    store.stoppedSending(batch)
                    expect(store.pendingEventCount).to(equal(2), description: "sent and failed")
                    store.remove(batch)
                    expect(store.pendingEventCount).to(equal(1), description: "delivered")
                }
            }

            it("does not count as events the summaries a failed write left in memory") {
                let lock = UnfairLock()
                var failing = false
                store = EventStore.temporary(writeLog: { file, bytes in
                    lock.withLock { failing } ? ENOSPC : file.writeAll(bytes)
                })
                _ = store.stage(EventStoreSpec.payload("written"))
                _ = store.stage(EventStoreSpec.payload("summary-written"), bypassingCapacity: true)
                store.commit()
                lock.withLock { failing = true }
                _ = store.stage(EventStoreSpec.payload("put-back"))
                _ = store.stage(EventStoreSpec.payload("summary-put-back"), bypassingCapacity: true)
                store.commit()
                expect(store.isPersisting) == false
                expect(store.pendingEventCount) == 2

                let fromLog = store.closeBatch()!
                let fromMemory = store.pendingBatches().last!
                expect(EventStoreSpec.keys(ofBody: try store.body(of: fromLog))) == ["written", "summary-written"]
                expect(EventStoreSpec.keys(ofBody: try store.body(of: fromMemory))) == ["put-back", "summary-put-back"]
                expect(store.pendingEventCount) == 2
                _ = store.pendingBatches()
                expect(store.pendingEventCount) == 2
            }

            for persistEvents in [true, false] {
                it("stops counting a batch once when two deliveries both remove it (persisting: \(persistEvents))") {
                    store = EventStore.temporary(persistEvents: persistEvents)
                    _ = store.stage(EventStoreSpec.payload("first"))
                    let first = store.closeBatch()!
                    _ = store.stage(EventStoreSpec.payload("second"))
                    _ = store.closeBatch()
                    _ = store.pendingBatches()

                    store.remove(first)
                    store.remove(first)

                    expect(store.pendingEventCount) == 1
                }
            }

            it("does not list a delivered batch again when its file will not delete, and deletes it when it can") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("first"))
                let first = store.closeBatch()!
                _ = store.stage(EventStoreSpec.payload("second"))
                let second = store.closeBatch()!

                let directory = store.directory!
                // A directory with no write permission is one its entries cannot be unlinked from, which is what the
                // filesystem refusing a delete looks like from here.
                let readOnly: [FileAttributeKey: Any] = [.posixPermissions: 0o555]
                let writable: [FileAttributeKey: Any] = [.posixPermissions: 0o755]
                try? FileManager.default.setAttributes(readOnly, ofItemAtPath: directory.path)
                defer { try? FileManager.default.setAttributes(writable, ofItemAtPath: directory.path) }

                store.remove(first)

                // Delivered, so it neither counts against capacity nor comes back for another delivery, even though
                // its file is still sitting there.
                expect(store.pendingBatches().map(\.payloadId)) == [second.payloadId]
                expect(store.pendingEventCount) == 1

                try? FileManager.default.setAttributes(writable, ofItemAtPath: directory.path)

                // The listing that can delete it does, rather than leaving it for a run that would send it again.
                _ = store.pendingBatches()
                let left = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                expect(left.filter { $0.lastPathComponent.hasPrefix("ready-\(first.payloadId)") }).to(beEmpty())
            }

            it("stops counting a batch once when another process delivered it and a listing came between") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("first"))
                let first = store.closeBatch()!
                _ = store.stage(EventStoreSpec.payload("second"))
                _ = store.closeBatch()

                EventStoreSpec.reader(sharing: store).remove(first)
                _ = store.pendingBatches()
                store.remove(first)

                expect(store.pendingEventCount) == 1
            }

            for persistEvents in [true, false] {
                it("neither loses nor doubles a batch closed while a listing runs (persisting: \(persistEvents))") {
                    store = EventStore.temporary(capacity: 100_000, persistEvents: persistEvents)
                    let listing = store!
                    let doneLock = UnfairLock()
                    var done = false
                    let listerFinished = DispatchSemaphore(value: 0)
                    DispatchQueue.global().async {
                        while !doneLock.withLock({ done }) {
                            _ = listing.pendingBatches()
                            // The locks are not fair, and without this the listings can hold them so continuously that
                            // the closes starve.
                            sched_yield()
                        }
                        listerFinished.signal()
                    }

                    // Checked after every close, because the next listing would correct a miscount before the end of
                    // the loop could see it.
                    var miscounts: [String] = []
                    for closed in 1...150 {
                        _ = store.stage(EventStoreSpec.payload("event-\(closed)"))
                        _ = store.closeBatch()
                        let counted = store.pendingEventCount
                        if counted != closed {
                            miscounts.append("\(counted) after \(closed) closes")
                        }
                    }
                    doneLock.withLock { done = true }
                    listerFinished.wait()

                    expect(miscounts).to(beEmpty())
                }
            }
        }
    }

    /// Events framed in a quarter of a batch each: four of them and the file header are just past the batch size, so
    /// three fit in each batch.
    private func batchSizeSpec() {
        describe("batch size") {
            let quarter = EventLogFormat.maxBatchSize / 4
            var store: EventStore!
            afterEach {
                store.deleteEverything()
            }

            func stage(_ indices: ClosedRange<Int>) {
                for index in indices {
                    expect(store.stage(EventStoreSpec.payload(framedIn: quarter, key: "event-\(index)"))) == true
                }
            }

            func keysByBatch() -> [[String]] {
                store.pendingBatches().map { batch -> [String] in
                    let body = try? store.body(of: batch)
                    expect(body?.count ?? 0) <= EventLogFormat.maxBatchSize
                    let keys = EventStoreSpec.keys(ofBody: body)
                    expect(keys.count) == batch.eventCount
                    return keys
                }
                // Batches closed within the same instant list in either order.
                .sorted { $0.first ?? "" < $1.first ?? "" }
            }

            func batchFileSizes() throws -> [Int] {
                try FileManager.default
                    .contentsOfDirectory(at: store.directory!, includingPropertiesForKeys: [.fileSizeKey])
                    .filter { $0.lastPathComponent.hasPrefix("ready-") }
                    .map { try $0.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0 }
            }

            it("closes a log a commit would take past the batch size, and carries on in a new one") {
                store = EventStore.temporary()
                stage(1...5)
                store.commit()
                _ = store.closeBatch()

                expect(keysByBatch()) == [["event-1", "event-2", "event-3"], ["event-4", "event-5"]]
                expect(try batchFileSizes().allSatisfy { $0 <= EventLogFormat.maxBatchSize }) == true
                expect(store.pendingEventCount) == 5
            }

            it("closes a log a later commit would take past the batch size") {
                store = EventStore.temporary()
                stage(1...2)
                store.commit()
                stage(3...5)
                store.commit()
                _ = store.closeBatch()

                expect(keysByBatch()) == [["event-1", "event-2", "event-3"], ["event-4", "event-5"]]
                expect(try batchFileSizes().allSatisfy { $0 <= EventLogFormat.maxBatchSize }) == true
            }

            it("splits what it holds in memory at the batch size too") {
                store = EventStore.temporary(persistEvents: false)
                stage(1...5)
                _ = store.closeBatch()

                expect(keysByBatch()) == [["event-1", "event-2", "event-3"], ["event-4", "event-5"]]
                expect(store.pendingEventCount) == 5
            }

            it("assembles a stored batch in the bytes it was read into, rather than in a copy") {
                var readInto: UnsafeRawPointer?
                store = EventStore.temporary(readFile: { url in
                    let file = try Data(contentsOf: url)
                    readInto = file.withUnsafeBytes { $0.baseAddress }
                    return file
                })
                stage(1...3)
                let batch = store.closeBatch()!

                let body = try? store.body(of: batch)
                expect(body?.withUnsafeBytes { $0.baseAddress }) == readInto
                expect(EventStoreSpec.keys(ofBody: body)) == ["event-1", "event-2", "event-3"]
            }

            it("takes an event that fills a batch on its own, and refuses any larger") {
                store = EventStore.temporary()
                let largest = EventLogFormat.maxFrameSize + EventLogFormat.frameHeaderSize
                expect(store.stage(EventStoreSpec.payload(framedIn: largest + 1, key: "too-large"))) == false
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-1"))) == true
                expect(store.stage(EventStoreSpec.payload(framedIn: largest, key: "largest"))) == true
                _ = store.closeBatch()

                expect(keysByBatch()) == [["event-1"], ["largest"]]
                expect(try batchFileSizes().allSatisfy { $0 <= EventLogFormat.maxBatchSize }) == true
            }
        }
    }

    /// A byte capacity of 1000 lets full events take the store to 800 bytes and summaries to 1000. Every event here is
    /// framed in exactly 100 bytes, so eight full events fill it and two summaries fill the rest.
    private func byteCapacitySpec() {
        describe("byte capacity") {
            var store: EventStore!
            afterEach {
                store.deleteEverything()
            }

            it("refuses full events past what it holds back for summaries") {
                store = EventStore.temporary(capacity: 100, byteCapacity: 1000)

                for index in 1...8 {
                    expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-\(index)"))) == true
                }
                expect(store.hasRoomForEventBytes) == false
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-9"))) == false
                expect(store.pendingEventCount) == 8
            }

            it("takes summaries into what it holds back, and refuses them past the byte capacity") {
                store = EventStore.temporary(capacity: 100, byteCapacity: 1000)
                for index in 1...8 {
                    _ = store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-\(index)"))
                }

                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "summary-1"), bypassingCapacity: true)) == true
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "summary-2"), bypassingCapacity: true)) == true
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "summary-3"), bypassingCapacity: true)) == false
                // Their bytes count, but they are not events.
                expect(store.pendingEventCount) == 8
            }

            it("refuses a reserved event that turns out not to fit, and gives up its reservation") {
                store = EventStore.temporary(capacity: 100, byteCapacity: 1000)
                for index in 1...7 {
                    _ = store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-\(index)"))
                }
                store.reserve(1)

                expect(store.stageReserved(EventStoreSpec.payload(framedIn: 200, key: "too-big"))) == false
                expect(store.pendingEventCount) == 7
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "fits"))) == true
            }

            it("makes room again once a batch is delivered") {
                store = EventStore.temporary(capacity: 100, byteCapacity: 1000)
                for index in 1...8 {
                    _ = store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-\(index)"))
                }
                let batch = store.closeBatch()!
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "while-held"))) == false

                store.startedSending(batch)
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "while-sending"))) == true
                store.remove(batch)
                expect(store.hasRoomForEventBytes) == true
            }

            it("bounds the batches it holds in memory once it has given up on the disk") {
                store = EventStore.temporary(capacity: 100, byteCapacity: 1000, writeLog: { _, _ in ENOSPC })
                for index in 1...8 {
                    _ = store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-\(index)"))
                }
                store.commit()
                expect(store.isPersisting) == false
                expect(store.closeBatch()).toNot(beNil())

                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "past-capacity"))) == false
            }

            it("is not bounded by bytes where it keeps events off the disk") {
                store = EventStore.temporary(capacity: 100, byteCapacity: 1000, persistEvents: false)
                for index in 1...20 {
                    expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-\(index)"))) == true
                }
                expect(store.hasRoomForEventBytes) == true
                expect(store.pendingEventCount) == 20
            }

            it("bounds summaries by bytes even where it keeps events off the disk") {
                // Nothing else bounds them: capacity never refuses a summary, and a delivery that keeps failing keeps
                // every one it was given.
                store = EventStore.temporary(capacity: 100, byteCapacity: 1000, persistEvents: false)
                for index in 1...8 {
                    _ = store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-\(index)"))
                }
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "summary-1"), bypassingCapacity: true)) == true
                expect(store.closeBatch()?.eventCount) == 9
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "summary-2"), bypassingCapacity: true)) == true

                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "summary-3"), bypassingCapacity: true)) == false
                // Full events are still bounded by count alone.
                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-9"))) == true
            }

            it("counts committed bytes as well as staged ones") {
                store = EventStore.temporary(capacity: 100, byteCapacity: 1000)
                for index in 1...8 {
                    _ = store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-\(index)"))
                }
                store.commit()

                expect(store.stage(EventStoreSpec.payload(framedIn: 100, key: "after-commit"))) == false
            }

            it("counts the bytes of a batch another process closed from the listing, without reading it") {
                store = EventStore.temporary()
                for index in 1...8 {
                    _ = store.stage(EventStoreSpec.payload(framedIn: 100, key: "event-\(index)"))
                }
                expect(store.closeBatch()).toNot(beNil())

                var reads = 0
                let other = EventStore.sharing(store.directory!, byteCapacity: 1000) { url in
                    reads += 1
                    return try Data(contentsOf: url)
                }
                expect(other.pendingBatches().count) == 1

                expect(reads) == 0
                expect(other.hasRoomForEventBytes) == false
                expect(other.stage(EventStoreSpec.payload(framedIn: 100, key: "other"))) == false
            }
        }
    }

    /// Each store here is the current environment of an application `app` under a root of the test's own, since the
    /// first expiry also looks at every other environment beside it.
    private func expirySpec() {
        describe("expiry") {
            var root: URL!
            var store: EventStore!
            beforeEach {
                root = EventStore.temporaryDirectory()
                store = EventStore.sharing(root.appendingPathComponent("app.current", isDirectory: true))
            }
            afterEach {
                try? FileManager.default.removeItem(at: root)
            }

            it("discards a batch last written longer ago than the maximum age, and stops counting it") {
                _ = store.stage(EventStoreSpec.payload("old-1"))
                _ = store.stage(EventStoreSpec.payload("old-2"))
                _ = store.closeBatch()
                try EventStoreSpec.age(try EventStoreSpec.onlyBatchFile(in: store), byDays: 8)

                expect(store.discardExpired()) == 2

                expect(store.pendingBatches()).to(beEmpty())
                expect(store.pendingEventCount) == 0
                expect(store.stage(EventStoreSpec.payload("new"))) == true
            }

            it("keeps a batch younger than the maximum age") {
                _ = store.stage(EventStoreSpec.payload("recent"))
                _ = store.closeBatch()
                try EventStoreSpec.age(try EventStoreSpec.onlyBatchFile(in: store), byDays: 6)

                expect(store.discardExpired()) == 0
                expect(store.pendingBatches().count) == 1
            }

            it("keeps a batch whose request is out, however old") {
                _ = store.stage(EventStoreSpec.payload("sending"))
                let batch = store.closeBatch()!
                try EventStoreSpec.age(try EventStoreSpec.onlyBatchFile(in: store), byDays: 30)
                store.startedSending(batch)

                expect(store.discardExpired()) == 0
                expect(try store.body(of: batch)).toNot(beNil())
            }

            it("leaves a batch another store in this process is sending until it stops") {
                let sender = EventStore.sharing(store.directory!)
                _ = sender.stage(EventStoreSpec.payload("sending"))
                let batch = sender.closeBatch()!
                let file = try EventStoreSpec.onlyBatchFile(in: sender)
                try EventStoreSpec.age(file, byDays: 30)
                sender.startedSending(batch)

                expect(store.discardExpired()) == 0
                expect(FileManager.default.fileExists(atPath: file.path)) == true

                sender.stoppedSending(batch)
                expect(store.discardExpired()) == 1
                expect(FileManager.default.fileExists(atPath: file.path)) == false
            }

            #if os(macOS) || targetEnvironment(macCatalyst)
            it("leaves a batch another process is sending until it stops") {
                _ = store.stage(EventStoreSpec.payload("sending"))
                _ = store.closeBatch()
                let file = try EventStoreSpec.onlyBatchFile(in: store)
                try EventStoreSpec.age(file, byDays: 30)
                // A lock taken through a descriptor of its own contends as another process's would.
                let otherProcess = EventLogFile.open(at: file, flags: O_RDONLY)!
                expect(otherProcess.tryLock(shared: true)) == true

                expect(store.discardExpired()) == 0
                expect(FileManager.default.fileExists(atPath: file.path)) == true

                otherProcess.close()
                expect(store.discardExpired()) == 1
                expect(FileManager.default.fileExists(atPath: file.path)) == false
            }
            #endif

            it("leaves the directory of another environment open in this process") {
                let open = EventStore.sharing(root.appendingPathComponent("app.open", isDirectory: true))
                _ = open.stage(EventStoreSpec.payload("open"))
                _ = open.closeBatch()
                try EventStoreSpec.age(contentsOf: open.directory!, byDays: 30)

                expect(store.discardExpired()) == 0
                expect(open.pendingBatches().count) == 1
            }

            it("discards a log nobody holds once nothing has written to it for the maximum age, and leaves a younger one") {
                func logLeftBy(_ key: String) -> URL {
                    // Going away closes its log, as its process ending would.
                    let ended = EventStore.sharing(store.directory!)
                    _ = ended.stage(EventStoreSpec.payload(key))
                    ended.commit()
                    return ended.openLogUrl!
                }
                let old = logLeftBy("gone")
                let young = logLeftBy("recent")
                try EventStoreSpec.age(old, byDays: 8)
                try EventStoreSpec.age(young, byDays: 1)

                expect(store.discardExpired()) == 1

                expect(FileManager.default.fileExists(atPath: old.path)) == false
                expect(FileManager.default.fileExists(atPath: young.path)) == true
            }

            it("leaves the log of another live store alone, however long since it was written") {
                // A live process may go longer than the maximum age without an event.
                let alive = EventStore.sharing(store.directory!)
                _ = alive.stage(EventStoreSpec.payload("alive"))
                alive.commit()
                try EventStoreSpec.age(alive.openLogUrl!, byDays: 8)

                expect(store.discardExpired()) == 0
                expect(FileManager.default.fileExists(atPath: alive.openLogUrl!.path)) == true
            }

            it("discards a log a process died while opening, which holds no events") {
                try FileManager.default.createDirectory(at: store.directory!, withIntermediateDirectories: true)
                let opening = store.directory!.appendingPathComponent(DiskEventLog.openingPrefix + UUID().uuidString)
                try EventLogFormat.fileHeader.write(to: opening)
                try EventStoreSpec.age(opening, byDays: 8)

                expect(store.discardExpired()) == 0
                expect(FileManager.default.fileExists(atPath: opening.path)) == false
            }

            it("leaves its own open log alone, however long since it was written") {
                _ = store.stage(EventStoreSpec.payload("own"))
                store.commit()
                try EventStoreSpec.age(store.openLogUrl!, byDays: 8)

                expect(store.discardExpired()) == 0
                expect(EventStoreSpec.keys(of: store)) == ["own"]
            }

            it("removes the directories of this application's other environments once nothing has written to them for the maximum age") {
                let abandoned = try EventStoreSpec.environment("app.abandoned", in: root, events: 2)
                let inUse = try EventStoreSpec.environment("app.in-use", in: root, events: 1)
                let otherApplication = try EventStoreSpec.environment("other.abandoned", in: root, events: 1)
                try EventStoreSpec.age(contentsOf: abandoned, byDays: 8)
                try EventStoreSpec.age(contentsOf: inUse, byDays: 1)
                try EventStoreSpec.age(contentsOf: otherApplication, byDays: 30)

                expect(store.discardExpired()) == 2
                // Once per process: the next call has nothing else to look at.
                expect(store.discardExpired()) == 0

                expect(FileManager.default.fileExists(atPath: abandoned.path)) == false
                expect(try FileManager.default.contentsOfDirectory(atPath: inUse.path)).toNot(beEmpty())
                expect(try FileManager.default.contentsOfDirectory(atPath: otherApplication.path)).toNot(beEmpty())
            }

            it("does nothing where the application did not ask for persistence") {
                let abandoned = try EventStoreSpec.environment("app.abandoned", in: root, events: 1)
                try EventStoreSpec.age(contentsOf: abandoned, byDays: 8)
                store = EventStore.sharing(root.appendingPathComponent("app.current", isDirectory: true), persistEvents: false)

                expect(store.discardExpired()) == 0
                expect(try FileManager.default.contentsOfDirectory(atPath: abandoned.path)).toNot(beEmpty())
            }
        }
    }

    /// An environment directory under `root` holding one closed batch of `events` events.
    private static func environment(_ name: String, in root: URL, events: Int) throws -> URL {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        let writer = EventStore.sharing(directory)
        for index in 0..<events {
            _ = writer.stage(payload("\(name)-\(index)"))
        }
        expect(writer.closeBatch()).toNot(beNil())
        return directory
    }

    private static func age(_ file: URL, byDays days: Double) throws {
        let modified = Date().addingTimeInterval(-days * 24 * 60 * 60)
        try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: file.path)
    }

    private static func age(contentsOf directory: URL, byDays days: Double) throws {
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try age(file, byDays: days)
        }
    }

    /// Losing the disk should cost durability and nothing else. These are the events an application would otherwise
    /// have reported before any of this existed, so the store keeps delivering them from memory.
    private func fallbackSpec() {
        describe("a store the filesystem will not take") {
            var store: EventStore!
            beforeEach {
                store = EventStoreSpec.unwritableStore()
            }
            afterEach {
                // The blocking file, which is the parent of the directory the store never got to create.
                try? FileManager.default.removeItem(at: store.directory!.deletingLastPathComponent())
            }

            it("delivers the events from memory rather than dropping them") {
                _ = store.stage(EventStoreSpec.payload("first"))
                _ = store.stage(EventStoreSpec.payload("second"))
                store.commit()

                // The commit had nowhere to go, so the events are still the store's to deliver.
                expect(store.pendingEventCount) == 2

                let batch = store.closeBatch()
                expect(batch?.eventCount) == 2
                expect(try store.body(of: batch!))
                    == Data("[{\"kind\":\"custom\",\"key\":\"first\"},{\"kind\":\"custom\",\"key\":\"second\"}]".utf8)
            }

            it("produces the same body a batch on disk would have") {
                let written = EventStore.temporary()
                defer { written.deleteEverything() }
                _ = written.stage(EventStoreSpec.payload("same"))
                let onDisk = written.closeBatch()!

                _ = store.stage(EventStoreSpec.payload("same"))
                let held = store.closeBatch()!

                expect(try store.body(of: held)) == (try written.body(of: onDisk))
            }

            it("keeps accepting events after persistence has been given up on") {
                _ = store.stage(EventStoreSpec.payload("before"))
                store.commit()

                expect(store.stage(EventStoreSpec.payload("after"))) == true
            }

            it("keeps the events in the order they were recorded across a failed commit") {
                _ = store.stage(EventStoreSpec.payload("first"))
                store.commit()
                _ = store.stage(EventStoreSpec.payload("second"))

                let batch = store.closeBatch()!
                expect(try store.body(of: batch))
                    == Data("[{\"kind\":\"custom\",\"key\":\"first\"},{\"kind\":\"custom\",\"key\":\"second\"}]".utf8)
            }

            it("delivers what memory was left holding beside what the disk already took") {
                var writes = 0
                let interrupted = EventStore.temporary(writeLog: { file, bytes in
                    writes += 1
                    // The file header and the first event land; the device is full from then on.
                    return writes > 2 ? ENOSPC : file.writeAll(bytes)
                })
                defer { interrupted.deleteEverything() }

                _ = interrupted.stage(EventStoreSpec.payload("written"))
                interrupted.commit()
                _ = interrupted.stage(EventStoreSpec.payload("held"))
                interrupted.commit()
                expect(interrupted.isPersisting) == false

                _ = interrupted.closeBatch()

                // A failed write leaves events on both sides, and closing only the log would leave the rest to a
                // delivery that reported success without them.
                let bodies = interrupted.pendingBatches().map { EventStoreSpec.keys(ofBody: try? interrupted.body(of: $0)) }
                expect(bodies) == [["written"], ["held"]]
                expect(interrupted.pendingEventCount) == 2
            }

            it("sends the frames a write landed before it failed once, not from the log and memory both") {
                var writes = 0
                let interrupted = EventStore.temporary(writeLog: { file, bytes in
                    writes += 1
                    // The file header and the first event land. The next write gets a whole frame and part of another
                    // onto the disk before the device is full.
                    guard writes > 2
                    else { return file.writeAll(bytes) }
                    _ = file.writeAll(bytes.dropLast(3))
                    return ENOSPC
                })
                defer { interrupted.deleteEverything() }

                _ = interrupted.stage(EventStoreSpec.payload("written"))
                interrupted.commit()
                _ = interrupted.stage(EventStoreSpec.payload("landed"))
                _ = interrupted.stage(EventStoreSpec.payload("torn"))
                interrupted.commit()
                expect(interrupted.isPersisting) == false

                _ = interrupted.closeBatch()

                let bodies = interrupted.pendingBatches().map { EventStoreSpec.keys(ofBody: try? interrupted.body(of: $0)) }
                expect(bodies) == [["written"], ["landed", "torn"]]
                expect(interrupted.pendingEventCount) == 3
            }

            it("leaves the next run nothing to recover from a first write that failed partway") {
                var writes = 0
                let interrupted = EventStore.temporary(writeLog: { file, bytes in
                    writes += 1
                    // The file header lands, and then a whole frame and part of another before the device is full.
                    guard writes > 1
                    else { return file.writeAll(bytes) }
                    _ = file.writeAll(bytes.dropLast(3))
                    return ENOSPC
                })
                defer { interrupted.deleteEverything() }

                _ = interrupted.stage(EventStoreSpec.payload("landed"))
                _ = interrupted.stage(EventStoreSpec.payload("torn"))
                interrupted.commit()
                let fromMemory = interrupted.closeBatch()
                expect(EventStoreSpec.keys(ofBody: fromMemory.flatMap { try? interrupted.body(of: $0) })) == ["landed", "torn"]

                // Delivered from memory this run, so the next must not find any of it again in the log.
                let next = interrupted.nextRun()
                next.preparePayloadsFromInterruptedLogs()
                expect(next.pendingBatches()).to(beEmpty())
            }

            it("leaves the next run nothing to recover from a first write that failed partway and could not be cut back") {
                var writes = 0
                let interrupted = EventStore.temporary(writeLog: { file, bytes in
                    writes += 1
                    guard writes > 1
                    else { return file.writeAll(bytes) }
                    _ = file.writeAll(bytes.dropLast(3))
                    EventStoreSpec.refuseTruncating(file)
                    return ENOSPC
                })
                defer { interrupted.deleteEverything() }

                _ = interrupted.stage(EventStoreSpec.payload("landed"))
                _ = interrupted.stage(EventStoreSpec.payload("torn"))
                interrupted.commit()
                let fromMemory = interrupted.closeBatch()
                expect(EventStoreSpec.keys(ofBody: fromMemory.flatMap { try? interrupted.body(of: $0) })) == ["landed", "torn"]

                // The whole frame that landed is in the log as well as in memory, under no count that would leave it
                // out, so a later run recovering the log would send it a second time under another payload ID.
                let next = interrupted.nextRun()
                next.preparePayloadsFromInterruptedLogs()
                expect(next.pendingBatches()).to(beEmpty())
            }

            it("holds a batch until it is removed, so a failed delivery can be retried") {
                _ = store.stage(EventStoreSpec.payload("retry-me"))
                let batch = store.closeBatch()!

                expect(store.pendingBatches()) == [batch]
                expect(store.pendingEventCount) == 1

                store.remove(batch)

                expect(store.pendingBatches()).to(beEmpty())
                expect(store.pendingEventCount) == 0
            }

            it("still refuses events once capacity is reached, so memory stays bounded") {
                let bounded = EventStoreSpec.unwritableStore(capacity: 2)
                defer { try? FileManager.default.removeItem(at: bounded.directory!.deletingLastPathComponent()) }

                expect(bounded.stage(EventStoreSpec.payload("first"))) == true
                bounded.commit()
                expect(bounded.stage(EventStoreSpec.payload("second"))) == true
                expect(bounded.stage(EventStoreSpec.payload("third"))) == false
                expect(bounded.pendingEventCount) == 2
            }

            it("has nothing to close when nothing was recorded") {
                expect(store.closeBatch()).to(beNil())
            }
        }
    }
}
