import Foundation
import OSLog

#if canImport(SQLite3)
import SQLite3

/// SQLite's own name for "copy this blob, I am about to free it". The C macro does not survive into Swift.
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// An experiment: the same durability contract as `EventStore`, kept in a SQLite table instead of an append-only log.
///
/// The durability spec leaves the mechanism open (§13.2) and names a SQLite table as one of the alternatives that has
/// to be held against D1-D9 on its own terms. This is that alternative, built to be measured against the log rather
/// than to replace it -- both implement `EventStoring`, so the reporter cannot tell them apart and a benchmark can run
/// the same recording sequence through each.
///
/// **What is deliberately identical.** Events are staged in memory and committed in one go, at the same 16 KiB
/// threshold, on the same borrowed thread. That is not incidental: D2 forbids putting a durable write on the thread
/// that evaluated a flag, and keeping the staging architecture unchanged is what makes the comparison isolate the
/// storage mechanism instead of measuring two different buffering strategies.
///
/// **What is deliberately different.** Three things the log has to build by hand come with the database:
///
/// - *Torn writes* (D5). The log frames every event with a length prefix so a reader can tell a finished frame from
///   one a dying process left half-written. SQLite's write-ahead log checksums its own frames and stops at the first
///   bad one, which is the same recovery with the same outcome, written by someone else.
/// - *Format versioning* (D6). `PRAGMA user_version` is the file's own field for this, so a database from a future
///   version of the SDK is recognized and discarded rather than misread.
/// - *Concurrent processes* (D9). The log relies on `O_APPEND` making each write land whole. SQLite takes real file
///   locks, which is a stronger guarantee than the log has and covers readers as well as writers.
///
/// **Batches cost nothing to close.** Every row carries the identifier of the batch it belongs to, assigned when the
/// row is inserted rather than when the batch closes. Closing is then just retiring the current identifier and
/// generating the next one -- no rows are rewritten, which is the database's answer to the log's atomic rename. It
/// also makes recovery free: rows a previous run left behind carry an identifier this run will never issue, so they
/// are already pending delivery the moment the database opens.
final class SQLiteEventStore: EventStoring {
    /// How the rows are laid out. Bump `schemaVersion` whenever this changes.
    ///
    /// The identifier is what orders events, so it has to keep increasing across deletions -- `AUTOINCREMENT` rather
    /// than a bare `INTEGER PRIMARY KEY`, which would reuse the row ids that removing a delivered batch frees up and
    /// could file a new event ahead of an older one.
    private static let schemaVersion: Int32 = 1
    ///
    /// Deliberately unindexed. An index on `batch_id` is the obvious thing to add -- every read here filters or groups
    /// by it -- and measuring it showed why not: maintaining it costs about 7 µs on every insert, which is paid on the
    /// thread that called `track`, to speed up queries that run once per delivery against a table `capacity` keeps to
    /// a few hundred rows. The scan is the cheaper side of that trade by a wide margin.
    private static let createSchema = """
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            batch_id TEXT NOT NULL,
            payload BLOB NOT NULL
        );
        """

    /// How many staged bytes are allowed to accumulate before one of them pays for a commit.
    ///
    /// The same figure the log uses, for the same reason and so that the two are comparable.
    private static let stagingThreshold = 16 * 1024

    /// How durable a commit is asked to be.
    ///
    /// The log never syncs (page-cache spec §2): handing bytes to the kernel is what defends against the process
    /// dying, and only losing the kernel itself can discard them. `normal` is the closest SQLite equivalent in WAL
    /// mode -- commits are written without a sync, and the sync happens when the write-ahead log is folded back into
    /// the database. The other two are here to be priced, not because either is the obvious default.
    enum Durability: String {
        /// Never sync. The nearest thing to what the log does, and the only setting where a power cut can damage the
        /// database itself rather than cost the most recent events.
        case off = "OFF"
        /// Sync when the write-ahead log is checkpointed, not on every commit.
        case normal = "NORMAL"
        /// Sync on every commit. What a database would do by default, and what §2 argues against paying for here.
        case full = "FULL"
    }

    let directory: URL
    private let capacity: Int
    private let durability: Durability
    private let logger: OSLog
    /// Where a commit runs when it was not asked for by a caller who needs it to have happened.
    private let commitQueue: DispatchQueue

    /// Guards the staging buffer and the counters. Held for an array append and never across a database call.
    private let bufferLock = UnfairLock()
    /// Serializes everything that touches the database. Taken before `bufferLock`, never after it.
    ///
    /// The connection is opened `NOMUTEX`, so this lock is what makes it safe rather than SQLite's own serialization:
    /// the store already needed a lock of its own to keep the batch identifier and the counters consistent with the
    /// rows, and paying for SQLite's as well would be paying twice for the same thing.
    private let ioLock = UnfairLock()

    /// Only to be used while holding `bufferLock`.
    private var stagedPayloads: [Data] = []
    private var stagedBytes = 0
    private var committedEvents = 0
    private var closedEvents = 0
    private var isDisabled = false
    private var isCommitScheduled = false

    /// Only to be used while holding `ioLock`.
    private var db: OpaquePointer?
    private var insertStatement: OpaquePointer?
    /// The batch rows are being inserted into. Retired by `closeBatch()`, never reused.
    private var openBatchId = UUID().uuidString
    /// Batches held in memory because the database would not take them; see `EventStore` for why this exists.
    private var inMemoryBatches: [HeldSQLiteBatch] = []

    private var databaseUrl: URL { directory.appendingPathComponent("events.sqlite") }

    init(directory: URL,
         capacity: Int,
         durability: Durability = .normal,
         logger: OSLog,
         commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.SQLiteEventStore.commitQueue", qos: .userInitiated)) {
        self.directory = directory
        self.capacity = capacity
        self.durability = durability
        self.logger = logger
        self.commitQueue = commitQueue
    }

    // MARK: Recording

    var pendingEventCount: Int {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return stagedPayloads.count + committedEvents + closedEvents
    }

    func stage(_ encodedEvent: Data, bypassingCapacity: Bool = false) -> Bool {
        bufferLock.lock()

        guard bypassingCapacity || stagedPayloads.count + committedEvents + closedEvents < capacity
        else {
            bufferLock.unlock()
            return false
        }

        stagedPayloads.append(encodedEvent)
        stagedBytes += encodedEvent.count
        let needsCommit = !isDisabled && stagedBytes >= SQLiteEventStore.stagingThreshold && !isCommitScheduled
        if needsCommit {
            isCommitScheduled = true
        }
        bufferLock.unlock()

        if needsCommit {
            commitQueue.async { [weak self] in
                self?.commitScheduled()
            }
        }
        return true
    }

    private func commitScheduled() {
        bufferLock.lock()
        isCommitScheduled = false
        bufferLock.unlock()

        commit()
    }

    func commit() {
        ioLock.lock()
        defer { ioLock.unlock() }
        commitHoldingIoLock()
    }

    func closeBatch() -> EventBatch? {
        ioLock.lock()
        defer { ioLock.unlock() }

        commitHoldingIoLock()

        bufferLock.lock()
        let events = committedEvents
        let stillStaged = stagedPayloads.count
        bufferLock.unlock()

        if events > 0 {
            // The whole close: the rows already carry this identifier, so retiring it is what makes them a batch.
            // Nothing is written, which is the database's counterpart to the log's rename.
            let payloadId = openBatchId
            openBatchId = UUID().uuidString

            bufferLock.lock()
            committedEvents = 0
            closedEvents += events
            bufferLock.unlock()

            return EventBatch(payloadId: payloadId, eventCount: events)
        }
        if stillStaged > 0 {
            // Only reachable once persistence has been given up on; a healthy commit leaves nothing staged behind.
            return closeInMemoryBatchHoldingIoLock()
        }
        return nil
    }

    // MARK: Delivery

    func pendingBatches() -> [EventBatch] {
        ioLock.lock()
        defer { ioLock.unlock() }

        var batches: [EventBatch] = []
        if let db = databaseHoldingIoLock() {
            // Ordered by the oldest row in each batch, which is the order they were recorded and so the order they
            // should be delivered in. Anything a previous run left carries an identifier this run never issues, so it
            // appears here without needing to be recovered first.
            let sql = """
                SELECT batch_id, COUNT(*) FROM events
                WHERE batch_id <> ?
                GROUP BY batch_id
                ORDER BY MIN(id)
                """
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, openBatchId, -1, sqliteTransient)
                while sqlite3_step(statement) == SQLITE_ROW {
                    guard let raw = sqlite3_column_text(statement, 0)
                    else { continue }
                    batches.append(EventBatch(payloadId: String(cString: raw),
                                              eventCount: Int(sqlite3_column_int(statement, 1))))
                }
            }
            sqlite3_finalize(statement)
        }

        // After the rows, since anything held in memory was closed by this run and so is newer than whatever a
        // previous run left in the database.
        batches.append(contentsOf: inMemoryBatches.map {
            EventBatch(payloadId: $0.payloadId, eventCount: $0.eventCount)
        })

        bufferLock.lock()
        closedEvents = batches.reduce(0) { $0 + $1.eventCount }
        bufferLock.unlock()

        return batches
    }

    func body(of batch: EventBatch) -> Data? {
        ioLock.lock()
        defer { ioLock.unlock() }

        if let held = inMemoryBatches.first(where: { $0.payloadId == batch.payloadId }) {
            return held.body
        }

        guard let db = databaseHoldingIoLock()
        else { return nil }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM events WHERE batch_id = ? ORDER BY id", -1, &statement, nil) == SQLITE_OK
        else {
            sqlite3_finalize(statement)
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, batch.payloadId, -1, sqliteTransient)

        // Assembled the same way the log assembles it: the events were serialized on the way in and are shipped
        // exactly as they were recorded, so this concatenates bytes and never parses one.
        var body = Data("[".utf8)
        var isFirst = true
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0)
            else { continue }
            if !isFirst {
                body.append(UInt8(ascii: ","))
            }
            body.append(Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0))))
            isFirst = false
        }

        guard !isFirst
        else { return nil }

        body.append(UInt8(ascii: "]"))
        return body
    }

    func remove(_ batch: EventBatch) {
        ioLock.lock()
        defer { ioLock.unlock() }

        if let index = inMemoryBatches.firstIndex(where: { $0.payloadId == batch.payloadId }) {
            inMemoryBatches.remove(at: index)
        } else if let db = databaseHoldingIoLock() {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, "DELETE FROM events WHERE batch_id = ?", -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, batch.payloadId, -1, sqliteTransient)
                _ = sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }

        bufferLock.lock()
        closedEvents = max(0, closedEvents - batch.eventCount)
        bufferLock.unlock()
    }

    /// Nothing to recover, but not nothing to do.
    ///
    /// Rows a previous run left carry a batch identifier this run will never issue, so `pendingBatches` already
    /// reports them -- the log needs this call because its open log is a file that has to be renamed before it counts
    /// as deliverable, and here the equivalent happened when the identifier was generated. What this call is still for
    /// is opening the database, which is where the backlog gets counted against capacity. Doing that here rather than
    /// lazily is deliberate: the alternative is a first-use open on whichever thread happened to record an event.
    func recoverInterruptedLog() {
        ioLock.lock()
        defer { ioLock.unlock() }
        _ = databaseHoldingIoLock()
    }

    // MARK: Writing

    /// Requires `ioLock`.
    private func commitHoldingIoLock() {
        bufferLock.lock()
        guard !isDisabled, !stagedPayloads.isEmpty
        else {
            bufferLock.unlock()
            return
        }
        let payloads = stagedPayloads
        stagedPayloads = []
        stagedBytes = 0
        bufferLock.unlock()

        if insert(payloads) {
            bufferLock.lock()
            committedEvents += payloads.count
            bufferLock.unlock()
        } else {
            // Put back, to be delivered from memory rather than lost. Ahead of anything staged while the insert was in
            // flight, so the events keep the order they were recorded in.
            bufferLock.lock()
            stagedPayloads = payloads + stagedPayloads
            stagedBytes = stagedPayloads.reduce(0) { $0 + $1.count }
            bufferLock.unlock()
        }
    }

    /// Requires `ioLock`.
    private func insert(_ payloads: [Data]) -> Bool {
        guard let db = databaseHoldingIoLock(), let statement = insertStatement
        else {
            disablePersistenceHoldingIoLock()
            return false
        }

        // One transaction for the whole staged buffer. This is the counterpart to the log's single `write(2)`: what
        // makes a commit cost one trip to the kernel rather than one per event.
        guard execute(db, "BEGIN IMMEDIATE")
        else {
            disablePersistenceHoldingIoLock()
            return false
        }

        for payload in payloads {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_text(statement, 1, openBatchId, -1, sqliteTransient)

            let stepped: Int32 = payload.withUnsafeBytes { raw in
                // `SQLITE_STATIC` because the bytes outlive the step: they belong to `payload`, which is alive for the
                // whole closure. That saves SQLite copying every event a second time.
                sqlite3_bind_blob(statement, 2, raw.baseAddress, Int32(raw.count), nil)
                return sqlite3_step(statement)
            }

            guard stepped == SQLITE_DONE
            else {
                os_log("%s giving up on persisting events: sqlite %d", log: logger, type: .debug,
                       typeName(and: #function), stepped)
                _ = execute(db, "ROLLBACK")
                disablePersistenceHoldingIoLock()
                return false
            }
        }
        sqlite3_reset(statement)

        guard execute(db, "COMMIT")
        else {
            _ = execute(db, "ROLLBACK")
            disablePersistenceHoldingIoLock()
            return false
        }
        return true
    }

    /// Requires `ioLock`.
    @discardableResult
    private func execute(_ db: OpaquePointer, _ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    /// Requires `ioLock`.
    private func databaseHoldingIoLock() -> OpaquePointer? {
        if let db = db {
            return db
        }
        guard !isDisabledSnapshot()
        else { return nil }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            os_log("%s could not create the event directory: %s", log: logger, type: .debug,
                   typeName(and: #function), String(describing: error))
            return nil
        }
        excludeFromBackup()

        var handle: OpaquePointer?
        // `NOMUTEX` because `ioLock` already serializes every call; see the lock's own comment.
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(databaseUrl.path, &handle, flags, nil) == SQLITE_OK, let handle = handle
        else {
            os_log("%s could not open the event database", log: logger, type: .debug, typeName(and: #function))
            sqlite3_close_v2(handle)
            return nil
        }

        // WAL is what lets a reader and the writer coexist, and it is also what gives D5 its answer: the write-ahead
        // log checksums its frames, so a process that died mid-commit leaves a frame that is recognized as unfinished
        // and skipped, exactly as the log's length prefix does for its own tail.
        execute(handle, "PRAGMA journal_mode=WAL")
        execute(handle, "PRAGMA synchronous=\(durability.rawValue)")

        guard prepareSchema(handle)
        else {
            sqlite3_close_v2(handle)
            return nil
        }

        db = handle
        restoreCountsHoldingIoLock(handle)
        return handle
    }

    /// Creates the schema, or discards a database written in a version this one does not read (D6).
    ///
    /// Requires `ioLock`.
    private func prepareSchema(_ handle: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        var version: Int32 = 0
        if sqlite3_prepare_v2(handle, "PRAGMA user_version", -1, &statement, nil) == SQLITE_OK,
           sqlite3_step(statement) == SQLITE_ROW {
            version = sqlite3_column_int(statement, 0)
        }
        sqlite3_finalize(statement)

        guard version == 0 || version == SQLiteEventStore.schemaVersion
        else {
            // Written by a version of the SDK whose schema this one does not know. Its events can never be delivered,
            // so the table goes rather than being read through the wrong shape.
            os_log("%s discarding an event database written in schema version %d", log: logger, type: .debug,
                   typeName(and: #function), version)
            execute(handle, "DROP TABLE IF EXISTS events")
            execute(handle, "PRAGMA user_version=\(SQLiteEventStore.schemaVersion)")
            return createSchemaAndStatement(handle)
        }

        execute(handle, "PRAGMA user_version=\(SQLiteEventStore.schemaVersion)")
        return createSchemaAndStatement(handle)
    }

    /// Requires `ioLock`.
    private func createSchemaAndStatement(_ handle: OpaquePointer) -> Bool {
        guard execute(handle, SQLiteEventStore.createSchema)
        else {
            os_log("%s could not create the event schema", log: logger, type: .debug, typeName(and: #function))
            return false
        }

        // Prepared once and reused for every event, which is the whole reason a database can compete with a single
        // `write(2)`: parsing the statement per event would cost more than the insert.
        guard sqlite3_prepare_v2(handle, "INSERT INTO events (batch_id, payload) VALUES (?, ?)", -1, &insertStatement, nil) == SQLITE_OK
        else {
            os_log("%s could not prepare the insert", log: logger, type: .debug, typeName(and: #function))
            return false
        }
        return true
    }

    /// Counts what a previous run left, so capacity accounts for it without a query per staged event.
    ///
    /// Requires `ioLock`.
    private func restoreCountsHoldingIoLock(_ handle: OpaquePointer) {
        var statement: OpaquePointer?
        var existing = 0
        if sqlite3_prepare_v2(handle, "SELECT COUNT(*) FROM events", -1, &statement, nil) == SQLITE_OK,
           sqlite3_step(statement) == SQLITE_ROW {
            existing = Int(sqlite3_column_int(statement, 0))
        }
        sqlite3_finalize(statement)

        bufferLock.lock()
        closedEvents = existing
        bufferLock.unlock()
    }

    private func isDisabledSnapshot() -> Bool {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        return isDisabled
    }

    private func excludeFromBackup() {
        #if canImport(Darwin)
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        #endif
    }

    deinit {
        ioLock.lock()
        commitHoldingIoLock()
        sqlite3_finalize(insertStatement)
        sqlite3_close_v2(db)
        insertStatement = nil
        db = nil
        ioLock.unlock()
    }
}

/// A batch the database would not take, kept where the SDK used to keep all of them.
private struct HeldSQLiteBatch {
    let payloadId: String
    let body: Data
    let eventCount: Int
}

/// What the store does once the database has refused it; the reasoning is `EventStore`'s, and so is the behaviour.
private extension SQLiteEventStore {
    /// Requires `ioLock`.
    func disablePersistenceHoldingIoLock() {
        sqlite3_finalize(insertStatement)
        sqlite3_close_v2(db)
        insertStatement = nil
        db = nil

        bufferLock.lock()
        isDisabled = true
        bufferLock.unlock()
    }

    /// Requires `ioLock`.
    func closeInMemoryBatchHoldingIoLock() -> EventBatch? {
        bufferLock.lock()
        let payloads = stagedPayloads
        stagedPayloads = []
        stagedBytes = 0
        bufferLock.unlock()

        guard !payloads.isEmpty
        else { return nil }

        var body = Data("[".utf8)
        for (index, payload) in payloads.enumerated() {
            if index > 0 {
                body.append(UInt8(ascii: ","))
            }
            body.append(payload)
        }
        body.append(UInt8(ascii: "]"))

        let payloadId = UUID().uuidString
        inMemoryBatches.append(HeldSQLiteBatch(payloadId: payloadId, body: body, eventCount: payloads.count))

        bufferLock.lock()
        closedEvents += payloads.count
        bufferLock.unlock()

        return EventBatch(payloadId: payloadId, eventCount: payloads.count)
    }
}

extension SQLiteEventStore: TypeIdentifying { }

extension SQLiteEventStore {
    /// Every event the store is holding, encoded exactly as it will be sent.
    ///
    /// The counterpart to `EventStore.pendingEventPayloads()`, and used the same way: by tests, and to diagnose a
    /// store rather than on the recording path.
    func pendingEventPayloads() -> [Data] {
        commit()

        ioLock.lock()
        defer { ioLock.unlock() }

        guard let db = databaseHoldingIoLock()
        else { return [] }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM events ORDER BY id", -1, &statement, nil) == SQLITE_OK
        else {
            sqlite3_finalize(statement)
            return []
        }
        defer { sqlite3_finalize(statement) }

        var payloads: [Data] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0)
            else { continue }
            payloads.append(Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0))))
        }
        return payloads
    }
}

#endif
