import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

#if canImport(SQLite3)
import SQLite3

/// Holds the SQLite store to the same contract `EventStoreSpec` holds the log to.
///
/// The durability spec's §13.2 is explicit that the mechanism is unspecified and the observable contract is not: a
/// later run has to find what the last one left, deliver it under the payload ID it was closed with, and have every
/// event counted once. So these are mostly the log's own tests asked of a different implementation, plus the few
/// places where a database answers a requirement differently enough to be worth pinning on its own.
final class SQLiteEventStoreSpec: QuickSpec {
    override func spec() {
        stagingSpec()
        recoverySpec()
        sigkillSpec()
        batchSpec()
        capacitySpec()
        schemaVersionSpec()
        interchangeabilitySpec()
    }

    private static func payload(_ key: String) -> Data {
        Data("{\"kind\":\"custom\",\"key\":\"\(key)\"}".utf8)
    }

    /// A store reading the same directory as another, standing in for the next run of the application: it sees only
    /// what actually reached the disk, which is the whole question a crash asks.
    private static func reader(sharing store: SQLiteEventStore) -> SQLiteEventStore {
        SQLiteEventStore(directory: store.directory, capacity: 100, logger: .disabled)
    }

    /// Copies the database as it sits on disk while the writer is still open.
    ///
    /// That is the `SIGKILL` picture: no `sqlite3_close`, no WAL checkpoint, no `deinit`. The `-shm` file is
    /// process-local and is not copied; SQLite rebuilds it. The main file and the WAL are what the next process sees.
    private static func imageAfterKill(of store: SQLiteEventStore) -> URL {
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in ["events.sqlite", "events.sqlite-wal"] {
            let source = store.directory.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: source.path) {
                try? FileManager.default.copyItem(at: source, to: destination.appendingPathComponent(name))
            }
        }
        return destination
    }

    private static func store(at directory: URL) -> SQLiteEventStore {
        SQLiteEventStore(directory: directory, capacity: 100, logger: .disabled)
    }

    private static func keys(of store: SQLiteEventStore) -> [String] {
        store.pendingEventPayloads().compactMap {
            guard case .object(let fields) = try? JSONDecoder().decode(LDValue.self, from: $0),
                  case .string(let key) = fields["key"]
            else { return nil }
            return key
        }
    }

    private func stagingSpec() {
        describe("staging") {
            var store: SQLiteEventStore!
            beforeEach {
                store = SQLiteEventStore.temporary()
            }
            afterEach {
                store.deleteEverything()
            }

            it("keeps a staged event out of the database until it is committed") {
                _ = store.stage(Self.payload("staged"), bypassingCapacity: false)

                expect(Self.keys(of: Self.reader(sharing: store))) == []
            }

            it("puts a committed event where another process would find it") {
                _ = store.stage(Self.payload("committed"), bypassingCapacity: false)
                store.commit()

                expect(Self.keys(of: Self.reader(sharing: store))) == ["committed"]
            }

            it("does not write on the thread that staged the event") {
                // The commit queue is suspended, so anything the store schedules onto it cannot have run. If staging
                // wrote on the caller's thread instead, the events would be in the database anyway.
                let suspended = DispatchQueue(label: "suspended")
                suspended.suspend()
                let deferring = SQLiteEventStore.temporary(commitQueue: suspended)
                defer { suspended.resume(); deferring.deleteEverything() }

                // Past the 16 KiB staging threshold, so a commit is certainly wanted.
                for index in 0..<200 {
                    _ = deferring.stage(Self.payload(String(repeating: "x", count: 200) + "\(index)"),
                                        bypassingCapacity: false)
                }

                expect(Self.keys(of: Self.reader(sharing: deferring))) == []
            }

            it("keeps events in the order they were recorded") {
                for index in 0..<50 {
                    _ = store.stage(Self.payload("event-\(index)"), bypassingCapacity: false)
                }
                store.commit()

                expect(Self.keys(of: Self.reader(sharing: store))) == (0..<50).map { "event-\($0)" }
            }
        }
    }

    private func recoverySpec() {
        describe("events a previous run left behind") {
            var store: SQLiteEventStore!
            beforeEach {
                store = SQLiteEventStore.temporary()
            }
            afterEach {
                store.deleteEverything()
            }

            it("are delivered as a batch by the next run") {
                _ = store.stage(Self.payload("from-the-last-run"), bypassingCapacity: false)
                store.commit()

                // A second store on the same database is the next run: it never saw the batch identifier the first one
                // was inserting under, so those rows are pending for it without any recovery step.
                let next = Self.reader(sharing: store)
                next.recoverInterruptedLog()

                let batches = next.pendingBatches()
                expect(batches.count) == 1
                expect(batches.first?.eventCount) == 1
                expect(next.body(of: batches[0])) == Data("[{\"kind\":\"custom\",\"key\":\"from-the-last-run\"}]".utf8)
            }

            it("do not become a second batch when the next run closes its own") {
                _ = store.stage(Self.payload("older"), bypassingCapacity: false)
                store.commit()

                let next = Self.reader(sharing: store)
                _ = next.stage(Self.payload("newer"), bypassingCapacity: false)
                let closed = next.closeBatch()

                // Two batches, not one merged batch and not three: the previous run's rows keep their own identifier.
                let batches = next.pendingBatches()
                expect(batches.count) == 2
                expect(batches.map { $0.eventCount }) == [1, 1]
                expect(batches.contains { $0.payloadId == closed?.payloadId }) == true
            }

            it("count against capacity, so a backlog cannot be doubled by restarting") {
                for index in 0..<10 {
                    _ = store.stage(Self.payload("event-\(index)"), bypassingCapacity: false)
                }
                store.commit()

                // Counted when the store opens the database, which is what the SDK's startup call does. Until then it
                // reports what this run has recorded, exactly as the log store does -- neither reads the disk on a
                // property that the recording path touches.
                let next = Self.reader(sharing: store)
                expect(next.pendingEventCount) == 0

                next.recoverInterruptedLog()

                expect(next.pendingEventCount) == 10
            }
        }
    }

    /// `SIGKILL` does not run `deinit`, so it never `COMMIT`s leftover staged rows and never closes the connection.
    ///
    /// The tests snapshot the files after the call under test returns, while the writer is still alive, then open a
    /// new store on that copy. That is stricter than opening a second connection on the live directory: the writer
    /// cannot checkpoint on the way out, because it never sees the copy.
    private func sigkillSpec() {
        describe("SIGKILL") {
            var writer: SQLiteEventStore!
            beforeEach {
                writer = SQLiteEventStore.temporary()
            }
            afterEach {
                writer.deleteEverything()
            }

            it("keeps an event whose commit had returned") {
                _ = writer.stage(Self.payload("committed"), bypassingCapacity: false)
                writer.commit()

                let image = Self.imageAfterKill(of: writer)
                defer { try? FileManager.default.removeItem(at: image) }

                let next = Self.store(at: image)
                next.recoverInterruptedLog()

                expect(Self.keys(of: next)) == ["committed"]
                expect(next.pendingBatches().first?.eventCount) == 1
            }

            it("loses an event that was only staged") {
                _ = writer.stage(Self.payload("still-in-memory"), bypassingCapacity: false)

                let image = Self.imageAfterKill(of: writer)
                defer { try? FileManager.default.removeItem(at: image) }

                let next = Self.store(at: image)
                next.recoverInterruptedLog()

                expect(Self.keys(of: next)) == []
                expect(next.pendingBatches()) == []
            }

            it("keeps a tracked event recorded through EventReporter") {
                var config = LDConfig.stub
                config.sendEvents = true
                let service = DarklyServiceMock()
                service.config = config
                let reporter = EventReporter(service: service, onSyncComplete: nil, store: writer)

                reporter.record(CustomEvent(key: "fatal-error", context: LDContext.stub(), data: nil))

                let image = Self.imageAfterKill(of: writer)
                defer { try? FileManager.default.removeItem(at: image) }

                let next = Self.store(at: image)
                next.recoverInterruptedLog()
                let payloads = next.pendingEventPayloads()
                expect(payloads.count) == 1
                expect(String(data: payloads[0], encoding: .utf8)).to(contain("\"kind\":\"custom\""))
                expect(String(data: payloads[0], encoding: .utf8)).to(contain("fatal-error"))
            }

            it("does not keep an evaluation that never reached a commit point") {
                var config = LDConfig.stub
                config.sendEvents = true
                let service = DarklyServiceMock()
                service.config = config
                let reporter = EventReporter(service: service, onSyncComplete: nil, store: writer)
                let flag = FeatureFlag(flagKey: "flag-key", value: true, variation: 1, flagVersion: 2, trackEvents: true)

                reporter.recordFlagEvaluationEvents(flagKey: "flag-key",
                                                    value: true,
                                                    defaultValue: false,
                                                    featureFlag: flag,
                                                    context: LDContext.stub(),
                                                    includeReason: false)

                let image = Self.imageAfterKill(of: writer)
                defer { try? FileManager.default.removeItem(at: image) }

                let next = Self.store(at: image)
                next.recoverInterruptedLog()
                expect(next.pendingEventPayloads()) == []
            }
        }
    }

    private func batchSpec() {
        describe("batches") {
            var store: SQLiteEventStore!
            beforeEach {
                store = SQLiteEventStore.temporary()
            }
            afterEach {
                store.deleteEverything()
            }

            it("assembles the events into one request body") {
                _ = store.stage(Self.payload("first"), bypassingCapacity: false)
                _ = store.stage(Self.payload("second"), bypassingCapacity: false)

                guard let batch = store.closeBatch()
                else { fail("expected a batch"); return }

                expect(store.body(of: batch)) == Data("""
                    [{"kind":"custom","key":"first"},{"kind":"custom","key":"second"}]
                    """.utf8)
            }

            it("has nothing to close when nothing was recorded") {
                expect(store.closeBatch()).to(beNil())
            }

            it("holds a batch until it is removed, so a failed delivery can be retried") {
                _ = store.stage(Self.payload("undelivered"), bypassingCapacity: false)
                guard let batch = store.closeBatch()
                else { fail("expected a batch"); return }

                expect(store.pendingBatches().map { $0.payloadId }) == [batch.payloadId]
                expect(store.body(of: batch)).toNot(beNil())

                store.remove(batch)

                expect(store.pendingBatches()) == []
                expect(store.body(of: batch)).to(beNil())
            }

            it("gives a batch its own payload id, so a retry is not read as a new delivery") {
                _ = store.stage(Self.payload("first"), bypassingCapacity: false)
                let first = store.closeBatch()
                _ = store.stage(Self.payload("second"), bypassingCapacity: false)
                let second = store.closeBatch()

                expect(first?.payloadId).toNot(equal(second?.payloadId))
            }

            it("keeps recording into a fresh batch after one is closed") {
                _ = store.stage(Self.payload("first"), bypassingCapacity: false)
                guard let first = store.closeBatch()
                else { fail("expected a batch"); return }

                _ = store.stage(Self.payload("second"), bypassingCapacity: false)
                store.commit()
                guard let second = store.closeBatch()
                else { fail("expected a second batch"); return }

                expect(store.body(of: first)) == Data("[{\"kind\":\"custom\",\"key\":\"first\"}]".utf8)
                expect(store.body(of: second)) == Data("[{\"kind\":\"custom\",\"key\":\"second\"}]".utf8)
            }
        }
    }

    private func capacitySpec() {
        describe("capacity") {
            var store: SQLiteEventStore!
            beforeEach {
                store = SQLiteEventStore.temporary(capacity: 3)
            }
            afterEach {
                store.deleteEverything()
            }

            it("refuses events once it is reached") {
                expect(store.stage(Self.payload("one"), bypassingCapacity: false)) == true
                expect(store.stage(Self.payload("two"), bypassingCapacity: false)) == true
                expect(store.stage(Self.payload("three"), bypassingCapacity: false)) == true
                expect(store.stage(Self.payload("four"), bypassingCapacity: false)) == false
            }

            it("counts the events in a batch that has not been delivered yet") {
                _ = store.stage(Self.payload("one"), bypassingCapacity: false)
                _ = store.stage(Self.payload("two"), bypassingCapacity: false)
                _ = store.closeBatch()

                expect(store.pendingEventCount) == 2
                expect(store.stage(Self.payload("three"), bypassingCapacity: false)) == true
                expect(store.stage(Self.payload("four"), bypassingCapacity: false)) == false
            }

            it("takes a summary even when it is full, since those evaluations were already counted") {
                for index in 0..<3 {
                    _ = store.stage(Self.payload("event-\(index)"), bypassingCapacity: false)
                }

                expect(store.stage(Self.payload("summary"), bypassingCapacity: true)) == true
            }
        }
    }

    private func schemaVersionSpec() {
        describe("a database written in a schema this version does not read") {
            it("is discarded rather than misread") {
                let store = SQLiteEventStore.temporary()
                defer { store.deleteEverything() }

                _ = store.stage(Self.payload("from-the-future"), bypassingCapacity: false)
                store.commit()

                // Stamped with a version no release will ever have, standing in for a database left by an SDK newer
                // than this one. D6: discarded, never parsed through the wrong shape.
                let path = store.directory.appendingPathComponent("events.sqlite").path
                var db: OpaquePointer?
                expect(sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil)) == SQLITE_OK
                sqlite3_exec(db, "PRAGMA user_version=9999", nil, nil, nil)
                sqlite3_close_v2(db)

                let next = Self.reader(sharing: store)
                expect(Self.keys(of: next)) == []
                expect(next.pendingBatches()) == []

                // And it is usable afterwards rather than left broken.
                _ = next.stage(Self.payload("after"), bypassingCapacity: false)
                next.commit()
                expect(Self.keys(of: Self.reader(sharing: store))) == ["after"]
            }
        }
    }

    private func interchangeabilitySpec() {
        describe("against the log store") {
            it("produces a byte-identical request body for the same events") {
                let log = EventStore.temporary()
                let sqlite = SQLiteEventStore.temporary()
                defer { log.deleteEverything(); sqlite.deleteEverything() }

                let events = (0..<25).map { Self.payload("event-\($0)") }
                for event in events {
                    _ = log.stage(event, bypassingCapacity: false)
                    _ = sqlite.stage(event, bypassingCapacity: false)
                }

                guard let logBatch = log.closeBatch(), let sqliteBatch = sqlite.closeBatch()
                else { fail("expected both stores to close a batch"); return }

                // The point of the experiment: the reporter cannot tell the two apart, and neither can LaunchDarkly.
                // The payload IDs differ -- they are meant to -- but the bytes on the wire do not.
                expect(sqlite.body(of: sqliteBatch)) == log.body(of: logBatch)
                expect(sqliteBatch.eventCount) == logBatch.eventCount
            }
        }
    }
}
#endif
