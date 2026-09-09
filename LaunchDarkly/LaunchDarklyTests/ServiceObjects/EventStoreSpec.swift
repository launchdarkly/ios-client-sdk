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
        fallbackSpec()
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

    /// A store reading the same directory as another, standing in for the next run of the application: it sees only
    /// what actually reached the disk, which is the whole question a crash asks.
    private static func reader(sharing store: EventStore) -> EventStore {
        EventStore(directory: store.directory, capacity: 100, logger: .disabled)
    }

    private static func payload(_ key: String) -> Data {
        Data("{\"kind\":\"custom\",\"key\":\"\(key)\"}".utf8)
    }

    private static func keys(of store: EventStore) -> [String] {
        store.pendingEventPayloads().compactMap {
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

                expect(EventStoreSpec.keys(of: EventStoreSpec.reader(sharing: store))).to(beEmpty())
                expect(store.pendingEventCount) == 1
            }

            it("puts a committed event where another process would find it") {
                _ = store.stage(EventStoreSpec.payload("committed"))
                store.commit()

                expect(EventStoreSpec.keys(of: EventStoreSpec.reader(sharing: store))) == ["committed"]
            }

            it("commits without being asked once enough has been staged") {
                // No commit point is reached and nothing is flushed, so only the staging threshold can have written these.
                let event = EventStoreSpec.payload(String(repeating: "p", count: 1_024))
                for _ in 0..<32 {
                    _ = store.stage(event)
                }

                expect(EventStoreSpec.reader(sharing: store).pendingEventPayloads()).toEventuallyNot(beEmpty())
            }

            it("does not write on the thread that staged the event") {
                // Suspended, so any write this thread was going to cause is a write that cannot happen.
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                let deferring = EventStore.temporary(commitQueue: commits)
                // Resumed in the body rather than here: a queue resumed twice traps.
                defer { deferring.deleteEverything() }

                let event = EventStoreSpec.payload(String(repeating: "p", count: 1_024))
                for _ in 0..<64 {
                    _ = deferring.stage(event)
                }

                expect(EventStoreSpec.reader(sharing: deferring).pendingEventPayloads()).to(beEmpty())
                expect(deferring.pendingEventCount) == 64

                commits.resume()

                expect(EventStoreSpec.reader(sharing: deferring).pendingEventPayloads().count).toEventually(equal(64))
            }

            it("still writes on the caller's thread when the caller is at a commit point") {
                // The same suspended queue, to show a commit point does not depend on it: `commit()` is the caller's
                // guarantee that the event outlived them, so it cannot be handed to someone else.
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                let committing = EventStore.temporary(commitQueue: commits)
                defer {
                    commits.resume()
                    committing.deleteEverything()
                }

                _ = committing.stage(EventStoreSpec.payload("tracked"))
                committing.commit()

                expect(EventStoreSpec.keys(of: EventStoreSpec.reader(sharing: committing))) == ["tracked"]
            }

            it("keeps events in the order they were recorded") {
                for index in 0..<5 {
                    _ = store.stage(EventStoreSpec.payload("event-\(index)"))
                }
                store.commit()

                expect(EventStoreSpec.keys(of: EventStoreSpec.reader(sharing: store))) == ["event-0", "event-1", "event-2", "event-3", "event-4"]
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
                let next = EventStoreSpec.reader(sharing: store)
                next.recoverInterruptedLog()

                let batches = next.pendingBatches()
                expect(batches.count) == 1
                expect(batches.first?.eventCount) == 1
                expect(next.body(of: batches[0])) == Data("[{\"kind\":\"custom\",\"key\":\"survived\"}]".utf8)
            }

            it("leaves nothing behind when the log held no events") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("only"))
                store.commit()
                let batch = store.closeBatch()
                store.remove(batch!)

                let next = EventStoreSpec.reader(sharing: store)
                next.recoverInterruptedLog()

                expect(next.pendingBatches()).to(beEmpty())
                expect(next.pendingEventCount) == 0
            }
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
                let log = store.directory.appendingPathComponent("current")
                let whole = try Data(contentsOf: log)
                try whole.dropLast(8).write(to: log)

                expect(EventStoreSpec.keys(of: EventStoreSpec.reader(sharing: store))) == ["event-0", "event-1"]
            }

            it("is discarded when it was written in a format this version does not read") {
                store = EventStore.temporary()
                _ = store.stage(EventStoreSpec.payload("unreadable"))
                store.commit()
                _ = store.closeBatch()

                let batchUrl = try FileManager.default
                    .contentsOfDirectory(at: store.directory, includingPropertiesForKeys: nil)
                    .first { $0.lastPathComponent.hasPrefix("ready-") }
                var corrupted = try Data(contentsOf: batchUrl!)
                corrupted[4] = 0xFF
                corrupted[5] = 0xFF
                try corrupted.write(to: batchUrl!)

                let next = EventStoreSpec.reader(sharing: store)
                expect(next.pendingBatches()).to(beEmpty())
                // A batch that can never be delivered is not left to occupy the device either.
                expect(FileManager.default.fileExists(atPath: batchUrl!.path)) == false
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

                let body = store.body(of: batch!)
                expect(body) == Data("[{\"kind\":\"custom\",\"key\":\"first\"},{\"kind\":\"custom\",\"key\":\"second\"}]".utf8)
            }

            it("has nothing to close when nothing was recorded") {
                expect(store.closeBatch()).to(beNil())
            }

            it("holds a batch until it is removed, so a failed delivery can be retried") {
                _ = store.stage(EventStoreSpec.payload("retry-me"))
                let batch = store.closeBatch()!

                expect(store.pendingBatches()) == [batch]
                expect(store.pendingEventCount) == 1
                expect(store.body(of: batch)).toNot(beNil())

                store.remove(batch)

                expect(store.pendingBatches()).to(beEmpty())
                expect(store.pendingEventCount) == 0
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

            it("takes a summary even when it is full, since those evaluations were already counted") {
                store = EventStore.temporary(capacity: 1)

                expect(store.stage(EventStoreSpec.payload("first"))) == true
                expect(store.stage(EventStoreSpec.payload("summary"), bypassingCapacity: true)) == true
                expect(store.pendingEventCount) == 2
            }
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
                try? FileManager.default.removeItem(at: store.directory.deletingLastPathComponent())
            }

            it("delivers the events from memory rather than dropping them") {
                _ = store.stage(EventStoreSpec.payload("first"))
                _ = store.stage(EventStoreSpec.payload("second"))
                store.commit()

                // The commit had nowhere to go, so the events are still the store's to deliver.
                expect(store.pendingEventCount) == 2

                let batch = store.closeBatch()
                expect(batch?.eventCount) == 2
                expect(store.body(of: batch!))
                    == Data("[{\"kind\":\"custom\",\"key\":\"first\"},{\"kind\":\"custom\",\"key\":\"second\"}]".utf8)
            }

            it("produces the same body a batch on disk would have") {
                let written = EventStore.temporary()
                defer { written.deleteEverything() }
                _ = written.stage(EventStoreSpec.payload("same"))
                let onDisk = written.closeBatch()!

                _ = store.stage(EventStoreSpec.payload("same"))
                let held = store.closeBatch()!

                expect(store.body(of: held)) == written.body(of: onDisk)
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
                expect(store.body(of: batch))
                    == Data("[{\"kind\":\"custom\",\"key\":\"first\"},{\"kind\":\"custom\",\"key\":\"second\"}]".utf8)
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
                defer { try? FileManager.default.removeItem(at: bounded.directory.deletingLastPathComponent()) }

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
