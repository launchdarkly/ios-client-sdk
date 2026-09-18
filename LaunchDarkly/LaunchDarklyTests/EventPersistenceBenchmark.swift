import XCTest
import Foundation
#if os(watchOS)
@testable import LaunchDarkly_watchOS
#else
@testable import LaunchDarkly
#endif

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

#if canImport(SQLite3)
import SQLite3
#endif

/// Measures what recording an event costs, so the choices behind `EventStore` can be checked rather than assumed.
///
/// Skipped unless `LD_EVENT_BENCH=1`, because the durability figures spend seconds waiting on the disk on purpose and
/// nothing here asserts anything a regression would trip.
///
///     LD_EVENT_BENCH=1 xcrun xctest -XCTest LaunchDarklyTests.EventPersistenceBenchmark <bundle>
final class EventPersistenceBenchmark: XCTestCase {
    private func requireBenchmarking() throws {
        #if os(watchOS)
        // This file is compiled into the dedicated WatchEventBench scheme only.
        return
        #else
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LD_EVENT_BENCH"] == "1",
                          "Set LD_EVENT_BENCH=1 to measure event recording")
        #endif
    }

    /// The claim W3 rests on: taking a lock is cheap enough to do once per evaluation, and a queue hop is not.
    func testCriticalSectionCost() throws {
        try requireBenchmarking()

        let lock = UnfairLock()
        let queue = DispatchQueue(label: "com.launchdarkly.benchmark")
        var counter = 0

        report("critical section, uncontended", [
            ("UnfairLock lock/unlock", measure(iterations: 2_000_000) {
                lock.lock()
                counter += 1
                lock.unlock()
            }),
            ("DispatchQueue.sync", measure(iterations: 200_000) {
                queue.sync { counter += 1 }
            })
        ])

        // Contended, which is what concurrent evaluations actually do to it.
        report("critical section, 8 threads contending", [
            ("UnfairLock lock/unlock", measureConcurrent(threads: 8, iterationsPerThread: 200_000) {
                lock.lock()
                counter += 1
                lock.unlock()
            }),
            ("DispatchQueue.sync", measureConcurrent(threads: 8, iterationsPerThread: 20_000) {
                queue.sync { counter += 1 }
            })
        ])

        XCTAssertGreaterThan(counter, 0)
    }

    /// Why the store writes and does not sync: the gap between handing bytes to the kernel and insisting they are on
    /// the medium is three orders of magnitude, and only the second one survives losing the kernel.
    func testDurabilityPrimitiveCost() throws {
        try requireBenchmarking()

        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let descriptor = file.withUnsafeFileSystemRepresentation { open($0!, O_WRONLY | O_APPEND | O_CREAT, 0o600) }
        defer {
            close(descriptor)
            try? FileManager.default.removeItem(at: file)
        }
        XCTAssertGreaterThanOrEqual(descriptor, 0)

        let payload = [UInt8](repeating: 0x41, count: 512)

        var results: [(String, Double)] = [
            ("write(2), 512 bytes", measure(iterations: 200_000) {
                payload.withUnsafeBytes { _ = write(descriptor, $0.baseAddress, $0.count) }
            }),
            // One round, unlike everything else here. These wait on a disk rather than on the CPU, so the fastest
            // of several rounds would report the best case the hardware can do rather than what a commit costs,
            // and repeating them is slow for a figure that is only ever quoted as an order of magnitude.
            ("write(2) + fsync", measure(iterations: 500, rounds: 1) {
                payload.withUnsafeBytes { _ = write(descriptor, $0.baseAddress, $0.count) }
                _ = fsync(descriptor)
            })
        ]

        #if canImport(Darwin)
        results.append(("write(2) + F_FULLFSYNC", measure(iterations: 200, rounds: 1) {
            payload.withUnsafeBytes { _ = write(descriptor, $0.baseAddress, $0.count) }
            _ = fcntl(descriptor, F_FULLFSYNC)
        }))
        #endif

        report("making 512 bytes durable", results)
    }

    /// What the store adds to recording an event, separated from what serializing one costs.
    func testStoreCost() throws {
        try requireBenchmarking()

        let store = EventStore.temporary(capacity: .max)
        defer { store.deleteEverything() }
        let event = Data(#"{"kind":"feature","key":"benchmark-flag","value":true,"default":false,"variation":1,"version":7,"creationDate":1740000000000}"#.utf8)

        let stagedOnly = measure(iterations: 200_000) {
            _ = store.stage(event)
        }

        let committingStore = EventStore.temporary(capacity: .max)
        defer { committingStore.deleteEverything() }
        let committedEach = measure(iterations: 100_000) {
            _ = committingStore.stage(event)
            committingStore.commit()
        }

        report("appending one \(event.count) byte event", [
            ("stage, committed at the 16 KiB threshold", stagedOnly),
            ("stage + commit, every event", committedEach)
        ])
    }

    #if canImport(SQLite3)
    /// The same store contract kept in a SQLite table instead of an append-only log.
    ///
    /// The durability spec leaves the mechanism open (§13.2) and names a SQLite table as an alternative to be held
    /// against D1-D9 on its own terms. Correctness is `SQLiteEventStoreSpec`'s job; this prices it.
    ///
    /// The `synchronous` settings are the point of the comparison rather than a tuning knob. The log never syncs, so
    /// `OFF` is the setting that puts the durability boundary in the same place; `NORMAL` and `FULL` are here to show
    /// what moving that boundary costs.
    func testSQLiteStoreCost() throws {
        try requireBenchmarking()

        let event = Data(#"{"kind":"feature","key":"benchmark-flag","value":true,"default":false,"variation":1,"version":7,"creationDate":1740000000000}"#.utf8)

        // MARK: staging and committing

        var staging: [(String, Double)] = []
        var committing: [(String, Double)] = []

        let log = EventStore.temporary(capacity: .max)
        defer { log.deleteEverything() }
        staging.append(("append-only log", measure(iterations: 200_000) { _ = log.stage(event) }))

        let committingLog = EventStore.temporary(capacity: .max)
        defer { committingLog.deleteEverything() }
        committing.append(("append-only log", measure(iterations: 20_000) {
            _ = committingLog.stage(event)
            committingLog.commit()
        }))

        var toClean: [SQLiteEventStore] = []
        defer { toClean.forEach { $0.deleteEverything() } }

        for durability in [SQLiteEventStore.Durability.off, .normal, .full] {
            let staged = SQLiteEventStore.temporary(capacity: .max, durability: durability)
            toClean.append(staged)
            staging.append(("SQLite, synchronous=\(durability.rawValue)", measure(iterations: 200_000) {
                _ = staged.stage(event)
            }))

            let committed = SQLiteEventStore.temporary(capacity: .max, durability: durability)
            toClean.append(committed)
            committing.append(("SQLite, synchronous=\(durability.rawValue)", measure(iterations: 20_000) {
                _ = committed.stage(event)
                committed.commit()
            }))
        }

        report("staging one \(event.count) byte event, no write", staging)
        // What a commit point pays, and so what D1 costs: `track` is durable by the time it returns.
        report("stage + commit, every event", committing)

        // MARK: closing and reading a batch

        let logBatchStore = EventStore.temporary(capacity: .max)
        defer { logBatchStore.deleteEverything() }
        let sqlBatchStore = SQLiteEventStore.temporary(capacity: .max)
        toClean.append(sqlBatchStore)

        // Closing is measured per batch rather than per event: 50 events in, one close, repeated.
        let logClose = measure(iterations: 2_000) {
            for _ in 0..<50 { _ = logBatchStore.stage(event) }
            if let batch = logBatchStore.closeBatch() { logBatchStore.remove(batch) }
        }
        let sqlClose = measure(iterations: 2_000) {
            for _ in 0..<50 { _ = sqlBatchStore.stage(event) }
            if let batch = sqlBatchStore.closeBatch() { sqlBatchStore.remove(batch) }
        }
        report("closing and discarding a 50 event batch", [
            ("append-only log", logClose),
            ("SQLite, synchronous=NORMAL", sqlClose)
        ])

        // MARK: assembling a request body

        let logBody = EventStore.temporary(capacity: .max)
        defer { logBody.deleteEverything() }
        let sqlBody = SQLiteEventStore.temporary(capacity: .max)
        toClean.append(sqlBody)
        for _ in 0..<500 {
            _ = logBody.stage(event)
            _ = sqlBody.stage(event)
        }
        guard let logReady = logBody.closeBatch(), let sqlReady = sqlBody.closeBatch()
        else { return XCTFail("expected both stores to close a batch") }

        report("assembling the request body for a 500 event batch", [
            ("append-only log", measure(iterations: 2_000) { _ = logBody.body(of: logReady) }),
            ("SQLite, synchronous=NORMAL", measure(iterations: 2_000) { _ = sqlBody.body(of: sqlReady) })
        ])

        // MARK: does insert cost grow with the table?

        // An append is O(1) in what is already there; a B-tree insert is not. Whether that matters at the sizes a
        // capped event store reaches is the question, so the same insert is timed against a table that already holds
        // a hundred events and against one holding a hundred thousand.
        var byTableSize: [(String, Double)] = []
        for existing in [1_000, 100_000] {
            let store = SQLiteEventStore.temporary(capacity: .max)
            toClean.append(store)
            for _ in 0..<existing { _ = store.stage(event) }
            store.commit()

            byTableSize.append(("\(existing) rows already stored", measure(iterations: 20_000) {
                _ = store.stage(event)
                store.commit()
            }))
        }
        report("stage + commit against a table that already holds", byTableSize)

        // MARK: what it costs on disk

        let logBytes = EventStore.temporary(capacity: .max)
        defer { logBytes.deleteEverything() }
        let sqlBytes = SQLiteEventStore.temporary(capacity: .max)
        toClean.append(sqlBytes)
        for _ in 0..<10_000 {
            _ = logBytes.stage(event)
            _ = sqlBytes.stage(event)
        }
        logBytes.commit()
        sqlBytes.commit()

        print("10,000 events of \(event.count) bytes on disk")
        print("  append-only log             \(pad(bytesOnDisk(logBytes.directory))) (\(10_000 * event.count) bytes of payload)")
        print("  SQLite, synchronous=NORMAL  \(pad(bytesOnDisk(sqlBytes.directory)))")
        print("")
    }

    /// What a bulk of recordings costs, split by which thread pays for it.
    ///
    /// Every other figure here prices one call, which hides the thing that decides whether a store is affordable:
    /// neither store writes on the thread that staged an event. Both accumulate 16 KiB and then hand the write to a
    /// commit queue, so a row that times `stage` alone reports a memcpy and silently omits the write it caused. That
    /// omission is not the same size for the two, which is how the staging rows can make SQLite look an order of
    /// magnitude cheaper than the log while the commit rows have it an order of magnitude more expensive. Neither
    /// row is wrong; neither is the number an application pays.
    ///
    /// So this records a bulk the way an application would and prices both sides of the hand-off:
    ///
    /// - *caller thread* is wall time on the thread that recorded. It includes whatever the commit queue made it wait
    ///   for on `bufferLock`, because a real evaluation waits for that too.
    /// - *commit queue* is the CPU every other thread in the process burned while that was happening. Nothing else in
    ///   the process is doing anything, so this is mostly the commit queue and the write it is performing.
    ///
    /// **The hundred-event row is the noise floor of that second column.** A hundred events of this size never reach
    /// the 16 KiB threshold, so the true answer there is zero and whatever it reports is XCTest's own threads. This is
    /// inferred from process CPU rather than measured directly, because a `DispatchQueue` cannot be wrapped the way
    /// the Android benchmark wraps its `Executor`; reading the smallest row as the floor is what that costs. By ten
    /// thousand events the floor is a small fraction of the figure and the column can be taken at face value.
    ///
    /// Deliberately no `closeBatch` and no `remove`. Those run on the delivery queue once per flush interval -- 30
    /// seconds by default -- so folding them into a per-event figure answers a question nobody asked.
    func testCallerThreadCostOfABulk() throws {
        try requireBenchmarking()

        let event = Data(#"{"kind":"feature","key":"benchmark-flag","value":true,"default":false,"variation":1,"version":7,"creationDate":1740000000000}"#.utf8)

        // Three sizes, because the 16 KiB threshold is what decides whether there is any deferred work at all. A
        // hundred events of this size never reach it: nothing is written, and the whole cost is the caller's. A
        // thousand cross it about eight times and ten thousand about eighty. Reading the three together is what
        // separates a store that is genuinely cheap to stage into from one that has not paid for anything yet.
        for bulk in EventPersistenceBenchmark.bulkSizes {
            var results: [(String, BulkCost)] = []

            let logQueue = DispatchQueue(label: "com.launchdarkly.benchmark.logCommit")
            var log = EventStore.temporary(capacity: .max, commitQueue: logQueue)
            defer { log.deleteEverything() }
            results.append(("append-only log", measureBulk(iterations: bulk, newRound: {
                log.deleteEverything()
                log = EventStore.temporary(capacity: .max, commitQueue: logQueue)
                // Opens the descriptor outside the timed region, so the round's first event does not pay for it.
                _ = log.stage(event)
                log.commit()
            }, record: { _ in
                _ = log.stage(event)
            }, drain: {
                logQueue.sync { }
            })))

            #if canImport(SQLite3)
            var toClean: [SQLiteEventStore] = []
            defer { toClean.forEach { $0.deleteEverything() } }

            for durability in [SQLiteEventStore.Durability.off, .normal, .full] {
                let queue = DispatchQueue(label: "com.launchdarkly.benchmark.sqlCommit")
                var store = SQLiteEventStore.temporary(capacity: .max, durability: durability, commitQueue: queue)
                results.append(("SQLite, synchronous=\(durability.rawValue)", measureBulk(iterations: bulk, newRound: {
                    toClean.append(store)
                    store = SQLiteEventStore.temporary(capacity: .max, durability: durability, commitQueue: queue)
                    // Opens the database outside the timed region, as the log opens its descriptor.
                    _ = store.stage(event)
                    store.commit()
                }, record: { _ in
                    _ = store.stage(event)
                }, drain: {
                    queue.sync { }
                })))
                toClean.append(store)
            }
            #endif

            reportBulk("recording \(count(bulk)) events, nothing delivered", results)
        }
    }

    /// What a commit point costs when it goes badly, rather than on average.
    ///
    /// `track` and `identify` commit on the caller's thread by design -- that is the durable barrier -- so this is the
    /// one figure here an application can observe as a stall. A mean hides what is worth knowing about a database:
    /// SQLite in WAL mode folds the write-ahead log back into the file every thousand pages, on whichever thread
    /// happens to be committing when the threshold is crossed. One unlucky `track` in a few hundred pays for all of
    /// them, and with `synchronous=NORMAL` that checkpoint is also where the deferred `fsync` finally happens.
    ///
    /// The log has no equivalent, because an append is an append. So if the asymmetry is real, it shows up as a
    /// maximum far from the median on the SQLite rows and close to it on the log's.
    func testCommitPointOutliers() throws {
        try requireBenchmarking()

        let event = Data(#"{"kind":"feature","key":"benchmark-flag","value":true,"default":false,"variation":1,"version":7,"creationDate":1740000000000}"#.utf8)

        // Swept over the same three sizes as the bulk figures, and here the sweep is the finding rather than a
        // convenience. A write-ahead log is checkpointed once it has filled, so a run short enough never reaches one
        // and reports a tail that does not exist. Each size gets a store of its own for the same reason: a database
        // inherited from the previous size would arrive with its log part-filled and charge the wrong run for it.
        for calls in EventPersistenceBenchmark.bulkSizes {
            var results: [(String, Distribution)] = []

            let log = EventStore.temporary(capacity: .max)
            defer { log.deleteEverything() }
            results.append(("append-only log", measureDistribution(iterations: calls) {
                _ = log.stage(event)
                log.commit()
            }))

            #if canImport(SQLite3)
            var toClean: [SQLiteEventStore] = []
            defer { toClean.forEach { $0.deleteEverything() } }

            for durability in [SQLiteEventStore.Durability.off, .normal, .full] {
                let store = SQLiteEventStore.temporary(capacity: .max, durability: durability)
                toClean.append(store)
                results.append(("SQLite, synchronous=\(durability.rawValue)", measureDistribution(iterations: calls) {
                    _ = store.stage(event)
                    store.commit()
                }))
            }
            #endif

            reportDistribution("one commit point, \(count(calls)) of them, on the caller's thread", results)
        }
    }

    /// Where the log's staging cost goes, given that the SQLite store's equivalent is an order of magnitude cheaper.
    ///
    /// The two stores stage differently on purpose: the log turns an event into a framed byte sequence on the spot,
    /// while the SQLite store keeps the event and does all of its work at commit. That is not a free choice either
    /// way -- the framing has to happen somewhere -- but it decides which thread pays for it, and staging is the part
    /// an evaluation pays on the caller's thread.
    func testStagingBreakdown() throws {
        try requireBenchmarking()

        let event = Data(#"{"kind":"feature","key":"benchmark-flag","value":true,"default":false,"variation":1,"version":7,"creationDate":1740000000000}"#.utf8)
        var sink = 0
        var buffer = Data()
        var array: [Data] = []

        let framing = measure(iterations: 500_000) {
            sink &+= EventLogFormat.frame(for: event).count
        }

        // Reset periodically so neither side is measured against a buffer growing into the tens of megabytes.
        let framingAndAppending = measure(iterations: 500_000) { iteration in
            if iteration.isMultiple(of: 1_000) { buffer.removeAll(keepingCapacity: true) }
            buffer.append(EventLogFormat.frame(for: event))
        }

        let arrayAppend = measure(iterations: 500_000) { iteration in
            if iteration.isMultiple(of: 1_000) { array.removeAll(keepingCapacity: true) }
            array.append(event)
        }

        report("staging one \(event.count) byte event, by step", [
            ("build the frame, discard it", framing),
            ("build the frame and append it to the buffer", framingAndAppending),
            ("append the event to an array (what SQLite stages)", arrayAppend)
        ])
        XCTAssertNotEqual(sink, -1)
    }

    /// Why closing a batch costs the log three times what it costs the SQLite store.
    ///
    /// Closing is the one operation the database wins outright, and the reason is not the database: the log's close
    /// is a sequence of filesystem *metadata* operations -- rename the open log, unlink the delivered batch, then
    /// recreate a descriptor -- and metadata is the expensive kind of filesystem work on APFS. The SQLite store
    /// mutates a file that is already open and never touches a directory entry.
    ///
    /// Two of these run per close and need not run at all: `descriptorForAppending()` recreates the directory and
    /// re-applies the backup exclusion every time the descriptor is reopened, which `closeBatch()` guarantees.
    ///
    /// One round each: these wait on the filesystem rather than the CPU, so the fastest of several is not the
    /// interesting number, and repeating them is slow.
    func testBatchCloseBreakdown() throws {
        try requireBenchmarking()

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = directory.appendingPathComponent("a")
        let second = directory.appendingPathComponent("b")
        FileManager.default.createFile(atPath: first.path, contents: Data("x".utf8))

        var results: [(String, Double)] = []

        results.append(("createDirectory, already exists", measure(iterations: 2_000, rounds: 1) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }))

        results.append(("setResourceValues, excluded from backup", measure(iterations: 2_000, rounds: 1) {
            var url = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }))

        results.append(("open(O_CREAT) + close", measure(iterations: 2_000, rounds: 1) {
            let opened = first.withUnsafeFileSystemRepresentation { path -> Int32 in
                guard let path = path else { return -1 }
                return open(path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
            }
            if opened >= 0 { close(opened) }
        }))

        // Alternating, so each iteration renames a file that is there and leaves one for the next. Measured both
        // through Foundation, which is what the store uses, and through the syscall it eventually reaches.
        results.append(("FileManager.moveItem", measure(iterations: 2_000, rounds: 1) { iteration in
            let from = iteration.isMultiple(of: 2) ? first : second
            let to = iteration.isMultiple(of: 2) ? second : first
            try? FileManager.default.moveItem(at: from, to: to)
        }))

        let firstPath = first.path
        let secondPath = second.path
        results.append(("rename(2)", measure(iterations: 2_000, rounds: 1) { iteration in
            let from = iteration.isMultiple(of: 2) ? firstPath : secondPath
            let to = iteration.isMultiple(of: 2) ? secondPath : firstPath
            _ = rename(from, to)
        }))

        let scratchPath = directory.appendingPathComponent("scratch").path
        results.append(("FileManager.createFile + removeItem", measure(iterations: 2_000, rounds: 1) {
            FileManager.default.createFile(atPath: scratchPath, contents: Data("x".utf8))
            try? FileManager.default.removeItem(atPath: scratchPath)
        }))

        results.append(("open(O_CREAT) + close + unlink(2)", measure(iterations: 2_000, rounds: 1) {
            let opened = open(scratchPath, O_WRONLY | O_CREAT, 0o600)
            if opened >= 0 { close(opened) }
            _ = unlink(scratchPath)
        }))

        report("filesystem operations a batch close pays for", results)
    }

    /// SQLite's own floor for one durable insert, with `SQLiteEventStore` taken out of the picture.
    ///
    /// Without this, the store's commit figures cannot be read: a reader is entitled to ask whether the gap against
    /// the log is SQLite or the wrapper around it, and whether it would close under tuning. This opens a raw
    /// connection and times `BEGIN/INSERT/COMMIT` through the C API directly, including the one pragma that would
    /// plausibly help and that D9 rules out.
    func testSQLiteFloorCost() throws {
        try requireBenchmarking()

        let payload = Data(#"{"kind":"feature","key":"benchmark-flag","value":true,"default":false,"variation":1,"version":7,"creationDate":1740000000000}"#.utf8)

        // `EXCLUSIVE` holds the file lock across transactions instead of taking it per commit. It is the obvious
        // tuning answer and it is not available here: D9 requires that two processes of one application -- an app and
        // its extension, both with a client for the same environment -- cannot corrupt each other's events, and an
        // exclusive lock means the second one simply cannot write.
        let configurations: [(String, [String])] = [
            ("WAL, synchronous=OFF", ["PRAGMA journal_mode=WAL", "PRAGMA synchronous=OFF"]),
            ("WAL, synchronous=NORMAL", ["PRAGMA journal_mode=WAL", "PRAGMA synchronous=NORMAL"]),
            ("WAL, OFF, locking_mode=EXCLUSIVE (D9 forbids)",
             ["PRAGMA journal_mode=WAL", "PRAGMA synchronous=OFF", "PRAGMA locking_mode=EXCLUSIVE"])
        ]

        var results: [(String, Double)] = []
        for (name, pragmas) in configurations {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            var db: OpaquePointer?
            guard sqlite3_open_v2(directory.appendingPathComponent("floor.sqlite").path, &db,
                                  SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK
            else { return XCTFail("could not open a database") }
            defer { sqlite3_close_v2(db) }

            for pragma in pragmas {
                sqlite3_exec(db, pragma, nil, nil, nil)
            }
            sqlite3_exec(db, "CREATE TABLE events (id INTEGER PRIMARY KEY AUTOINCREMENT, payload BLOB NOT NULL)", nil, nil, nil)

            var insert: OpaquePointer?
            guard sqlite3_prepare_v2(db, "INSERT INTO events (payload) VALUES (?)", -1, &insert, nil) == SQLITE_OK
            else { return XCTFail("could not prepare the insert") }
            defer { sqlite3_finalize(insert) }

            results.append((name, measure(iterations: 20_000) {
                sqlite3_exec(db, "BEGIN IMMEDIATE", nil, nil, nil)
                sqlite3_reset(insert)
                payload.withUnsafeBytes { raw in
                    sqlite3_bind_blob(insert, 1, raw.baseAddress, Int32(raw.count), nil)
                    _ = sqlite3_step(insert)
                }
                sqlite3_exec(db, "COMMIT", nil, nil, nil)
            }))
        }

        report("one insert committed on its own, raw SQLite", results)
    }

    private func bytesOnDisk(_ directory: URL) -> String {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory,
                                                                  includingPropertiesForKeys: [.fileSizeKey],
                                                                  options: [])) ?? []
        let total = files.reduce(0) { sum, file in
            sum + ((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return "\(total) bytes"
    }

    private func pad(_ value: String) -> String {
        value.count >= 12 ? value : String(repeating: " ", count: 12 - value.count) + value
    }
    #endif

    /// The figures that decide whether this is affordable: what an evaluation and a track cost end to end.
    func testRecordingCost() throws {
        try requireBenchmarking()

        let service = DarklyServiceMock()
        var config = LDConfig.stub
        config.eventCapacity = .max
        service.config = config

        let store = EventStore.temporary(capacity: .max)
        defer { store.deleteEverything() }
        let reporter = EventReporter(service: service, onSyncComplete: nil, store: store)
        let context = LDContext.stub()
        let trackedFlag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)
        let summaryOnlyFlag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: false)
        reporter.setLastEventResponseDate(Date())

        let summarized = measure(iterations: 100_000) {
            reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: summaryOnlyFlag, context: context, includeReason: false)
        }

        let tracked = measure(iterations: 50_000) {
            reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: trackedFlag, context: context, includeReason: false)
        }

        // A commit point: the summary of what came before it, the event itself, and the write that makes both durable.
        let commitPoint = measure(iterations: 20_000) { iteration in
            reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: summaryOnlyFlag, context: context, includeReason: false)
            reporter.record(CustomEvent(key: "benchmark-\(iteration)", context: context, data: nil))
        }

        report("recording, per call", [
            ("evaluation, summary only", summarized),
            ("evaluation, trackEvents on", tracked),
            ("evaluation + track (commit point)", commitPoint)
        ])
    }

    /// Where an evaluation's time actually goes, since serializing it is the one cost this design moves off the delivery
    /// thread and onto the caller's.
    func testSerializationCost() throws {
        try requireBenchmarking()

        let context = LDContext.stub()
        let flag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)

        let dateAsMillis: (Date, Encoder) throws -> Void = { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }

        let building = measure(iterations: 200_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            _ = event.kind
        }

        // Everything `EventReporter.encode` used to do per event: a fresh `JSONEncoder`, a `userInfo` dictionary
        // rebuilt from the configuration, and the array copy of the private attributes that goes into it. Measuring
        // only the `JSONEncoder()` allocation understates what reusing one is worth, because the dictionary and the
        // array are the larger half of the setup.
        let privateAttributes: [Reference] = []
        let buildingAndEncoding = measure(iterations: 100_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            let encoder = JSONEncoder()
            encoder.userInfo = [
                LDContext.UserInfoKeys.allAttributesPrivate: false,
                LDContext.UserInfoKeys.globalPrivateAttributes: privateAttributes.map { $0 }
            ]
            encoder.dateEncodingStrategy = .custom(dateAsMillis)
            _ = try? encoder.encode(event)
        }

        // The same work with the encoder built and configured once, which is what the reporter now does.
        let sharedEncoder = JSONEncoder()
        sharedEncoder.userInfo = [
            LDContext.UserInfoKeys.allAttributesPrivate: false,
            LDContext.UserInfoKeys.globalPrivateAttributes: privateAttributes.map { $0 }
        ]
        sharedEncoder.dateEncodingStrategy = .custom(dateAsMillis)
        let reusingEncoder = measure(iterations: 100_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            _ = try? sharedEncoder.encode(event)
        }

        report("preparing one feature event", [
            ("build the event only", building),
            ("build + encode, encoder per event", buildingAndEncoding),
            ("build + encode, encoder reused", reusingEncoder)
        ])
    }

    /// O3 from the encoding research: what replacing `Codable` with a hand-written writer actually buys.
    ///
    /// Measured across context shapes and privacy settings, because the research's open question is not whether a
    /// hand-written writer is faster but *where* the time goes. If the cost is the context walk and its redaction, the
    /// gap should stay roughly constant as contexts grow; if it is `Codable`'s container machinery, the gap should widen
    /// with the number of attributes encoded.
    func testHandWrittenEncoderCost() throws {
        try requireBenchmarking()

        let flag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)

        for (shapeName, context) in EventPersistenceBenchmark.contextShapes() {
            for (privacyName, allAttributesPrivate, globalPrivateAttributes) in EventPersistenceBenchmark.privacyShapes() {
                let codable = EventPersistenceBenchmark.makeCodableEncoder(allAttributesPrivate: allAttributesPrivate,
                                                                          globalPrivateAttributes: globalPrivateAttributes)
                let handWritten = EventJSONWriter(allAttributesPrivate: allAttributesPrivate,
                                                  globalPrivateAttributes: globalPrivateAttributes)

                let codableTime = measure(iterations: 50_000) {
                    let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
                    _ = try? codable.encode(event)
                }
                let handWrittenTime = measure(iterations: 50_000) {
                    let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
                    _ = handWritten.encode(event)
                }

                let bytes = handWritten.encode(FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false))?.count ?? 0

                report("encoding a feature event -- \(shapeName), \(privacyName), \(bytes) bytes out", [
                    ("Codable", codableTime),
                    ("hand-written", handWrittenTime),
                    ("saved", codableTime - handWrittenTime)
                ])
                print("  speedup                                   \(String(format: "%8.2fx", codableTime / handWrittenTime))")
            }
        }
    }

    /// The same comparison on the path a customer actually pays for, rather than on the encoder in isolation.
    func testRecordingCostByEncoder() throws {
        try requireBenchmarking()

        let context = LDContext.stub()
        let trackedFlag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)
        let summaryOnlyFlag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: false)

        var results: [(String, Double)] = []
        for (name, encoding) in [("Codable", EventReporter.Encoding.codable),
                                 ("hand-written", .handWritten),
                                 ("hand-written + cache", .handWrittenCachingContext)] {
            let service = DarklyServiceMock()
            var config = LDConfig.stub
            config.eventCapacity = .max
            service.config = config

            let store = EventStore.temporary(capacity: .max)
            defer { store.deleteEverything() }
            let reporter = EventReporter(service: service, onSyncComplete: nil, store: store, encoding: encoding)
            reporter.setLastEventResponseDate(Date())

            results.append(("\(name): evaluation, summary only", measure(iterations: 100_000) {
                reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: summaryOnlyFlag, context: context, includeReason: false)
            }))
            results.append(("\(name): evaluation, trackEvents on", measure(iterations: 50_000) {
                reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: trackedFlag, context: context, includeReason: false)
            }))
            reporter.contextCache?.resetCounters()
            results.append(("\(name): evaluation + track (commit point)", measure(iterations: 20_000) { iteration in
                reporter.recordFlagEvaluationEvents(flagKey: "benchmark-flag", value: true, defaultValue: false, featureFlag: summaryOnlyFlag, context: context, includeReason: false)
                reporter.record(CustomEvent(key: "benchmark-\(iteration)", context: context, data: nil))
            }))
            if let cache = reporter.contextCache {
                let total = cache.hits + cache.misses
                let rate = total == 0 ? 0 : 100 * Double(cache.hits) / Double(total)
                print("  \(name) at a commit point: \(cache.hits) hits / \(total) lookups (\(String(format: "%.1f", rate))%)")
            }
        }

        report("recording, per call, by encoder", results)
    }

    /// O2: reusing the last context's encoded bytes when the context has not changed.
    ///
    /// Measured at both ends of the hit rate, because the cache is only worth having if a miss costs close to nothing.
    /// What a hit pays on top of the lookup is `LDContext ==`, which `testContextCopyAndComparisonCost` prices
    /// separately for each way two equal contexts can be related.
    func testContextCacheCost() throws {
        try requireBenchmarking()

        let flag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)

        // The context to alternate with differs only in its key, so a miss costs the same encode as a hit would have.
        // Alternating between contexts of different sizes would price the other context, not the miss.
        for (shapeName, context, other) in EventPersistenceBenchmark.contextShapePairs() {
            let uncached = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
            let allHits = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [], cachingContexts: true)
            let allMisses = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [], cachingContexts: true)

            func event(_ carried: LDContext) -> FeatureEvent {
                FeatureEvent(key: "benchmark-flag", context: carried, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            }

            let uncachedTime = measure(iterations: 50_000) {
                _ = uncached.encode(event(context))
            }
            let hitTime = measure(iterations: 50_000) {
                _ = allHits.encode(event(context))
            }
            // Both sides of the miss comparison walk the same alternating sequence.
            let uncachedAlternating = measure(iterations: 50_000) { iteration in
                _ = uncached.encode(event(iteration.isMultiple(of: 2) ? context : other))
            }
            let missTime = measure(iterations: 50_000) { iteration in
                _ = allMisses.encode(event(iteration.isMultiple(of: 2) ? context : other))
            }

            report("hand-written encode -- \(shapeName)", [
                ("no cache", uncachedTime),
                ("cache, every event hits", hitTime),
                ("no cache, alternating contexts", uncachedAlternating),
                ("cache, every event misses", missTime),
                ("cost of a miss", missTime - uncachedAlternating)
            ])
            print("  speedup on a hit                          \(String(format: "%8.2fx", uncachedTime / hitTime))")
            print("  observed: \(allHits.contextCache?.hits ?? 0) hits all-hit, \(allMisses.contextCache?.hits ?? 0) hits alternating")
        }
    }

    /// What the per-event `JSONWriter` allocation costs, which is the cheapest of the memory questions to answer.
    func testWriterAllocationCost() throws {
        try requireBenchmarking()

        let context = LDContext.stub()
        let flag = FeatureFlag(flagKey: "benchmark-flag", value: true, variation: 1, flagVersion: 7, trackEvents: true)
        let writer = EventJSONWriter(allAttributesPrivate: false, globalPrivateAttributes: [])
        let reused = JSONWriter()

        let fresh = measure(iterations: 100_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            _ = writer.encode(event)
        }
        let reusing = measure(iterations: 100_000) {
            let event = FeatureEvent(key: "benchmark-flag", context: context, value: true, defaultValue: false, featureFlag: flag, includeReason: false, isDebug: false)
            _ = writer.encode(event, into: reused)
        }

        report("encoding a feature event, stub context", [
            ("a fresh JSONWriter per event", fresh),
            ("one JSONWriter reused", reusing),
            ("saved", fresh - reusing)
        ])
    }

    /// What it costs to copy a context and to compare two equal ones, which together decide whether the context cache
    /// is worth anything outside a benchmark.
    ///
    /// Three kinds of equal pair, because they are not the same question:
    /// - **shared storage**: one value assigned to another, so `Dictionary` and `Array` equality take the identity
    ///   fast path. This is what the cache benchmark measured, and it flatters the result.
    /// - **after `redactingAnonymousAttributes()`**: what the SDK actually hands to a feature event.
    /// - **independently built**: two equal contexts that share nothing, which is what an application that rebuilds
    ///   its context between evaluations produces. This is the case the cache's real-world value depends on.
    func testContextCopyAndComparisonCost() throws {
        try requireBenchmarking()

        var comparisons: [(String, Double)] = []
        var copies: [(String, Double)] = []

        for shape in ContextShape.allCases {
            let context = EventPersistenceBenchmark.makeContext(shape, key: "benchmark-key")
            let shared = context
            let redacting = context.redactingAnonymousAttributes()
            let rebuilt = EventPersistenceBenchmark.makeContext(shape, key: "benchmark-key")
                .redactingAnonymousAttributes()

            // Each pair must be equal, or the figures below measure an early exit rather than a comparison.
            XCTAssertEqual(context, shared, "\(shape.rawValue)")
            XCTAssertEqual(redacting, redacting, "\(shape.rawValue)")
            XCTAssertEqual(redacting, rebuilt, "\(shape.rawValue)")

            comparisons.append(("shared storage, \(shape.rawValue)", measure(iterations: 500_000) {
                _ = context == shared
            }))
            let alsoRedacting = context.redactingAnonymousAttributes()
            comparisons.append(("after redactingAnonymousAttributes, \(shape.rawValue)", measure(iterations: 500_000) {
                _ = redacting == alsoRedacting
            }))
            comparisons.append(("independently built, \(shape.rawValue)", measure(iterations: 200_000) {
                _ = redacting == rebuilt
            }))

            copies.append(("redactingAnonymousAttributes(), \(shape.rawValue)", measure(iterations: 500_000) {
                _ = context.redactingAnonymousAttributes()
            }))
        }

        report("comparing two equal contexts", comparisons)
        report("copying a context", copies)
    }

    // MARK: Corpus

    private static func makeCodableEncoder(allAttributesPrivate: Bool, globalPrivateAttributes: [Reference]) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.userInfo = [
            LDContext.UserInfoKeys.allAttributesPrivate: allAttributesPrivate,
            LDContext.UserInfoKeys.globalPrivateAttributes: globalPrivateAttributes.map { $0 }
        ]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.millisSince1970)
        }
        return encoder
    }

    private static func privacyShapes() -> [(String, Bool, [Reference])] {
        [("no redaction", false, []),
         ("1 global private", false, [Reference("email")]),
         ("all private", true, [])]
    }

    private enum ContextShape: String, CaseIterable {
        case keyOnly = "key only"
        case stub = "stub, 9 attributes"
        case wide = "20 flat attributes"
        case nested = "nested attributes"
        case multi = "multi-context"
    }

    /// Built from a key so the cache benchmark can make two contexts of identical shape that never compare equal.
    private static func makeContext(_ shape: ContextShape, key: String) -> LDContext {
        switch shape {
        case .keyOnly:
            let builder = LDContextBuilder(key: key)
            return (try? builder.build().get()) ?? LDContext.stub()
        case .stub:
            return LDContext.stub(key: key)
        case .wide:
            var builder = LDContextBuilder(key: key)
            builder.name("Wide")
            for index in 0..<20 {
                _ = builder.trySetValue("attribute\(index)", .string("value\(index)"))
            }
            return (try? builder.build().get()) ?? LDContext.stub()
        case .nested:
            var builder = LDContextBuilder(key: key)
            builder.name("Nested")
            _ = builder.trySetValue("address", ["street": "1 Main St", "city": "Springfield", "geo": ["lat": 1.5, "lon": -2.5]])
            _ = builder.trySetValue("tags", ["a", "b", "c", "d", "e"])
            return (try? builder.build().get()) ?? LDContext.stub()
        case .multi:
            var device = LDContextBuilder(key: "device-\(key)")
            device.kind("device")
            _ = device.trySetValue("os", ["name": "iOS", "version": 18])

            var builder = LDMultiContextBuilder()
            builder.addContext(LDContext.stub(key: key))
            builder.addContext((try? device.build().get()) ?? LDContext.stub())
            return (try? builder.build().get()) ?? LDContext.stub()
        }
    }

    private static func contextShapes() -> [(String, LDContext)] {
        ContextShape.allCases.map { ($0.rawValue, makeContext($0, key: "benchmark-key")) }
    }

    /// Each shape as a pair that costs the same to encode but never compares equal, for pricing a cache miss.
    private static func contextShapePairs() -> [(String, LDContext, LDContext)] {
        ContextShape.allCases.map { ($0.rawValue,
                                     makeContext($0, key: "benchmark-key"),
                                     makeContext($0, key: "benchmark-key-alternate")) }
    }

    // MARK: Harness

    /// How many times each timed loop is repeated; the fastest round is reported.
    ///
    /// Deliberately the same as the Android benchmark's, because the aggregation is what decides whether the two
    /// platforms' numbers can be put in one table. Reporting the mean of a single round on one platform and the
    /// fastest of five on the other would flatter the second by however much noise the first happened to catch.
    private static let rounds = 5

    /// The bulk sizes the recording figures are swept over.
    ///
    /// Chosen around the store's 16 KiB staging threshold rather than for being round. At the event size used here a
    /// hundred events stay under it and cause no write at all, a thousand cross it a handful of times, and ten
    /// thousand cross it often enough that the deferred column is an average rather than a report on one commit.
    /// The same three are used by the Android benchmark, so the two platforms' tables line up row for row.
    private static let bulkSizes = [100, 1_000, 10_000]

    /// How many recordings it takes for a bulk to settle, independent of how many the round then makes.
    ///
    /// The smallest bulk size is below it on purpose, which is exactly why this is not a share of the round.
    private static let bulkWarmup = 10_000

    private func measure(iterations: Int, rounds: Int = EventPersistenceBenchmark.rounds, _ body: () -> Void) -> Double {
        measure(iterations: iterations, rounds: rounds) { _ in body() }
    }

    /// Times `body`, returning nanoseconds per iteration: warmed, then run `rounds` times with the fastest round
    /// reported, since a descheduled thread or a page fault can only ever make a round slower.
    ///
    /// The warmup is a smaller share here than in the Android benchmark, which needs enough iterations to get the
    /// JIT to compile what it is measuring. Swift is compiled ahead of time and only needs the first allocation and
    /// page fault charged elsewhere.
    private func measure(iterations: Int, rounds: Int = EventPersistenceBenchmark.rounds, _ body: (Int) -> Void) -> Double {
        #if os(watchOS)
        let measuredIterations = max(1, iterations / 10)
        #else
        let measuredIterations = iterations
        #endif

        for iteration in 0..<max(1, measuredIterations / 100) {
            body(iteration)
        }

        var best = Double.greatestFiniteMagnitude
        for _ in 0..<max(1, rounds) {
            let start = monotonicNanoseconds()
            for iteration in 0..<measuredIterations {
                body(iteration)
            }
            let elapsed = monotonicNanoseconds() - start
            best = min(best, Double(elapsed) / Double(measuredIterations))
        }
        return best
    }

    private func measureConcurrent(threads: Int, iterationsPerThread: Int, _ body: () -> Void) -> Double {
        #if os(watchOS)
        let measuredIterations = max(1, iterationsPerThread / 10)
        #else
        let measuredIterations = iterationsPerThread
        #endif

        let start = monotonicNanoseconds()
        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            for _ in 0..<measuredIterations {
                body()
            }
        }
        let elapsed = monotonicNanoseconds() - start
        return Double(elapsed) / Double(threads * measuredIterations)
    }

    private func monotonicNanoseconds() -> UInt64 {
        var now = timespec()
        clock_gettime(CLOCK_MONOTONIC, &now)
        return UInt64(now.tv_sec) * 1_000_000_000 + UInt64(now.tv_nsec)
    }

    /// CPU burned by every thread in the process, which is how work handed to another queue is caught.
    private func processCpuNanoseconds() -> UInt64 {
        var now = timespec()
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &now)
        return UInt64(now.tv_sec) * 1_000_000_000 + UInt64(now.tv_nsec)
    }

    /// CPU burned by the calling thread alone. Subtracted from the process figure to leave the commit queue's share.
    private func threadCpuNanoseconds() -> UInt64 {
        var now = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &now)
        return UInt64(now.tv_sec) * 1_000_000_000 + UInt64(now.tv_nsec)
    }

    /// What one bulk of recordings cost, per event, split by which thread paid for it.
    private struct BulkCost {
        /// Wall time on the thread that recorded, which is what an application feels.
        let caller: Double
        /// CPU burned elsewhere in the process, which is the commit queue writing what the recordings staged.
        let deferred: Double

        var total: Double { caller + deferred }
    }

    /// Records `iterations` events per round, returning the cheapest round priced on both sides of the hand-off.
    ///
    /// `newRound` gets a fresh store. That matters more than it would for the other figures here: an append is O(1) in
    /// what the file already holds and a B-tree insert is not, so reusing one store across rounds would charge the
    /// later rounds for the earlier ones on exactly one of the two implementations being compared.
    private func measureBulk(iterations: Int,
                             rounds: Int = EventPersistenceBenchmark.rounds,
                             newRound: () -> Void,
                             record: (Int) -> Void,
                             drain: () -> Void) -> BulkCost {
        // Warmed against a store of its own, and outside the rounds. The first events a process records pay for page
        // faults and lazy allocation that no later one does, and at a hundred events per round there are not enough
        // of them for that to amortize away.
        //
        // A fixed count rather than a share of the round, for the reason the Android benchmark spells out: what it
        // takes to settle has nothing to do with how many events the round is about to record, and scaling the warmup
        // down with the round leaves the smallest size reporting the warmup.
        newRound()
        for iteration in 0..<EventPersistenceBenchmark.bulkWarmup {
            record(iteration)
        }
        drain()

        var best: BulkCost?

        for _ in 0..<max(1, rounds) {
            newRound()

            let startProcessCpu = processCpuNanoseconds()
            let startThreadCpu = threadCpuNanoseconds()
            let startWall = monotonicNanoseconds()
            for iteration in 0..<iterations {
                record(iteration)
            }
            let callerWall = monotonicNanoseconds() - startWall
            let callerCpu = threadCpuNanoseconds() - startThreadCpu

            // Drained inside the measured window, so that a commit still in flight when the loop ended is charged to
            // the queue rather than escaping the figure entirely.
            drain()
            let processCpu = processCpuNanoseconds() - startProcessCpu

            let round = BulkCost(caller: Double(callerWall) / Double(iterations),
                                 deferred: max(0, Double(processCpu) - Double(callerCpu)) / Double(iterations))
            if best == nil || round.total < best!.total {
                best = round
            }
        }
        return best ?? BulkCost(caller: 0, deferred: 0)
    }

    /// How long one call took, across many of them, when the tail is the point.
    private struct Distribution {
        let median: Double
        let mean: Double
        let p999: Double
        let worst: Double
    }

    /// Times every call rather than the enclosing loop, so the tail survives to be reported.
    ///
    /// One round, and the median rather than the fastest. Every other figure here reports the cheapest of several
    /// rounds, on the reasoning that noise can only make a round slower -- but here an outlier is the measurement, and
    /// that aggregation would throw away the answer.
    ///
    /// The warmup is a single call, where every other figure here warms proportionally. That is deliberate: the tail
    /// this is looking for appears only once enough commits have filled a write-ahead log, so a warmup generous enough
    /// to settle anything would be generous enough to spend the very budget being measured. One call is what it takes
    /// to get the file or the database open, and Swift is compiled ahead of time and needs no more.
    private func measureDistribution(iterations: Int, warmup: Int = 1, _ body: () -> Void) -> Distribution {
        for _ in 0..<max(0, warmup) {
            body()
        }

        var samples = [Double](repeating: 0, count: iterations)
        for index in 0..<iterations {
            let start = monotonicNanoseconds()
            body()
            samples[index] = Double(monotonicNanoseconds() - start)
        }

        let mean = samples.reduce(0, +) / Double(iterations)
        samples.sort()
        return Distribution(median: samples[iterations / 2],
                            mean: mean,
                            p999: samples[min(iterations - 1, (iterations * 999) / 1_000)],
                            worst: samples[iterations - 1])
    }

    private func report(_ title: String, _ results: [(String, Double)]) {
        let width = results.map { $0.0.count }.max() ?? 0
        print("\n\(title)")
        for (name, nanoseconds) in results {
            let padded = name.padding(toLength: width, withPad: " ", startingAt: 0)
            print("  \(padded)  \(format(nanoseconds))")
        }
    }

    /// Three columns rather than one, because the split is the whole point of the table.
    private func reportBulk(_ title: String, _ results: [(String, BulkCost)]) {
        let width = results.map { $0.0.count }.max() ?? 0
        print("\n\(title), per event")
        print("  \(String(repeating: " ", count: width))  \(column("caller thread"))  \(column("commit queue"))  \(column("total"))")
        for (name, cost) in results {
            let padded = name.padding(toLength: width, withPad: " ", startingAt: 0)
            print("  \(padded)  \(format(cost.caller))  \(format(cost.deferred))  \(format(cost.total))")
        }
        print("")
    }

    private func reportDistribution(_ title: String, _ results: [(String, Distribution)]) {
        let width = results.map { $0.0.count }.max() ?? 0
        print("\n\(title)")
        print("  \(String(repeating: " ", count: width))  \(column("median"))  \(column("mean"))  \(column("p99.9"))  \(column("worst"))")
        for (name, distribution) in results {
            let padded = name.padding(toLength: width, withPad: " ", startingAt: 0)
            print("  \(padded)  \(format(distribution.median))  \(format(distribution.mean))  \(format(distribution.p999))  \(format(distribution.worst))")
        }
        print("")
    }

    /// Right-aligns a column heading over the fixed width `format` produces.
    private func column(_ title: String) -> String {
        String(repeating: " ", count: max(0, 11 - title.count)) + title
    }

    /// Renders a count with thousands separators, so a table title reads as a quantity rather than a code literal.
    private func count(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func format(_ nanoseconds: Double) -> String {
        if nanoseconds >= 1_000_000 {
            return String(format: "%8.2f ms", nanoseconds / 1_000_000)
        }
        if nanoseconds >= 1_000 {
            return String(format: "%8.2f µs", nanoseconds / 1_000)
        }
        return String(format: "%8.1f ns", nanoseconds)
    }
}
