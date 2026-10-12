import Foundation

/// Stands in where the platform gave the SDK nowhere to write. Events are recorded and delivered from memory for the
/// life of the process, which is the behavior the SDK had before it kept a log.
final class NullEventStore: EventStoring {
    private let lock = UnfairLock()
    private var staged: [Data] = []
    private var reserved = 0
    /// Oldest first, as the store with a disk lists its batches, so that delivery goes in the order events were closed.
    private var closed: [(payloadId: String, events: [Data])] = []
    /// Closed batches whose request is out, which do not count against capacity.
    private var sending: Set<String> = []

    var pendingEventCount: Int {
        lock.withLock {
            reserved + staged.count + closed.reduce(0) { $0 + (sending.contains($1.payloadId) ? 0 : $1.events.count) }
        }
    }

    var isPersisting: Bool { false }

    func stage(_ encodedEvent: Data, bypassingCapacity: Bool) -> Bool {
        lock.withLock { staged.append(encodedEvent) }
        return true
    }

    func reserve(_ events: Int) {
        lock.withLock { reserved += events }
    }

    func stageReserved(_ encodedEvent: Data) -> Bool {
        lock.withLock {
            reserved = max(0, reserved - 1)
            staged.append(encodedEvent)
        }
        return true
    }

    func releaseReservations() {
        lock.withLock { reserved = 0 }
    }

    func commit() {
    }

    func closeBatch() -> EventBatch? {
        lock.withLock {
            guard !staged.isEmpty
            else { return nil }

            let payloadId = UUID().uuidString
            let events = staged
            staged = []
            closed.append((payloadId, events))
            return EventBatch(payloadId: payloadId, eventCount: events.count)
        }
    }

    func pendingBatches() -> [EventBatch] {
        lock.withLock { closed.map { EventBatch(payloadId: $0.payloadId, eventCount: $0.events.count) } }
    }

    func body(of batch: EventBatch) -> Data? {
        guard let events = lock.withLock({ closed.first { $0.payloadId == batch.payloadId }?.events })
        else { return nil }

        var body = Data("[".utf8)
        for (index, event) in events.enumerated() {
            if index > 0 {
                body.append(UInt8(ascii: ","))
            }
            body.append(event)
        }
        body.append(UInt8(ascii: "]"))
        return body
    }

    func remove(_ batch: EventBatch) {
        lock.withLock {
            closed.removeAll { $0.payloadId == batch.payloadId }
            sending.remove(batch.payloadId)
        }
    }

    func startedSending(_ batch: EventBatch) {
        lock.withLock {
            if closed.contains(where: { $0.payloadId == batch.payloadId }) {
                sending.insert(batch.payloadId)
            }
        }
    }

    func stoppedSending(_ batch: EventBatch) {
        _ = lock.withLock { sending.remove(batch.payloadId) }
    }

    func recoverInterruptedLog() {
    }
}
