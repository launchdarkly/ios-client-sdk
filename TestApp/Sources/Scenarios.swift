import Darwin
import Foundation
import LaunchDarkly

/// The event-loss and stress scenarios, the same ones the Android test app has.
///
/// The three exits record the same pair -- an evaluation, which is the exposure, and a track standing in for the error
/// an application reports just before it dies -- and then end the process a different way. What differs is how much
/// opportunity the SDK gets to deliver the pair first, so together they separate "delivered in time" from "was already
/// on disk".
@MainActor
enum Scenarios {
    static let defaultKillFlag = "kill-flag"
    static let overRefreshFlag = "trackevents-test"
    private static let errorEventKey = "$ld:telemetry:error"

    /// Enough evaluations past capacity for the average to settle, and few enough that a slow device finishes the tap
    /// promptly.
    private static let overCapacityEvaluations = 2000

    /// A batch holds at most 2 MiB, so seven of these fit in one and an eighth does not. Large events rather than many
    /// small ones, because the event capacity is reached long before small events fill a batch.
    private static let largeEventDataCharacters = 256 * 1024
    /// Seven, seven and six: three batches, the last of them not full.
    private static let largeEvents = 20

    /// Returns false where there is no client, in which case nothing was recorded and ending the process would
    /// demonstrate nothing.
    private static func recordExposureAndError(_ client: LDClient?, flagKey: String) -> Bool {
        guard let client
        else { return false }
        _ = client.boolVariation(forKey: flagKey, defaultValue: false)
        client.track(key: errorEventKey)
        return true
    }

    /// Records the pair, asks for a flush, and sends `SIGKILL` five seconds later.
    ///
    /// The control: the SDK gets an explicit flush and five seconds of runway, so the pair should arrive on this
    /// launch. Backgrounding or quitting would run the SDK's own delivery, so this kills the process instead.
    static func evalTrackFlushThenKill(_ client: LDClient?, flagKey: String) {
        guard recordExposureAndError(client, flagKey: flagKey)
        else { return }
        client?.flush()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            kill(getpid(), SIGKILL)
        }
    }

    /// Nothing at all between the track and the process dying: no flush, no delay for a timer to fire in, and
    /// `SIGKILL`, which cannot be caught, so no part of the SDK runs on the way out.
    ///
    /// Whether the pair is reported therefore says exactly one thing: whether recording it had already put it on disk.
    /// Under `.immediate` it should arrive on the next launch, not this one.
    static func evalTrackThenKillNow(_ client: LDClient?, flagKey: String) {
        guard recordExposureAndError(client, flagKey: flagKey)
        else { return }
        kill(getpid(), SIGKILL)
    }

    /// The same again, ending in a Swift runtime trap instead of a signal the process never sees.
    ///
    /// This is the shape a customer report takes: application code hits a fatal error immediately after reporting it.
    /// Unlike an uncaught exception on Android, a trap leaves nothing that could safely flush, so this behaves like
    /// the kill: the pair arrives on the next launch only if it was already on disk.
    static func evalTrackThenFatalErrorNow(_ client: LDClient?, flagKey: String) {
        guard recordExposureAndError(client, flagKey: flagKey)
        else { return }
        fatalError("Eval+Fatal: deliberate fatalError immediately after track, to test event persistence")
    }

    /// Reproduces the over-refresh pathology: a UI that re-evaluates one flag far more often than anything about it
    /// changed, against a flag whose events LaunchDarkly is tracking. Runs on the main thread, because that is where
    /// the loop it stands in for runs.
    ///
    /// The comparison between the two phases is the point rather than either number on its own. The first
    /// `eventCapacity` evaluations have room in the event store; every one after that is dropped, because nothing
    /// empties it until a flush. So the two phases costing the same per evaluation means the SDK is serializing events
    /// it then discards. A cost of a couple of microseconds instead means the flag has event tracking off, and this
    /// measured the summary counters rather than the thing in question.
    static func overRefreshEval(_ client: LDClient?, eventCapacity: Int) -> String? {
        guard let client
        else { return nil }
        let evaluate = { _ = client.boolVariation(forKey: overRefreshFlag, defaultValue: false) }
        let filling = averageMicroseconds(over: eventCapacity, evaluate)
        let overCapacity = averageMicroseconds(over: overCapacityEvaluations, evaluate)
        return String(format: "%@: %.0f µs/eval filling %d, %.0f µs/eval over capacity",
                      overRefreshFlag, filling, eventCapacity, overCapacity)
    }

    /// Records more events than one batch holds, so a flush sends several requests, each with a payload ID of its own.
    /// Offline, or followed by a kill, it leaves several `ready-` files on disk for the next launch to deliver. Each
    /// event's index is in its data, so the dashboard shows whether all of them arrived and none twice.
    static func fillBatches(_ client: LDClient?) -> String? {
        guard let client
        else { return nil }
        let padding = LDValue.string(String(repeating: "x", count: largeEventDataCharacters))
        for index in 1...largeEvents {
            client.track(key: "fill-batches", data: [
                "index": .number(Double(index)),
                "of": .number(Double(largeEvents)),
                "padding": padding,
            ])
        }
        return "Tracked \(largeEvents) × \(largeEventDataCharacters / 1024) KiB: 3 batches of at most 2 MiB"
    }

    private static func averageMicroseconds(over iterations: Int, _ body: () -> Void) -> Double {
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<iterations {
            body()
        }
        return Double(DispatchTime.now().uptimeNanoseconds - start) / 1000 / Double(iterations)
    }
}
