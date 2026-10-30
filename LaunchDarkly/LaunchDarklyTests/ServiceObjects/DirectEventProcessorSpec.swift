import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

class DirectEventProcessorSpec: QuickSpec {
    /// The persistence a `TestContext` gets where it names neither one nor a store. Immediate here, as the durable
    /// behaviour is what most of these are about; `DirectEventProcessorWithoutPersistenceSpec` runs them all again with
    /// it off, which is what an application gets.
    class var persistence: EventPersistence { .immediate }

    /// `persistence` of the spec whose examples are running, for the `TestContext` default, which cannot see the class.
    fileprivate static var runningPersistence: EventPersistence = .immediate

    /// Whether the spec runs with a disk, for examples whose subject is the disk.
    var persists: Bool { type(of: self).persistence != .disabled }

    struct Constants {
        static let eventFlushInterval: TimeInterval = 10.0
        static let eventFlushIntervalHalfSecond: TimeInterval = 0.5
        /// How long a flush or delivery may take before a test gives up on it. A wait ends as soon as what it waits
        /// for happens, so this costs a passing test nothing, and a loaded CI simulator can take over a second.
        static let deliveryTimeout: DispatchTimeInterval = .seconds(10)
    }

    /// Retries at once and never waits, so every flush posts: for tests about what is kept through failures rather than
    /// when it is posted again.
    static func withoutBackoff() -> DeliveryRetryState {
        DeliveryRetryState(initialDelay: 0, normalCeiling: 0, extendedCeiling: 0)
    }

    struct TestContext {
        var eventProcessor: DirectEventProcessor!
        var config: LDConfig!
        var context: LDContext!
        var serviceMock: DarklyServiceMock!
        var store: EventStore!
        var events: [Event] = []
        var lastEventResponseDate: Date
        var eventStubResponseDate: Date?
        var syncResult: SynchronizingError? = nil
        var diagnosticCache: DiagnosticCachingMock

        init(eventCount: Int = 0,
             eventFlushInterval: TimeInterval? = nil,
             lastEventResponseDate: Date = Date.distantPast,
             stubResponseSuccess: Bool = true,
             stubResponseOnly: Bool = false,
             stubResponseErrorOnly: Bool = false,
             eventStubResponseDate: Date? = nil,
             onSyncComplete: EventSyncCompleteClosure? = nil,
             store: EventStore? = nil,
             eventCapacity: Int = Event.Kind.allKinds.count,
             eventPersistence: EventPersistence? = nil,
             commitQueue: DispatchQueue = DispatchQueue(label: "com.launchdarkly.tests.DirectEventProcessor.commitQueue"),
             retryState: DeliveryRetryState? = nil) {

            config = LDConfig.stub
            config.eventCapacity = eventCapacity
            // A store a test brings decides, so the processor is never configured for a disk its store does not have.
            let persistence = eventPersistence
                ?? store.map { $0.isPersisting ? .immediate : .disabled }
                ?? DirectEventProcessorSpec.runningPersistence
            config.eventPersistence = persistence
            config.eventFlushInterval = eventFlushInterval ?? Constants.eventFlushInterval

            context = LDContext.stub()

            self.eventStubResponseDate = eventStubResponseDate?.adjustedForHttpUrlHeaderUse
            serviceMock = DarklyServiceMock()
            serviceMock.config = config
            serviceMock.stubEventResponse(success: stubResponseSuccess, responseOnly: stubResponseOnly, errorOnly: stubResponseErrorOnly, responseDate: self.eventStubResponseDate)

            diagnosticCache = DiagnosticCachingMock()
            serviceMock.diagnosticCache = diagnosticCache

            self.lastEventResponseDate = lastEventResponseDate.adjustedForHttpUrlHeaderUse
            self.store = store ?? EventStore.temporary(capacity: config.eventCapacity, persistEvents: persistence != .disabled)
            eventProcessor = DirectEventProcessor(service: serviceMock, onSyncComplete: onSyncComplete,
                                          store: self.store, commitQueue: commitQueue, retryState: retryState,
                                          pacing: .noWaits)
            (0..<eventCount).forEach {
                let event = Event.stub(Event.eventKind(for: $0), with: context!)
                events.append(event)
                eventProcessor.record(event)
            }
            eventProcessor.setLastEventResponseDate(self.lastEventResponseDate)
        }

        mutating func recordEvents(_ eventCount: Int) {
            for _ in 0..<eventCount {
                let event = Event.stub(Event.eventKind(for: events.count), with: context)
                events.append(event)
                eventProcessor.record(event)
            }
        }

        /// Commits everything accepted so far and returns its wire representation.
        func committedEvents() -> [LDValue] {
            eventProcessor.commitRecordedEvents()
            return store.pendingEventPayloads().compactMap { try? JSONDecoder().decode(LDValue.self, from: $0) }
        }

        /// The events recorded so far, in the JSON they encode to, for comparison with `committedEvents()`.
        func recordedEventsAsJSON() -> [LDValue] {
            events.compactMap { encodeToLDValue($0) }
        }

        /// Flushes, and answers whether a flush made from the completion got anywhere.
        ///
        /// A completion is free to flush again, which only works where it is not running on the queue deliveries go
        /// through: from there the delivery it asks for would be queued behind the completion asking for it. Waited
        /// on against a deadline, so a reporter answering on its own queue fails this rather than hanging the test
        /// process on a deadlock it can never leave.
        func flushedFromACompletion() -> Bool {
            var flushed = false
            waitUntil(timeout: .seconds(5)) { done in
                eventProcessor.flushReportingOutcome { _ in
                    let finished = DispatchSemaphore(value: 0)
                    eventProcessor.flush { finished.signal() }
                    flushed = finished.wait(timeout: .now() + 1) == .success
                    done()
                }
            }
            return flushed
        }

        /// Flushes and returns what the flush answered.
        func flushOutcome() -> Bool? {
            var delivered: Bool?
            // Long enough for a refused post and its retry a second later.
            waitUntil(timeout: .seconds(10)) { done in
                eventProcessor.flushReportingOutcome { result in
                    delivered = result
                    done()
                }
            }
            return delivered
        }

        func flushBypassingBackoffOutcome() -> Bool? {
            var delivered: Bool?
            waitUntil(timeout: .seconds(10)) { done in
                eventProcessor.flushBypassingBackoff { result in
                    delivered = result
                    done()
                }
            }
            return delivered
        }

        func cleanUp() {
            eventProcessor.isOnline = false
            store.deleteEverything()
        }
    }

    override func spec() {
        let persistence = type(of: self).persistence
        beforeEach { DirectEventProcessorSpec.runningPersistence = persistence }

        initSpec()
        isOnlineSpec()
        recordEventSpec()
        testRecordFlagEvaluationEvents()
        reportEventsSpec()
        unserializableEventSpec()
        privacySpec()
        reportTimerSpec()
        durabilitySpec()
        commitSpec()
        flushReportingOutcomeSpec()
        outageSpec()
        flagTrafficSpec()
        nullEventProcessorSpec()
        if !persists {
            withoutPersistenceSpec()
        }
    }

    /// The situations where holding events only in memory is hardest, which the examples shared with persistence do
    /// not set out to reach.
    private func withoutPersistenceSpec() {
        describe("without persistence") {
            var testContext: TestContext!
            afterEach {
                testContext?.cleanUp()
                testContext = nil
            }

            /// The custom event keys LaunchDarkly took, once per payload ID however often it was sent, in the order taken.
            func acceptedKeys() -> [String] {
                let mock = testContext.serviceMock!
                var payloadIds = Set<String>()
                var keys: [String] = []
                for (index, status) in mock.publishedEventStatuses.enumerated() where status == 202 {
                    if payloadIds.insert(mock.publishedPayloadIds[index]).inserted {
                        keys += customKeys(mock.publishedEventPayloads[index])
                    }
                }
                return keys
            }

            func record(_ key: String) {
                testContext.eventProcessor.record(CustomEvent(key: key, context: testContext.context))
            }

            it("never works out where its directory is through refusals, a retry, deliveries and a refusal that makes it wait") {
                let lock = UnfairLock()
                var located = 0
                let store = EventStore(locatingDirectory: {
                                           lock.withLock { located += 1 }
                                           return FileManager.default.temporaryDirectory
                                               .appendingPathComponent("com.launchdarkly.tests.events", isDirectory: true)
                                               .appendingPathComponent(UUID().uuidString, isDirectory: true)
                                       },
                                       capacity: Event.Kind.allKinds.count,
                                       persistEvents: false,
                                       logger: .disabled)
                // Refused and refused again on the retry; then the batch held from that and the next one are accepted;
                // then the service says the key is no good, after which nothing is posted for a while. The waits are
                // cut to milliseconds, which makes that while about four seconds.
                testContext = TestContext(store: store,
                                          retryState: DeliveryRetryState(initialDelay: 0.008, normalCeiling: 0.008, extendedCeiling: 3600))
                testContext.serviceMock.eventStatusForPost = { post in post <= 2 ? 503 : post <= 4 ? 202 : 401 }
                testContext.eventProcessor.isOnline = true

                record("refused")
                expect(testContext.flushOutcome()) == false
                record("accepted")
                expect(testContext.flushOutcome()) == true
                record("refused-for-good")
                expect(testContext.flushOutcome()) == false
                expect(testContext.eventProcessor.isOnline) == true
                record("while-waiting")
                testContext.eventProcessor.flush(completion: nil)
                waitLettingTimersFire(1.5)

                expect(testContext.serviceMock.publishEventDataCallCount) == 5
                expect(acceptedKeys()) == ["refused", "accepted"]
                testContext.eventProcessor.isOnline = false
                expect(lock.withLock { located }) == 0
            }

            it("keeps the oldest events up to capacity through an outage, and delivers each once in order") {
                // A batch refused twice used to be dropped. Now it waits in memory, still counted against capacity, so
                // an outage costs the newest events rather than the oldest and memory stays bounded however long it lasts.
                let capacity = 20
                testContext = TestContext(eventCapacity: capacity, retryState: DirectEventProcessorSpec.withoutBackoff())
                testContext.serviceMock.respondToEvents(with: 503)
                testContext.eventProcessor.isOnline = true

                (0..<10).forEach { record("e-\($0)") }
                expect(testContext.flushOutcome()) == false
                (10..<100).forEach { record("e-\($0)") }
                expect(testContext.flushOutcome()) == false

                testContext.serviceMock.stubEventResponse(success: true)
                testContext.serviceMock.eventStatusForPost = { _ in 202 }
                expect(testContext.flushOutcome()) == true

                expect(acceptedKeys()) == (0..<capacity).map { "e-\($0)" }
                expect(testContext.store.pendingEventCount) == 0
            }

            it("delivers each event once when it is recorded and flushed from many threads through refusals") {
                let recorders = 4
                let eventsEach = 150
                testContext = TestContext(eventCapacity: 100_000)
                // Every third post refused, so retries, batches held for the next delivery and flushes overlapping one
                // another all happen while the recorders are still going.
                testContext.serviceMock.eventStatusForPost = { post in post % 3 == 0 ? 503 : 202 }
                testContext.eventProcessor.isOnline = true
                let processor = testContext.eventProcessor!
                let context = testContext.context!

                let recorded = DispatchGroup()
                for recorder in 0..<recorders {
                    DispatchQueue.global().async(group: recorded) {
                        for index in 0..<eventsEach {
                            processor.record(CustomEvent(key: "r\(recorder)-\(index)", context: context))
                        }
                    }
                }
                let lock = UnfairLock()
                var recording = true
                let flusherDone = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    while lock.withLock({ recording }) {
                        processor.flush(completion: nil)
                        usleep(2_000)
                    }
                    flusherDone.signal()
                }
                expect(recorded.wait(timeout: .now() + 20)) == .success
                lock.withLock { recording = false }
                expect(flusherDone.wait(timeout: .now() + 5)) == .success

                testContext.serviceMock.eventStatusForPost = { _ in 202 }
                // Lets retries already scheduled land before the flush that has to take whatever is still held.
                waitLettingTimersFire(1.5)
                expect(testContext.flushOutcome()) == true

                let delivered = acceptedKeys()
                expect(Set(delivered).count).to(equal(delivered.count),
                                                description: "an event arrived under two payload IDs, so LaunchDarkly counts it twice")
                let expected = (0..<recorders).flatMap { recorder in (0..<eventsEach).map { "r\(recorder)-\($0)" } }
                expect(Set(delivered)) == Set(expected)
            }

            it("summarizes at most capacity contexts between deliveries, and starts over after each") {
                // Without a disk there are no commit points to drain the summarizer, so between two deliveries it
                // counts evaluations for at most capacity contexts and turns the rest away. Before the bound, evaluating
                // across many contexts while offline grew memory without limit.
                let capacity = 10
                testContext = TestContext(lastEventResponseDate: Date(), eventCapacity: capacity)
                testContext.eventProcessor.isOnline = true
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: false)

                for round in 0..<2 {
                    let posted = testContext.serviceMock.publishEventDataCallCount
                    for index in 0..<(capacity * 3) {
                        let context = LDContext.stub(key: "round-\(round)-context-\(index)")
                        testContext.eventProcessor.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b",
                                                                              featureFlag: flag, context: context, includeReason: false)
                    }
                    expect(testContext.flushOutcome()) == true

                    let summaries = testContext.serviceMock.publishedEventPayloads.dropFirst(posted).flatMap { body -> [LDValue] in
                        guard case .array(let events)? = try? JSONDecoder().decode(LDValue.self, from: body)
                        else { return [] }
                        return events.filter { $0.kindField == "summary" }
                    }
                    expect(summaries.count).to(equal(capacity), description: "round \(round)")
                }
            }
        }
    }

    private func flagTrafficSpec() {
        describe("giving way to flag values") {
            var testContext: TestContext!
            var nextRun: DirectEventProcessor?
            beforeEach {
                testContext = TestContext()
            }
            afterEach {
                nextRun?.isOnline = false
                nextRun = nil
                testContext.cleanUp()
            }

            /// A reporter on what a previous run left: `batches` batches of one event each.
            func nextRunLeft(_ batches: Int, pacing: DirectEventProcessor.Pacing) -> DirectEventProcessor {
                for _ in 0..<batches {
                    testContext.recordEvents(1)
                    testContext.eventProcessor.commitRecordedEvents()
                    _ = testContext.store.closeBatch()
                }
                let reporter = DirectEventProcessor(service: testContext.serviceMock, onSyncComplete: nil,
                                                    store: testContext.store.nextRun(), pacing: pacing)
                nextRun = reporter
                return reporter
            }

            /// When each of the first `count` posts was seen, or fewer where they did not all come in time.
            func postTimes(_ count: Int) -> [Date] {
                var times: [Date] = []
                let deadline = Date().addingTimeInterval(10)
                while times.count < count && Date() < deadline {
                    let posted = testContext.serviceMock.publishEventDataCallCount
                    while times.count < posted {
                        times.append(Date())
                    }
                    Thread.sleep(forTimeInterval: 0.005)
                }
                return times
            }

            itPersisting("sends what a previous run left only once the launch delay has passed after going online") {
                let reporter = nextRunLeft(1, pacing: DirectEventProcessor.Pacing(launchDelay: 0.8, gap: 0))
                let wentOnline = Date()

                reporter.isOnline = true

                Thread.sleep(forTimeInterval: 0.5)
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
                let times = postTimes(1)
                expect(times.count) == 1
                expect(times.first?.timeIntervalSince(wentOnline)) >= 0.75
            }

            itPersisting("counts the launch delay from going online rather than from the reporter starting") {
                let reporter = nextRunLeft(1, pacing: DirectEventProcessor.Pacing(launchDelay: 0.6, gap: 0))
                Thread.sleep(forTimeInterval: 0.8)

                reporter.isOnline = true

                Thread.sleep(forTimeInterval: 0.3)
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)
            }

            itPersisting("sends what a previous run left on a flush, without waiting for the launch gate") {
                let reporter = nextRunLeft(1, pacing: DirectEventProcessor.Pacing(launchDelay: 5, gap: 0))
                reporter.isOnline = true

                waitUntil(timeout: .seconds(3)) { done in
                    reporter.flush(completion: done)
                }

                expect(testContext.serviceMock.publishEventDataCallCount) == 1
            }

            itPersisting("sends what a previous run left a batch at a time, with a gap after each answer") {
                let reporter = nextRunLeft(3, pacing: DirectEventProcessor.Pacing(launchDelay: 0, gap: 0.4))

                reporter.isOnline = true

                let times = postTimes(3)
                expect(times.count) == 3
                for (earlier, later) in zip(times, times.dropFirst()) {
                    expect(later.timeIntervalSince(earlier)) >= 0.3
                }
            }

            itPersisting("sends the rest at once when a flush is asked for while pacing") {
                let reporter = nextRunLeft(3, pacing: DirectEventProcessor.Pacing(launchDelay: 0, gap: 10))
                reporter.isOnline = true
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                waitUntil(timeout: .seconds(3)) { done in
                    reporter.flush(completion: done)
                }

                expect(testContext.serviceMock.publishEventDataCallCount) == 3
            }

            itPersisting("stops a paced delivery on going offline, and keeps the rest") {
                let reporter = nextRunLeft(3, pacing: DirectEventProcessor.Pacing(launchDelay: 0, gap: 0.5))
                reporter.isOnline = true
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                reporter.isOnline = false
                Thread.sleep(forTimeInterval: 1.5)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1

                reporter.isOnline = true
                waitUntil(timeout: .seconds(3)) { done in
                    reporter.flush(completion: done)
                }
                expect(testContext.serviceMock.publishEventDataCallCount) == 3
            }

            it("holds what waits for the launch gate only where events persist") {
                let reporter = DirectEventProcessor(service: testContext.serviceMock, onSyncComplete: nil, store: testContext.store,
                                                    pacing: DirectEventProcessor.Pacing(launchDelay: 1, gap: 0))
                nextRun = reporter
                expect(reporter.givesWayToFlags) == self.persists
                let opened = UnfairLock()
                var hasOpened = false
                reporter.whenLaunchGateOpens { opened.withLock { hasOpened = true } }
                reporter.isOnline = true

                if self.persists {
                    Thread.sleep(forTimeInterval: 0.6)
                    expect(opened.withLock { hasOpened }) == false
                }

                expect(opened.withLock { hasOpened }).toEventually(beTrue(), timeout: .seconds(2))
            }

            itPersisting("does not let a report interval shorter than the launch delay send what a previous run left") {
                testContext = TestContext(eventFlushInterval: 0.1)
                let reporter = nextRunLeft(1, pacing: DirectEventProcessor.Pacing(launchDelay: 0.8, gap: 0))
                let wentOnline = Date()

                reporter.isOnline = true

                // Waited for on the run loop, which the report timer fires on.
                waitLettingTimersFire(0.5)
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)
                expect(Date().timeIntervalSince(wentOnline)) >= 0.75
            }

            itPersisting("keeps pacing a backlog through the report intervals that end during it") {
                testContext = TestContext(eventFlushInterval: 0.2)
                let reporter = nextRunLeft(2, pacing: DirectEventProcessor.Pacing(launchDelay: 0.2, gap: 1))

                reporter.isOnline = true

                // Waited for on the run loop, which the report timer fires on.
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)
                let first = Date()
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(2), timeout: .seconds(3))
                expect(Date().timeIntervalSince(first)) >= 0.8
            }
        }
    }

    /// An example whose subject is the disk, left out where the spec runs without one.
    private func itPersisting(_ description: String, file: FileString = #file, line: UInt = #line, closure: @escaping () throws -> Void) {
        guard persists
        else { return }
        it(description, file: file, line: line, closure: closure)
    }

    private func nullEventProcessorSpec() {
        describe("NullEventProcessor") {
            it("answers every flush off the caller's thread") {
                let reporter = NullEventProcessor()
                let caller = Thread.current
                let lock = UnfairLock()
                var answers: [(delivered: Bool, onCaller: Bool)] = []
                let record: (Bool) -> Void = { delivered in
                    lock.withLock { answers.append((delivered, Thread.current === caller)) }
                }

                // Events are off, so there is never anything to wait for. The threading a caller sees still must not
                // depend on that: one holding a lock its completion takes would deadlock only with events off.
                reporter.flush { record(true) }
                reporter.flushReportingOutcome(completion: record)

                expect(lock.withLock { answers.count }).toEventually(equal(2), timeout: Constants.deliveryTimeout)
                lock.withLock {
                    expect(answers.map { $0.delivered }) == [true, true]
                    expect(answers.contains { $0.onCaller }) == false
                }
            }
        }
    }

    private func initSpec() {
        describe("init") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
                testContext.eventProcessor = DirectEventProcessor(service: testContext.serviceMock, onSyncComplete: { _ in }, store: testContext.store, pacing: .noWaits)
            }
            it("starts offline without reporting events") {
                expect(testContext.eventProcessor.service) === testContext.serviceMock
                expect(testContext.eventProcessor.isOnline) == false
                expect(testContext.eventProcessor.isReportingActive) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
            }
        }
        describe("the byte capacity") {
            var config: LDConfig!
            beforeEach {
                config = LDConfig(mobileKey: LDConfig.Constants.mockMobileKey, autoEnvAttributes: .disabled)
            }
            it("is the whole of it for a single environment") {
                config.eventCapacityBytes = 2_400
                expect(DirectEventProcessor.shareOfCapacityBytes(config: config)) == 2_400
            }
            it("is shared equally by the configured environments") {
                config.eventCapacityBytes = 2_400
                try? config.setSecondaryMobileKeys(["second": "mob-second", "third": "mob-third", "fourth": "mob-fourth"])
                expect(DirectEventProcessor.shareOfCapacityBytes(config: config)) == 600
            }
            it("shares the default where none is set") {
                config.eventCapacityBytes = 0
                try? config.setSecondaryMobileKeys(["second": "mob-second"])
                expect(DirectEventProcessor.shareOfCapacityBytes(config: config)) == LDConfig.Defaults.eventCapacityBytes / 2
            }
            it("leaves each environment at least a byte") {
                config.eventCapacityBytes = 2
                try? config.setSecondaryMobileKeys(["second": "mob-second", "third": "mob-third"])
                expect(DirectEventProcessor.shareOfCapacityBytes(config: config)) == 1
            }
        }
    }

    private func isOnlineSpec() {
        describe("isOnline") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
            }
            afterEach {
                testContext.cleanUp()
            }
            context("online to offline") {
                beforeEach {
                    testContext.eventProcessor.isOnline = true

                    testContext.eventProcessor.isOnline = false
                }
                it("goes offline and stops reporting") {
                    expect(testContext.eventProcessor.isOnline) == false
                    expect(testContext.eventProcessor.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                }
            }
            context("offline to online") {
                context("with events") {
                    beforeEach {
                        testContext = TestContext(eventCount: Event.Kind.allKinds.count)

                        testContext.eventProcessor.isOnline = true
                    }
                    it("goes online and starts reporting") {
                        expect(testContext.eventProcessor.isOnline) == true
                        expect(testContext.eventProcessor.isReportingActive) == true
                        expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    }
                }
                context("without events") {
                    beforeEach {
                        testContext = TestContext()

                        testContext.eventProcessor.isOnline = true
                    }
                    it("goes online and starts reporting") {
                        expect(testContext.eventProcessor.isOnline) == true
                        expect(testContext.eventProcessor.isReportingActive) == true
                        expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    }
                }
            }
            context("online to online") {
                beforeEach {
                    testContext = TestContext()
                    testContext.eventProcessor.isOnline = true

                    testContext.eventProcessor.isOnline = true
                }
                it("stays online and continues reporting") {
                    expect(testContext.eventProcessor.isOnline) == true
                    expect(testContext.eventProcessor.isReportingActive) == true
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                }
            }
            context("offline to offline") {
                beforeEach {
                    testContext = TestContext(eventCount: Event.Kind.allKinds.count)

                    testContext.eventProcessor.isOnline = false
                }
                it("stays offline and does not start reporting") {
                    expect(testContext.eventProcessor.isOnline) == false
                    expect(testContext.eventProcessor.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.committedEvents()) == testContext.recordedEventsAsJSON()
                }
            }
        }
    }

    private func recordEventSpec() {
        describe("recordEvent") {
            var testContext: TestContext!
            context("event store empty") {
                beforeEach {
                    testContext = TestContext()
                    testContext.recordEvents(Event.Kind.allKinds.count) // Stub events, call testContext.eventProcessor.recordEvent, and keeps them in testContext.events
                }
                it("records events up to event capacity") {
                    expect(testContext.eventProcessor.isOnline) == false
                    expect(testContext.eventProcessor.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.committedEvents()) == testContext.recordedEventsAsJSON()
                }
                it("does not record a dropped event to diagnosticCache") {
                    expect(testContext.diagnosticCache.incrementDroppedEventCountCallCount) == 0
                }
            }
            context("event store full") {
                var extraEvent: Event!
                beforeEach {
                    testContext = TestContext(eventCount: Event.Kind.allKinds.count)
                    extraEvent = Event.stub(.feature, with: testContext.context)

                    testContext.eventProcessor.record(extraEvent)
                }
                it("doesn't record any more events") {
                    expect(testContext.eventProcessor.isOnline) == false
                    expect(testContext.eventProcessor.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.committedEvents()) == testContext.recordedEventsAsJSON()
                }
                it("records a dropped event to diagnosticCache") {
                    expect(testContext.diagnosticCache.incrementDroppedEventCountCallCount) == 1
                }
            }
        }
    }

    /// An event holding a NaN or infinite number cannot be serialized by either encoder. It is dropped, and
    /// the events beside it and after it are still delivered.
    private func unserializableEventSpec() {
        describe("unserializable events") {
            var serviceMock: DarklyServiceMock!
            var ldContext: LDContext!
            var reporter: DirectEventProcessor!
            var store: EventStore!

            func makeReporter(encoding: OutboundEventBuffer.Encoding) -> DirectEventProcessor {
                var config = LDConfig.stub
                config.eventCapacity = 8
                ldContext = LDContext.stub()
                serviceMock = DarklyServiceMock()
                serviceMock.config = config
                serviceMock.stubEventResponse(success: true)
                store = EventStore.temporary(capacity: config.eventCapacity)
                return DirectEventProcessor(service: serviceMock, onSyncComplete: nil, store: store, encoding: encoding, pacing: .noWaits)
            }

            afterEach {
                reporter?.isOnline = false
            }

            for encoding in [OutboundEventBuffer.Encoding.codable, .handWritten] {
                context("\(encoding): when an event holds a non-finite metric") {
                    beforeEach {
                        reporter = makeReporter(encoding: encoding)
                        reporter.isOnline = true
                    }
                    it("drops the poisoned batch and delivers a later event") {
                        waitUntil(timeout: Constants.deliveryTimeout) { done in
                            reporter.record(CustomEvent(key: "poison", context: ldContext, metricValue: .nan))
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 0
                        expect(store.pendingEventCount) == 0

                        waitUntil(timeout: Constants.deliveryTimeout) { done in
                            reporter.record(CustomEvent(key: "after-poison", context: ldContext, metricValue: 1.0))
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 1
                        let published = try JSONDecoder().decode(LDValue.self, from: serviceMock.publishedEventData!)
                        valueIsArray(published) { events in
                            expect(events.count) == 1
                            valueIsObject(events[0]) { body in
                                expect(body["key"]) == "after-poison"
                            }
                        }
                    }
                }

                context("\(encoding): when an event holds a non-finite metric beside a valid event") {
                    beforeEach {
                        reporter = makeReporter(encoding: encoding)
                        reporter.isOnline = true
                    }
                    it("drops only the poisoned event") {
                        waitUntil(timeout: Constants.deliveryTimeout) { done in
                            reporter.record(CustomEvent(key: "poison", context: ldContext, metricValue: .nan))
                            reporter.record(CustomEvent(key: "kept", context: ldContext, metricValue: 1.0))
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 1
                        let published = try JSONDecoder().decode(LDValue.self, from: serviceMock.publishedEventData!)
                        valueIsArray(published) { events in
                            expect(events.count) == 1
                            valueIsObject(events[0]) { body in
                                expect(body["key"]) == "kept"
                            }
                        }
                    }
                }

                context("\(encoding): when an event holds a non-finite summary beside a valid event") {
                    beforeEach {
                        reporter = makeReporter(encoding: encoding)
                        reporter.isOnline = true
                    }
                    it("drops only the poisoned summary") {
                        waitUntil(timeout: Constants.deliveryTimeout) { done in
                            reporter.recordFlagEvaluationEvents(flagKey: "poison-flag",
                                                                value: .number(.nan),
                                                                defaultValue: .number(0),
                                                                featureFlag: nil,
                                                                context: ldContext,
                                                                includeReason: false)
                            reporter.record(IdentifyEvent(context: ldContext))
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 1
                        let published = try JSONDecoder().decode(LDValue.self, from: serviceMock.publishedEventData!)
                        valueIsArray(published) { events in
                            expect(events.count) == 1
                            valueIsObject(events[0]) { body in
                                expect(body["kind"]) == "identify"
                            }
                        }
                    }
                }

                context("\(encoding): when an event holds a non-finite summary value") {
                    beforeEach {
                        reporter = makeReporter(encoding: encoding)
                        reporter.isOnline = true
                    }
                    it("drops the poisoned summary and delivers a later one") {
                        waitUntil(timeout: Constants.deliveryTimeout) { done in
                            reporter.recordFlagEvaluationEvents(flagKey: "poison-flag",
                                                                value: .number(.nan),
                                                                defaultValue: .number(0),
                                                                featureFlag: nil,
                                                                context: ldContext,
                                                                includeReason: false)
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 0
                        expect(store.pendingEventCount) == 0
                        expect(reporter.withContextSummarizer { $0.hasLoggedRequests }) == false

                        waitUntil(timeout: Constants.deliveryTimeout) { done in
                            reporter.recordFlagEvaluationEvents(flagKey: "after-poison",
                                                                value: .bool(true),
                                                                defaultValue: .bool(false),
                                                                featureFlag: nil,
                                                                context: ldContext,
                                                                includeReason: false)
                            reporter.flush(completion: done)
                        }
                        expect(serviceMock.publishEventDataCallCount) == 1
                        let published = try JSONDecoder().decode(LDValue.self, from: serviceMock.publishedEventData!)
                        valueIsArray(published) { events in
                            expect(events.count) == 1
                            valueIsObject(events[0]) { body in
                                expect(body["kind"]) == "summary"
                                valueIsObject(body["features"]) { features in
                                    expect(features["after-poison"]).toNot(beNil())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Context redaction as it reaches the payload the processor posts, configured through `LDConfig` as an application
    /// configures it, with each encoder.
    ///
    /// The encoder tests pin what redaction produces. These pin that the configuration reaches the encoder, which
    /// events inline a context and which of those also redact an anonymous context's attributes, and that a summary,
    /// which inlines the context it counted, is redacted like any other event. Android's `EventProcessorPrivacyTest`
    /// covers the same ground.
    private func privacySpec() {
        describe("context privacy") {
            var serviceMock: DarklyServiceMock!
            var reporter: DirectEventProcessor!
            var store: EventStore!

            let trackedFlag = FeatureFlag(flagKey: "flag-key", value: true, variation: 1, flagVersion: 2, trackEvents: true)

            func person() -> LDContext {
                var builder = LDContextBuilder(key: "user-key")
                builder.name("Sandy")
                _ = builder.trySetValue("email", "sandy@example.com")
                _ = builder.trySetValue("address", ["city": "Oakland", "street": "123 Main St"])
                return try! builder.build().get()
            }

            func makeReporter(_ encoding: OutboundEventBuffer.Encoding,
                              configure: (inout LDConfig) -> Void = { _ in }) -> DirectEventProcessor {
                var config = LDConfig.stub
                config.eventCapacity = 100
                configure(&config)
                serviceMock = DarklyServiceMock()
                serviceMock.config = config
                serviceMock.stubEventResponse(success: true)
                store = EventStore.temporary(capacity: config.eventCapacity)
                reporter = DirectEventProcessor(service: serviceMock, onSyncComplete: nil, store: store, encoding: encoding, pacing: .noWaits)
                reporter.isOnline = true
                return reporter
            }

            /// Records, flushes, and answers the events in the one request the flush posted.
            func posted(_ record: (DirectEventProcessor) -> Void) -> [[String: LDValue]] {
                record(reporter)
                waitUntil(timeout: Constants.deliveryTimeout) { done in reporter.flush(completion: done) }
                expect(serviceMock.publishEventDataCallCount) == 1
                guard let data = serviceMock.publishedEventData,
                      case .array(let events)? = try? JSONDecoder().decode(LDValue.self, from: data)
                else { return [] }
                return events.map(object)
            }

            func object(_ value: LDValue?) -> [String: LDValue] {
                guard case .object(let members)? = value
                else { return [:] }
                return members
            }

            func inlinedContext(ofKind kind: String, in events: [[String: LDValue]]) -> [String: LDValue] {
                object(events.first { $0["kind"] == .string(kind) }?["context"])
            }

            /// What a context reports as redacted, sorted so the comparison is stable.
            func redacted(_ context: [String: LDValue]) -> [String] {
                guard case .array(let names)? = object(context["_meta"])["redactedAttributes"]
                else { return [] }
                return names.compactMap { name -> String? in
                    guard case .string(let string) = name
                    else { return nil }
                    return string
                }.sorted()
            }

            afterEach {
                reporter?.isOnline = false
                store?.deleteEverything()
            }

            for encoding in [OutboundEventBuffer.Encoding.codable, .handWritten] {
                context("\(encoding)") {
                    it("redacts and reports an attribute the configuration names private") {
                        _ = makeReporter(encoding) { $0.privateContextAttributes = [Reference("email")] }
                        let delivered = inlinedContext(ofKind: "identify", in: posted { $0.record(IdentifyEvent(context: person())) })

                        expect(delivered["key"]) == "user-key"
                        expect(delivered["email"]).to(beNil())
                        expect(delivered["name"]) == "Sandy"
                        expect(redacted(delivered)) == ["email"]
                    }

                    it("leaves only the key and kind where every attribute is private") {
                        _ = makeReporter(encoding) { $0.allContextAttributesPrivate = true }
                        let delivered = inlinedContext(ofKind: "identify", in: posted { $0.record(IdentifyEvent(context: person())) })

                        expect(delivered["key"]) == "user-key"
                        expect(delivered["kind"]) == "user"
                        expect(delivered["name"]).to(beNil())
                        expect(delivered["email"]).to(beNil())
                        expect(delivered["address"]).to(beNil())
                        expect(redacted(delivered)) == ["address", "email", "name"]
                    }

                    it("reports each name as the reference that names it where every attribute is private") {
                        var builder = LDContextBuilder(key: "user-key")
                        _ = builder.trySetValue("/ssn", "123-45-6789")
                        _ = builder.trySetValue("/a~b", "secret")
                        _ = builder.trySetValue("c/d", "value")
                        let slashed = try! builder.build().get()
                        _ = makeReporter(encoding) { $0.allContextAttributesPrivate = true }
                        let delivered = inlinedContext(ofKind: "identify", in: posted { $0.record(IdentifyEvent(context: slashed)) })

                        expect(delivered["/ssn"]).to(beNil())
                        expect(redacted(delivered)) == ["/~1a~0b", "/~1ssn", "c/d"]
                    }

                    it("redacts only the property a private sub-attribute names") {
                        _ = makeReporter(encoding) { $0.privateContextAttributes = [Reference("/address/street")] }
                        let delivered = inlinedContext(ofKind: "identify", in: posted { $0.record(IdentifyEvent(context: person())) })

                        expect(object(delivered["address"])["city"]) == "Oakland"
                        expect(object(delivered["address"])["street"]).to(beNil())
                        expect(redacted(delivered)) == ["/address/street"]
                    }

                    it("redacts an attribute the context itself marks private") {
                        var builder = LDContextBuilder(key: "user-key")
                        builder.name("Sandy")
                        _ = builder.trySetValue("email", "sandy@example.com")
                        builder.addPrivateAttribute(Reference("email"))
                        let marked = try! builder.build().get()
                        _ = makeReporter(encoding)
                        let delivered = inlinedContext(ofKind: "identify", in: posted { $0.record(IdentifyEvent(context: marked)) })

                        expect(delivered["email"]).to(beNil())
                        expect(delivered["name"]) == "Sandy"
                        expect(redacted(delivered)) == ["email"]
                    }

                    it("redacts an anonymous context's attributes from a feature event but not an identify event") {
                        var builder = LDContextBuilder(key: "anon-key")
                        builder.anonymous(true)
                        _ = builder.trySetValue("email", "sandy@example.com")
                        let anonymous = try! builder.build().get()
                        _ = makeReporter(encoding)
                        let events = posted {
                            $0.record(IdentifyEvent(context: anonymous))
                            $0.recordFlagEvaluationEvents(flagKey: "flag-key", value: true, defaultValue: false,
                                                          featureFlag: trackedFlag, context: anonymous, includeReason: false)
                        }

                        // An identify event is the application deliberately registering this context.
                        expect(inlinedContext(ofKind: "identify", in: events)["email"]) == "sandy@example.com"
                        // A feature event redacts every attribute of an anonymous context unasked.
                        let feature = inlinedContext(ofKind: "feature", in: events)
                        expect(feature["key"]) == "anon-key"
                        expect(feature["email"]).to(beNil())
                        expect(redacted(feature)) == ["email"]
                    }

                    it("redacts the private attributes of the context a summary inlines") {
                        _ = makeReporter(encoding) { $0.privateContextAttributes = [Reference("email")] }
                        let events = posted {
                            $0.recordFlagEvaluationEvents(flagKey: "flag-key", value: true, defaultValue: false,
                                                          featureFlag: nil, context: person(), includeReason: false)
                        }

                        let summarized = inlinedContext(ofKind: "summary", in: events)
                        expect(summarized["key"]) == "user-key"
                        expect(summarized["email"]).to(beNil())
                        expect(redacted(summarized)) == ["email"]
                        expect(object(summarized["address"])["city"]) == "Oakland"
                    }

                    it("redacts every kind of a multi-context") {
                        var multi = LDMultiContextBuilder()
                        for (kind, email) in [("user", "sandy@example.com"), ("org", "billing@example.com")] {
                            var part = LDContextBuilder(key: "\(kind)-key")
                            part.kind(kind)
                            _ = part.trySetValue("email", .string(email))
                            multi.addContext(try! part.build().get())
                        }
                        let both = try! multi.build().get()
                        _ = makeReporter(encoding) { $0.privateContextAttributes = [Reference("email")] }
                        let delivered = inlinedContext(ofKind: "identify", in: posted { $0.record(IdentifyEvent(context: both)) })

                        expect(delivered["kind"]) == "multi"
                        for kind in ["user", "org"] {
                            expect(object(delivered[kind])["email"]).to(beNil(), description: kind)
                            expect(redacted(object(delivered[kind]))).to(equal(["email"]), description: kind)
                        }
                    }

                    it("posts no private value in any event") {
                        // Over the whole request body rather than one field, so that a private value cannot slip
                        // through in an event kind the tests above do not name.
                        _ = makeReporter(encoding) { $0.privateContextAttributes = [Reference("email")] }
                        let events = posted {
                            $0.record(IdentifyEvent(context: person()))
                            $0.record(CustomEvent(key: "an-event", context: person()))
                            $0.recordFlagEvaluationEvents(flagKey: "flag-key", value: true, defaultValue: false,
                                                          featureFlag: trackedFlag, context: person(), includeReason: false)
                        }

                        let kinds = events.compactMap { event -> String? in
                            guard case .string(let kind)? = event["kind"]
                            else { return nil }
                            return kind
                        }
                        expect(Set(kinds)) == ["identify", "custom", "feature", "summary"]
                        let body = String(data: serviceMock.publishedEventData ?? Data(), encoding: .utf8) ?? ""
                        expect(body.contains("sandy@example.com")) == false
                    }
                }
            }
        }
    }

    private func reportEventsSpec() {
        describe("reportEvents") {
            var testContext: TestContext!
            var eventStubResponseDate: Date!
            beforeEach {
                eventStubResponseDate = Date().addingTimeInterval(-TimeInterval(3))
            }
            afterEach {
                testContext.cleanUp()
            }
            let erOnline = {
                expect(testContext.eventProcessor.isOnline) == true
                expect(testContext.eventProcessor.isReportingActive) == true
            }
            context("online") {
                context("success") {
                    context("with events and tracked requests") {
                        beforeEach {
                            waitUntil(timeout: Constants.deliveryTimeout) { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventProcessor.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventProcessor.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventProcessor.flush(completion: nil)
                            }
                        }
                        it("reports events and a summary event") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == testContext.events.count + 1
                                expect(Array(valueArray.prefix(testContext.events.count))) == testContext.events.map { encodeToLDValue($0) }
                                valueIsObject(valueArray[testContext.events.count]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == Event.Kind.nonSummaryKinds.count + 1
                            expect(testContext.store.pendingEventCount) == 0
                            expect(testContext.eventProcessor.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventProcessor.withContextSummarizer { $0.hasLoggedRequests }) == false
                            expect(testContext.syncResult).to(beNil())
                        }
                    }
                    context("with events only") {
                        beforeEach {
                            waitUntil(timeout: Constants.deliveryTimeout) { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventProcessor.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.eventProcessor.flush(completion: nil)
                            }
                        }
                        it("reports events without a summary event") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            expect(published) == encodeToLDValue(testContext.events)
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == testContext.events.count
                            expect(testContext.store.pendingEventCount) == 0
                            expect(testContext.eventProcessor.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventProcessor.withContextSummarizer { $0.hasLoggedRequests }) == false
                            expect(testContext.syncResult).to(beNil())
                        }
                    }
                    context("with tracked requests only") {
                        beforeEach {
                            waitUntil(timeout: Constants.deliveryTimeout) { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventProcessor.isOnline = true
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventProcessor.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventProcessor.flush(completion: nil)
                            }
                        }
                        it("reports only a summary event") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == 1
                                valueIsObject(valueArray[0]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == 1
                            expect(testContext.store.pendingEventCount) == 0
                            expect(testContext.eventProcessor.lastEventResponseDate) == testContext.eventStubResponseDate
                            expect(testContext.eventProcessor.withContextSummarizer { $0.hasLoggedRequests }) == false
                            expect(testContext.syncResult).to(beNil())
                        }
                    }
                    context("without events or tracked requests") {
                        beforeEach {
                            waitUntil(timeout: Constants.deliveryTimeout) { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventProcessor.isOnline = true
                                testContext.eventProcessor.flush(completion: nil)
                            }
                        }
                        it("does not report events") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 0
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 0
                            expect(testContext.store.pendingEventCount) == 0
                            expect(testContext.eventProcessor.lastEventResponseDate) == Date.distantPast
                            expect(testContext.eventProcessor.withContextSummarizer { $0.hasLoggedRequests }) == false
                            expect(testContext.syncResult).to(beNil())
                        }
                    }
                    context("while a commit is stuck writing") {
                        it("takes the delivered batch out of the store before telling observers") {
                            let writeStarted = DispatchSemaphore(value: 0)
                            let finishWrite = DispatchSemaphore(value: 0)
                            let blockLock = NSLock()
                            var blockNextWrite = false
                            // A slow disk, holding the store's I/O, which removing a delivered batch also needs.
                            let store = EventStore.temporary(writeLog: { file, bytes in
                                blockLock.lock()
                                let blocks = blockNextWrite
                                blockNextWrite = false
                                blockLock.unlock()
                                if blocks {
                                    writeStarted.signal()
                                    finishWrite.wait()
                                }
                                return file.writeAll(bytes)
                            })
                            var pendingWhenTold: Int?
                            testContext = TestContext(onSyncComplete: { _ in
                                pendingWhenTold = store.pendingEventCount
                            }, store: store)
                            let reporter = testContext.eventProcessor!
                            let context = testContext.context!
                            reporter.isOnline = true
                            testContext.serviceMock.holdsEventCompletions = true
                            reporter.record(CustomEvent(key: "delivered", context: context))
                            reporter.flush(completion: nil)
                            expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                            blockLock.lock()
                            blockNextWrite = true
                            blockLock.unlock()
                            DispatchQueue.global().async {
                                reporter.record(CustomEvent(key: "written", context: context))
                            }
                            expect(writeStarted.wait(timeout: .now() + 2)) == .success
                            DispatchQueue.global().async {
                                testContext.serviceMock.releaseHeldEventCompletions()
                            }
                            // Long enough for an announcement made ahead of the removal to reach the main thread.
                            waitUntil(timeout: Constants.deliveryTimeout) { done in
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: done)
                            }
                            finishWrite.signal()

                            expect(pendingWhenTold).toEventuallyNot(beNil(), timeout: Constants.deliveryTimeout)
                            // Only the event still being written. The delivered one was gone before anyone heard.
                            expect(pendingWhenTold) == 1
                        }
                    }
                }
                context("failure") {
                    context("server error") {
                        beforeEach {
                            waitUntil(timeout: .seconds(10)) { syncComplete in
                                testContext = TestContext(stubResponseSuccess: false, eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventProcessor.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventProcessor.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventProcessor.flush(completion: nil)
                            }
                        }
                        it("keeps the events to retry after the failure") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 2 // 1 retry attempt
                            // The events are not lost by a failed delivery; they stay in the log, summary included,
                            // though only the full events count against capacity.
                            expect(testContext.store.pendingEventCount) == testContext.events.count
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == testContext.events.count + 1
                                expect(Array(valueArray.prefix(testContext.events.count))) == testContext.events.map { encodeToLDValue($0) }
                                valueIsObject(valueArray[testContext.events.count]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == Event.Kind.nonSummaryKinds.count + 1
                            expect(testContext.eventProcessor.lastEventResponseDate) == Date.distantPast
                            expect(testContext.eventProcessor.withContextSummarizer { $0.hasLoggedRequests }) == false
                            guard case let .request(error) = testContext.syncResult
                            else {
                                fail("Expected error result for event send")
                                return
                            }
                            expect(error as NSError?) == DarklyServiceMock.Constants.error
                        }
                    }
                    context("response only") {
                        beforeEach {
                            waitUntil(timeout: .seconds(10)) { syncComplete in
                                testContext = TestContext(stubResponseSuccess: false, stubResponseOnly: true, eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventProcessor.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventProcessor.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventProcessor.flush(completion: nil)
                            }
                        }
                        it("keeps the events to retry after the failure") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 2 // 1 retry attempt
                            // The events are not lost by a failed delivery; they stay in the log, summary included,
                            // though only the full events count against capacity.
                            expect(testContext.store.pendingEventCount) == testContext.events.count
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == testContext.events.count + 1
                                expect(Array(valueArray.prefix(testContext.events.count))) == testContext.events.map { encodeToLDValue($0) }
                                valueIsObject(valueArray[testContext.events.count]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == Event.Kind.nonSummaryKinds.count + 1
                            expect(testContext.eventProcessor.lastEventResponseDate) == Date.distantPast
                            expect(testContext.eventProcessor.withContextSummarizer { $0.hasLoggedRequests }) == false
                            let expectedError = testContext.serviceMock.errorEventHTTPURLResponse
                            guard case let .response(error) = testContext.syncResult
                            else {
                                fail("Expected error result for event send")
                                return
                            }
                            let httpError = error as? HTTPURLResponse
                            expect(httpError?.url) == expectedError?.url
                            expect(httpError?.statusCode) == expectedError?.statusCode
                        }
                    }
                    context("error only") {
                        beforeEach {
                            waitUntil(timeout: .seconds(10)) { syncComplete in
                                testContext = TestContext(stubResponseSuccess: false, stubResponseErrorOnly: true, eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                testContext.eventProcessor.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                // Track some flag evaluations to populate the contextSummarizer
                                testContext.eventProcessor.recordFlagEvaluationEvents(
                                    flagKey: "test-flag",
                                    value: .bool(true),
                                    defaultValue: .bool(false),
                                    featureFlag: nil,
                                    context: testContext.context,
                                    includeReason: false
                                )
                                testContext.eventProcessor.flush(completion: nil)
                            }
                        }
                        it("keeps the events to retry after the failure") {
                            erOnline()
                            expect(testContext.serviceMock.publishEventDataCallCount) == 2 // 1 retry attempt
                            // The events are not lost by a failed delivery; they stay in the log, summary included,
                            // though only the full events count against capacity.
                            expect(testContext.store.pendingEventCount) == testContext.events.count
                            let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                            valueIsArray(published) { valueArray in
                                expect(valueArray.count) == testContext.events.count + 1
                                expect(Array(valueArray.prefix(testContext.events.count))) == testContext.events.map { encodeToLDValue($0) }
                                valueIsObject(valueArray[testContext.events.count]) { summaryObject in
                                    expect(summaryObject["kind"]) == "summary"
                                }
                            }
                            expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 1
                            expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == Event.Kind.nonSummaryKinds.count + 1
                            expect(testContext.eventProcessor.lastEventResponseDate) == Date.distantPast
                            expect(testContext.eventProcessor.withContextSummarizer { $0.hasLoggedRequests }) == false
                            guard case let .request(error) = testContext.syncResult
                            else {
                                fail("Expected error result for event send")
                                return
                            }
                            expect(error as NSError?) == DarklyServiceMock.Constants.error
                        }
                    }
                    context("unexpected response") {
                        beforeEach {
                            waitUntil(timeout: .seconds(10)) { syncComplete in
                                testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                                    testContext.syncResult = result
                                    syncComplete()
                                })
                                let unauthorized = HTTPURLResponse(url: testContext.serviceMock.config.eventsUrl,
                                                                   statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                                                   httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                                   headerFields: nil)
                                testContext.serviceMock.stubbedEventResponse = (nil, unauthorized, nil, nil)
                                testContext.eventProcessor.isOnline = true
                                testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                                testContext.eventProcessor.flush(completion: nil)
                            }
                        }
                        it("keeps the events and keeps reporting, without retrying soon") {
                            // A valid key is sometimes refused for minutes during an incident, so the events wait for
                            // the longer backoff rather than being deleted with the SDK going quiet.
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                            expect(testContext.store.pendingEventCount) == testContext.events.count
                            expect(testContext.eventProcessor.isOnline).to(beTrue())
                            expect(testContext.eventProcessor.isReportingActive).to(beTrue())
                            if case let .response(error) = testContext.syncResult {
                                expect((error as? HTTPURLResponse)?.statusCode) == HTTPURLResponse.StatusCodes.unauthorized
                            } else {
                                fail("Expected response error result for event send")
                            }
                            waitLettingTimersFire(1.5)
                            expect(testContext.serviceMock.publishEventDataCallCount) == 1
                        }
                    }
                }
            }
            context("offline") {
                beforeEach {
                    waitUntil(timeout: Constants.deliveryTimeout) { syncComplete in
                        testContext = TestContext(eventStubResponseDate: eventStubResponseDate, onSyncComplete: { result in
                            testContext.syncResult = result
                            syncComplete()
                        })
                        testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                        // Track some flag evaluations to populate the contextSummarizer
                        testContext.eventProcessor.recordFlagEvaluationEvents(
                            flagKey: "test-flag",
                            value: .bool(true),
                            defaultValue: .bool(false),
                            featureFlag: nil,
                            context: testContext.context,
                            includeReason: false
                        )
                        testContext.eventProcessor.flush(completion: nil)
                    }
                }
                it("doesn't report events, but persists them") {
                    expect(testContext.eventProcessor.isOnline) == false
                    expect(testContext.eventProcessor.isReportingActive) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount) == 0
                    expect(testContext.eventProcessor.lastEventResponseDate) == Date.distantPast

                    // Being offline delays delivery, not durability: a flush is a commit point, so the recorded events and
                    // the evaluations counted so far are on disk even though nothing can be sent.
                    let pending = testContext.committedEvents()
                    expect(pending.dropLast().map { $0 }) == testContext.recordedEventsAsJSON()
                    expect(pending.last?.kindField) == "summary"
                    expect(testContext.eventProcessor.withContextSummarizer { $0.hasLoggedRequests }) == false
                    guard case .isOffline = testContext.syncResult
                    else {
                        fail("Expected error .isOffline result for event send")
                        return
                    }
                }
            }
        }
    }

    func testRecordFlagEvaluationEvents() {
        let context = LDContext.stub()
        let serviceMock = DarklyServiceMock()

        /// A reporter writing to a store of its own, and that store, so a test can read back what was recorded.
        func makeReporter() -> (DirectEventProcessor, EventStore) {
            let store = EventStore.temporary()
            return (DirectEventProcessor(service: serviceMock, onSyncComplete: nil, store: store, pacing: .noWaits), store)
        }

        describe("recordFlagEvaluationEvents") {
            it("counts an evaluation the summarizer turns away as dropped, and still keeps its full event") {
                var config = LDConfig.stub
                config.eventCapacity = 2
                let service = DarklyServiceMock()
                service.config = config
                let diagnosticCache = DiagnosticCachingMock()
                service.diagnosticCache = diagnosticCache
                let store = EventStore.temporary(capacity: config.eventCapacity)
                defer { store.deleteEverything() }
                let reporter = DirectEventProcessor(service: service, onSyncComplete: nil, store: store, pacing: .noWaits)
                let untracked = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: false)
                let tracked = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)

                // Capacity bounds the number of contexts counted as well as the number of events held.
                for key in ["a", "b"] {
                    reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: untracked, context: LDContext.stub(key: key), includeReason: false)
                }
                expect(diagnosticCache.incrementDroppedEventCountCallCount) == 0

                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: tracked, context: LDContext.stub(key: "c"), includeReason: false)

                expect(diagnosticCache.incrementDroppedEventCountCallCount) == 1
                expect(reporter.withContextSummarizer { $0.getSummaries() }.count) == 2
                reporter.commitRecordedEvents()
                expect(recordedEvents(store).compactMap { $0.kindField }) == ["feature", "summary", "summary"]
            }
            it("unknown flag") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: nil, context: context, includeReason: true)
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.withContextSummarizer { $0.hasLoggedRequests }) == true
                let summaries = reporter.withContextSummarizer { $0.getSummaries() }
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: nil, version: nil)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: nil, version: nil)]?.value) == "a"
            }
            it("untracked flag") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false)
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.withContextSummarizer { $0.hasLoggedRequests }) == true
                let summaries = reporter.withContextSummarizer { $0.getSummaries() }
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("tracked flag") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                let expected = FeatureEvent(key: "flag-key", context: context, value: "a", defaultValue: "b", featureFlag: flag, includeReason: true, isDebug: false)
                expect(expectedEvents(reporter.pendingEventsForTesting)) == expectedEvents([expected])
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.withContextSummarizer { $0.hasLoggedRequests }) == true
                let summaries = reporter.withContextSummarizer { $0.getSummaries() }
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("debug until past date") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(-1.0))
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.withContextSummarizer { $0.hasLoggedRequests }) == true
                let summaries = reporter.withContextSummarizer { $0.getSummaries() }
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("debug until future date") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(3.0))
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                let expected = FeatureEvent(key: "flag-key", context: context, value: "a", defaultValue: "b", featureFlag: flag, includeReason: false, isDebug: true)
                expect(expectedEvents(reporter.pendingEventsForTesting)) == expectedEvents([expected])
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.withContextSummarizer { $0.hasLoggedRequests }) == true
                let summaries = reporter.withContextSummarizer { $0.getSummaries() }
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("debug until future date earlier than service date") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                reporter.setLastEventResponseDate(Date().addingTimeInterval(10.0))
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: false, debugEventsUntilDate: Date().addingTimeInterval(3.0))
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: true)
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.withContextSummarizer { $0.hasLoggedRequests }) == true
                let summaries = reporter.withContextSummarizer { $0.getSummaries() }
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("tracked flag and debug date in future") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                reporter.setLastEventResponseDate(Date().addingTimeInterval(-3.0))
                let flag = FeatureFlag(flagKey: "unused", value: nil, variation: 1, flagVersion: 2, trackEvents: true, debugEventsUntilDate: Date())
                reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                let expectedFeature = FeatureEvent(key: "flag-key", context: context, value: "a", defaultValue: "b", featureFlag: flag, includeReason: false, isDebug: false)
                let expectedDebug = FeatureEvent(key: "flag-key", context: context, value: "a", defaultValue: "b", featureFlag: flag, includeReason: false, isDebug: true)
                expect(expectedEvents(reporter.pendingEventsForTesting)) == expectedEvents([expectedFeature, expectedDebug])
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.withContextSummarizer { $0.hasLoggedRequests }) == true
                let summaries = reporter.withContextSummarizer { $0.getSummaries() }
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: 1, version: 2)]?.value) == "a"
            }
            it("records events concurrently") {
                let (reporter, store) = makeReporter()
                defer { store.deleteEverything() }
                reporter.setLastEventResponseDate(Date())
                let flag = FeatureFlag(flagKey: "unused", trackEvents: true, debugEventsUntilDate: Date().addingTimeInterval(3.0))

                let counter = DispatchSemaphore(value: 0)
                DispatchQueue.concurrentPerform(iterations: 10) { _ in
                    reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                    counter.signal()
                }
                (0..<10).forEach { _ in counter.wait() }

                let held = expectedEvents(reporter.pendingEventsForTesting)
                expect(held.count) == 20
                expect(held.filter { $0.kindField == "feature" }.count) == 10
                expect(held.filter { $0.kindField == "debug" }.count) == 10
                expect(recordedEvents(store)).to(beEmpty())
                expect(reporter.withContextSummarizer { $0.hasLoggedRequests }) == true
                let summaries = reporter.withContextSummarizer { $0.getSummaries() }
                expect(summaries.count) == 1
                let tracker = summaries[0].tracker
                expect(tracker.flagCounters["flag-key"]?.defaultValue) == "b"
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters.count) == 1
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: nil, version: nil)]?.count) == 10
                expect(tracker.flagCounters["flag-key"]?.flagValueCounters[CounterKey(variation: nil, version: nil)]?.value) == "a"
            }
        }
    }

    private func reportTimerSpec() {
        describe("report timer fires") {
            var testContext: TestContext!
            afterEach {
                testContext.cleanUp()
            }
            context("with events") {
                beforeEach {
                    testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                    testContext.eventProcessor.isOnline = true
                    testContext.recordEvents(Event.Kind.allKinds.count)
                }
                it("reports events") {
                    expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)
                    expect(testContext.store.pendingEventCount).toEventually(equal(0), timeout: Constants.deliveryTimeout)
                    expect(testContext.diagnosticCache.recordEventsInLastBatchCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)
                    expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch).toEventually(equal(testContext.events.count), timeout: Constants.deliveryTimeout)
                    let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                    valueIsArray(published) { valueArray in
                        expect(valueArray.count) == testContext.events.count
                        expect(valueArray) == testContext.events.map { encodeToLDValue($0) }
                    }
                }
            }
            context("on later intervals") {
                beforeEach {
                    testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                    testContext.eventProcessor.isOnline = true
                    testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                }
                it("publishes events recorded after the first fire") {
                    expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)
                    testContext.recordEvents(Event.Kind.nonSummaryKinds.count)
                    expect(testContext.serviceMock.publishEventDataCallCount)
                        .toEventually(equal(2), timeout: .seconds(2))
                }
            }
            it("without events") {
                testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                testContext.eventProcessor.isOnline = true

                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Constants.eventFlushIntervalHalfSecond) {
                        expect(testContext.serviceMock.publishEventDataCallCount) == 0
                        done()
                    }
                }
            }
        }
    }
}

extension DirectEventProcessorSpec {
    /// What the SDK is able to report after the process it was recording in is gone.
    ///
    /// These are written against what is in the directory, and a store on a copy of it, which is what the next run of
    /// the application amounts to: it sees the bytes that reached the disk and nothing that was still in memory.
    private func durabilitySpec() {
        describe("surviving the process") {
            var testContext: TestContext!
            afterEach {
                testContext?.cleanUp()
                testContext = nil
            }

            /// The events the next run of the application would find.
            func eventsLeftOnDisk() -> [LDValue] {
                testContext.store.payloadsOnDisk.compactMap { try? JSONDecoder().decode(LDValue.self, from: $0) }
            }

            itPersisting("has written a tracked event by the time recording it returns") {
                testContext = TestContext()

                // The sequence that loses events today: something is tracked and the process ends immediately after.
                testContext.eventProcessor.record(CustomEvent(key: "fatal-error", context: testContext.context, data: ["message": "boom"]))

                let onDisk = eventsLeftOnDisk()
                expect(onDisk.count) == 1
                expect(onDisk.first?.kindField) == "custom"
            }

            itPersisting("writes nothing for a tracked event at .deferred, and writes it with the rest at the pending threshold") {
                let commits = DispatchQueue(label: "com.launchdarkly.tests.commits")
                testContext = TestContext(eventCapacity: 100, eventPersistence: .deferred, commitQueue: commits)

                testContext.eventProcessor.record(CustomEvent(key: "fatal-error", context: testContext.context, data: ["message": "boom"]))
                // Behind any write the track queued, so that write has run by now.
                commits.sync { }
                expect(eventsLeftOnDisk()).to(beEmpty())

                for index in 1..<EventCommitter.pendingCommitThreshold {
                    testContext.eventProcessor.record(CustomEvent(key: "more-\(index)", context: testContext.context))
                }
                expect(eventsLeftOnDisk().count).toEventually(equal(EventCommitter.pendingCommitThreshold), timeout: Constants.deliveryTimeout)
            }

            itPersisting("has written the evaluations that came before a tracked event") {
                // A response date of its own, because the distant past that a fresh context defaults to also satisfies
                // the debug window comparison and would add a debug event to what is asserted below.
                testContext = TestContext(lastEventResponseDate: Date())
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: false)

                // An untracked flag is only ever reported as a summary, so this is the case where the exposure exists
                // nowhere but in memory until something forces it out.
                testContext.eventProcessor.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                testContext.eventProcessor.record(CustomEvent(key: "fatal-error", context: testContext.context, data: nil))

                expect(eventsLeftOnDisk().compactMap { $0.kindField }) == ["custom", "summary"]
            }

            itPersisting("persists feature and summary events synchronously on flush") {
                testContext = TestContext(lastEventResponseDate: Date())
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)

                // The deliberate trade: an evaluation does not pay for a write, so it is only staged until something
                // else commits it.
                testContext.eventProcessor.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                expect(eventsLeftOnDisk()).to(beEmpty())

                testContext.eventProcessor.flush(completion: nil)
                expect(eventsLeftOnDisk().compactMap { $0.kindField }) == ["feature", "summary"]
            }

            itPersisting("writes on flush at .deferred too, without waiting for the commit queue") {
                // Suspended, so that a queued write cannot run and the only write there can be is one the flush makes on
                // this thread.
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                defer { commits.resume() }
                testContext = TestContext(eventPersistence: .deferred, commitQueue: commits)

                testContext.eventProcessor.record(CustomEvent(key: "before-exit", context: testContext.context, data: nil))
                expect(eventsLeftOnDisk()).to(beEmpty())

                testContext.eventProcessor.flush(completion: nil)
                expect(eventsLeftOnDisk().compactMap { $0.kindField }) == ["custom"]
            }

            it("does not write on the main thread when a flag is evaluated there") {
                // Suspended for the length of the evaluations, so that a write this thread was going to cause is a
                // write that cannot happen: an evaluation is expected to be a memory operation, and the thread
                // evaluating is usually this one.
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                testContext = TestContext(lastEventResponseDate: Date(),
                                          store: EventStore.temporary(capacity: .max),
                                          eventCapacity: .max,
                                          commitQueue: commits)

                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                expect(Thread.isMainThread) == true
                // Far past the pending threshold, so one coalesced commit is waiting.
                for _ in 0..<400 {
                    testContext.eventProcessor.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                }

                expect(eventsLeftOnDisk()).to(beEmpty())

                commits.resume()

                // Each poll reads and decodes every event on this thread, so polling often keeps the run loop too busy
                // to notice the count is already there.
                expect(eventsLeftOnDisk().compactMap { $0.kindField }.filter { $0 == "feature" }.count)
                    .toEventually(equal(400), timeout: Constants.deliveryTimeout, pollInterval: .milliseconds(200))
            }

            itPersisting("hands back a flush that reports its outcome while a write is stalled on the disk") {
                let lock = UnfairLock()
                var stalling = false
                let stalled = DispatchSemaphore(value: 0)
                let release = DispatchSemaphore(value: 0)
                let store = EventStore.temporary(writeLog: { file, bytes in
                    if lock.withLock({ stalling }) {
                        stalled.signal()
                        _ = release.wait(timeout: .now() + 5)
                    }
                    return file.writeAll(bytes)
                })
                testContext = TestContext(store: store)
                let processor = testContext.eventProcessor!
                processor.isOnline = true
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    processor.flushReportingOutcome { _ in done() }
                }

                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                processor.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                lock.withLock { stalling = true }
                // A commit stalled in its write, holding the commit lock, as one on a slow disk does.
                DispatchQueue.global().async { processor.commitRecordedEvents() }
                expect(stalled.wait(timeout: .now() + 5)) == .success
                lock.withLock { stalling = false }

                let answer = Answer()
                let started = Date()
                processor.flushReportingOutcome(completion: answer.record)
                expect(Date().timeIntervalSince(started)) < 1
                expect(answer.value()).to(beNil())

                release.signal()
                expect(answer.value()).toEventually(equal(true), timeout: Constants.deliveryTimeout)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
            }

            itPersisting("reports the events a previous run left behind") {
                testContext = TestContext()
                testContext.recordEvents(2)
                testContext.eventProcessor.commitRecordedEvents()

                // Nothing delivered them and nothing closed the log, as would be the case had the process died here.
                let recovered = testContext.store.nextRun()
                let nextRun = DirectEventProcessor(service: testContext.serviceMock, onSyncComplete: nil, store: recovered, pacing: .noWaits)
                nextRun.isOnline = true

                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    nextRun.flush(completion: done)
                }

                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                valueIsArray(published) { events in
                    expect(events.count) == 2
                }
                expect(recovered.pendingEventCount) == 0
                nextRun.isOnline = false
            }

            itPersisting("delivers what a previous run left behind as soon as it is online, without waiting for a report interval") {
                testContext = TestContext()
                testContext.recordEvents(2)
                testContext.eventProcessor.commitRecordedEvents()

                let recovered = testContext.store.nextRun()
                let nextRun = DirectEventProcessor(service: testContext.serviceMock, onSyncComplete: nil, store: recovered, pacing: .noWaits)

                // Nothing asks for a flush, and the report interval is several times longer than this waits, so the
                // only thing that can deliver these is the reporter coming online.
                nextRun.isOnline = true

                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)
                expect(recovered.pendingEventCount).toEventually(equal(0), timeout: Constants.deliveryTimeout)
                nextRun.isOnline = false
            }

            itPersisting("discards what a previous run left longer ago than the maximum age, and still answers a flush with success") {
                testContext = TestContext()
                testContext.recordEvents(2)
                testContext.eventProcessor.commitRecordedEvents()
                expect(testContext.store.closeBatch()).toNot(beNil())
                let directory = testContext.store.directory!
                let longAgo = Date().addingTimeInterval(-8 * 24 * 60 * 60)
                for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                    try FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: file.path)
                }

                let nextRun = DirectEventProcessor(service: testContext.serviceMock, onSyncComplete: nil, store: EventStore.sharing(directory), pacing: .noWaits)
                nextRun.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    nextRun.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }

                // The caller's own events all got out; the ones discarded were no one's to wait on.
                expect(delivered) == true
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
                expect(testContext.diagnosticCache.incrementDroppedEventCountCallCount) == 2
                nextRun.isOnline = false
            }

            itPersisting("refuses an event without encoding it once the stored bytes leave no room for full events") {
                let store = EventStore.temporary(capacity: 100, byteCapacity: 1000)
                // One frame of 800 bytes, which is all the room full events have.
                expect(store.stage(Data(repeating: UInt8(ascii: "x"), count: 800 - EventLogFormat.frameOverhead))) == true
                testContext = TestContext(store: store, eventCapacity: 100)

                let refused = EncodingGate(key: "refused", context: testContext.context)
                refused.proceed.signal()
                testContext.eventProcessor.record(refused)

                expect(refused.started.wait(timeout: .now() + 0.2)) == .timedOut
                expect(testContext.diagnosticCache.incrementDroppedEventCountCallCount) == 1
            }

            itPersisting("reports a flush as failed when an accepted event turns out too large for the bytes left") {
                let store = EventStore.temporary(capacity: 100, byteCapacity: 1000)
                expect(store.stage(Data(repeating: UInt8(ascii: "x"), count: 700 - EventLogFormat.frameOverhead))) == true
                testContext = TestContext(store: store, eventCapacity: 100)
                testContext.eventProcessor.isOnline = true

                testContext.eventProcessor.record(CustomEvent(key: "large", context: testContext.context,
                                                              data: LDValue.string(String(repeating: "y", count: 300))))

                expect(testContext.flushOutcome()) == false
                expect(testContext.serviceMock.publishedEventPayloads.flatMap(customKeys)).toNot(contain("large"))
            }

            itPersisting("reports a flush as failed when the stored events cannot be listed, and still sends the batch it closed") {
                testContext = TestContext()
                testContext.eventProcessor.isOnline = true
                testContext.eventProcessor.record(CustomEvent(key: "tracked", context: testContext.context))
                testContext.eventProcessor.commitRecordedEvents()

                let directory = testContext.store.directory!
                // Writable and searchable but not readable, so the batch can be closed and read and not listed.
                try FileManager.default.setAttributes([.posixPermissions: 0o300], ofItemAtPath: directory.path)
                defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }

                expect(testContext.flushOutcome()) == false
                expect(testContext.serviceMock.publishedEventPayloads.flatMap(customKeys)) == ["tracked"]

                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
                expect(testContext.flushOutcome()) == true
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
            }

            itPersisting("reports a flush as failed while the event log will not close, and delivers all of it once it does") {
                testContext = TestContext()
                testContext.eventProcessor.isOnline = true
                testContext.eventProcessor.record(CustomEvent(key: "first", context: testContext.context))
                testContext.eventProcessor.commitRecordedEvents()

                let directory = testContext.store.directory!
                // No write permission, so the log cannot be renamed into a batch.
                try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: directory.path)
                defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path) }

                expect(testContext.flushOutcome()) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 0

                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
                testContext.eventProcessor.record(CustomEvent(key: "second", context: testContext.context))
                expect(testContext.flushOutcome()) == true
                expect(testContext.serviceMock.publishedEventPayloads.flatMap(customKeys)) == ["first", "second"]
            }

            it("does not bring a delivery forward when a previous run left nothing behind") {
                testContext = TestContext()

                testContext.eventProcessor.isOnline = true

                // Coming online is not itself a reason to send: an ordinary start has nothing waiting, and the events
                // this run records keep to the report interval.
                testContext.recordEvents(1)
                Thread.sleep(forTimeInterval: 0.2)
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
            }

            itPersisting("delivers a batch a failed run left behind under the same payload id") {
                testContext = TestContext(stubResponseSuccess: false)
                testContext.recordEvents(1)

                waitUntil(timeout: .seconds(10)) { done in
                    testContext.eventProcessor.isOnline = true
                    testContext.eventProcessor.flush(completion: done)
                }

                let kept = testContext.store.pendingBatches()
                expect(kept.count) == 1

                // A payload LaunchDarkly may have already seen is retried under the identifier it was first sent with,
                // which is how the events are not counted twice.
                let payloadIds = Set(testContext.serviceMock.publishedPayloadIds)
                expect(payloadIds.count) == 1
                expect(payloadIds.first) == kept.first?.payloadId
            }

            it("does not send a batch again when a delivery is asked for while one is in flight") {
                testContext = TestContext()
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                // The response is held back, so the first delivery stays in flight and its batch stays on disk --
                // the window in which a second delivery would find that batch and send it again.
                testContext.serviceMock.holdsEventCompletions = true

                // Answered from the delivery's own threads and polled from this one.
                let first = Answer()
                testContext.eventProcessor.flush { first.record(true) }
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                let second = Answer()
                testContext.eventProcessor.flush { second.record(true) }
                // Nothing more goes out while the first delivery is unanswered.
                Thread.sleep(forTimeInterval: 0.3)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1

                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()

                // The second caller's delivery starts once the first is answered, and finds nothing left to send. The
                // batch goes out once in total.
                expect(first.value()).toEventually(beTrue(), timeout: Constants.deliveryTimeout)
                expect(second.value()).toEventually(beTrue(), timeout: Constants.deliveryTimeout)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                expect(testContext.store.pendingEventCount) == 0
            }

            // What the contract tests' "buffer is reset after flush" does: they have the payload as soon as it is sent,
            // and record the next event before the SDK has heard back.
            it("makes room in a full store as soon as its batch is sent") {
                testContext = TestContext(eventCapacity: 2)
                testContext.eventProcessor.isOnline = true
                testContext.serviceMock.holdsEventCompletions = true
                testContext.eventProcessor.record(CustomEvent(key: "first", context: testContext.context))
                testContext.eventProcessor.record(CustomEvent(key: "second", context: testContext.context))

                let first = Answer()
                testContext.eventProcessor.flush { first.record(true) }
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                testContext.eventProcessor.record(CustomEvent(key: "one-more", context: testContext.context))
                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()
                expect(first.value()).toEventually(beTrue(), timeout: Constants.deliveryTimeout)

                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flush(completion: done)
                }
                expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == [["first", "second"], ["one-more"]]
            }

            it("answers an evaluating thread while a delivery is listing the store") {
                testContext = TestContext()
                // Standing in for the listing a delivery makes on a device whose disk is busy, which on the first one
                // after launch reads every batch a previous run left behind.
                let store = SlowListingStore(testContext.store)
                defer { store.release.signal() }
                let reporter = DirectEventProcessor(service: testContext.serviceMock, onSyncComplete: nil, store: store, pacing: .noWaits)
                reporter.isOnline = true

                reporter.record(CustomEvent(key: "tracked", context: testContext.context))
                reporter.flush(completion: nil)
                expect(store.listing.wait(timeout: .now() + 5)) == .success

                // Read on the evaluating thread for every flag with debug events turned on, so it must not end up
                // behind whatever the delivery is holding while it lists.
                let answered = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    _ = reporter.lastEventResponseDate
                    answered.signal()
                }
                expect(answered.wait(timeout: .now() + 2)) == .success

                store.release.signal()
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)
            }

            itPersisting("writes deferred events at the pending threshold while a delivery holds the delivery queue") {
                testContext = TestContext(eventCapacity: 100, eventPersistence: .deferred)
                // Stands in for a post to a network that does not answer, which holds the queue for as long as its
                // timeouts allow.
                let released = DispatchSemaphore(value: 0)
                defer { released.signal() }
                testContext.eventProcessor.occupyQueue(until: released)

                for index in 0..<EventCommitter.pendingCommitThreshold {
                    testContext.eventProcessor.record(CustomEvent(key: "tracked-\(index)", context: testContext.context))
                }

                expect(eventsLeftOnDisk().count).toEventually(equal(EventCommitter.pendingCommitThreshold), timeout: Constants.deliveryTimeout)
            }

            itPersisting("has written everything by the time a flush returns, even while a delivery holds the delivery queue") {
                testContext = TestContext(lastEventResponseDate: Date())
                let released = DispatchSemaphore(value: 0)
                defer { released.signal() }
                testContext.eventProcessor.occupyQueue(until: released)
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                testContext.eventProcessor.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)

                // What `LDClient.close()` relies on: the write is the caller's, so a delivery that never finishes
                // cannot keep it from happening.
                testContext.eventProcessor.flush(completion: nil)

                expect(eventsLeftOnDisk().compactMap { $0.kindField }) == ["feature", "summary"]
            }

            itPersisting("shares commits between tracks recorded at once, and has each on disk when recording it returns") {
                let trackers = 8
                var config = LDConfig.stub
                config.eventCapacity = 100
                config.eventPersistence = .immediate
                let serviceMock = DarklyServiceMock()
                serviceMock.config = config
                let inner = EventStore.temporary(capacity: config.eventCapacity)
                defer { inner.deleteEverything() }
                let store = ClosingHookStore(inner)
                let commitsLock = NSLock()
                var commits = 0
                // A slow disk, so that the other tracks arrive while a commit is under way.
                store.beforeCommitting = {
                    commitsLock.lock()
                    commits += 1
                    commitsLock.unlock()
                    Thread.sleep(forTimeInterval: 0.05)
                }
                let reporter = DirectEventProcessor(service: serviceMock, onSyncComplete: nil, store: store, encoding: .codable, commitQueue: DispatchQueue(label: "com.launchdarkly.tests.commits"), pacing: .noWaits)
                let context = LDContext.stub()
                func keysOnDisk() -> [String] {
                    inner.payloadsOnDisk.compactMap { try? JSONDecoder().decode(LDValue.self, from: $0).keyField }
                }

                let start = DispatchSemaphore(value: 0)
                let finished = DispatchGroup()
                let missingLock = NSLock()
                var missingOnReturn: [String] = []
                for index in 0..<trackers {
                    let key = "event-\(index)"
                    finished.enter()
                    Thread {
                        start.wait()
                        reporter.record(CustomEvent(key: key, context: context))
                        if !keysOnDisk().contains(key) {
                            missingLock.lock()
                            missingOnReturn.append(key)
                            missingLock.unlock()
                        }
                        finished.leave()
                    }.start()
                }
                for _ in 0..<trackers {
                    start.signal()
                }
                expect(finished.wait(timeout: .now() + 10)) == .success

                expect(missingOnReturn).to(beEmpty())
                commitsLock.lock()
                let totalCommits = commits
                commitsLock.unlock()
                expect(totalCommits) < trackers
            }

            itPersisting("tries a batch a previous run left once at start, with its retry, and then waits out the backoff") {
                testContext = TestContext()
                testContext.serviceMock.respondToEvents(with: 503)
                testContext.eventProcessor.record(CustomEvent(key: "kept", context: testContext.context))

                let recovered = testContext.store.nextRun()
                let nextRun = DirectEventProcessor(service: testContext.serviceMock, onSyncComplete: nil, store: recovered, pacing: .noWaits)
                nextRun.isOnline = true
                defer { nextRun.isOnline = false }

                // The delivery at start and its retry a second later, then nothing until the two seconds after that are
                // up.
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(2), timeout: .seconds(5))
                expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == [["kept"], ["kept"]]
                waitLettingTimersFire(1.5)
                expect(testContext.serviceMock.publishEventDataCallCount) == 2
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(3), timeout: .seconds(3))
            }

            itPersisting("leaves a batch still refused when the run ended for the next run to deliver, under the same payload id") {
                testContext = TestContext()
                testContext.serviceMock.respondToEvents(with: 503)
                testContext.eventProcessor.record(CustomEvent(key: "kept", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                expect(testContext.flushOutcome()) == false
                let payloadId = testContext.serviceMock.publishedPayloadIds.first
                testContext.eventProcessor.isOnline = false

                // The same directory, as the application's next launch would find it.
                testContext.serviceMock.stubEventResponse(success: true)
                let recovered = EventStore.sharing(testContext.store.directory!)
                let nextRun = DirectEventProcessor(service: testContext.serviceMock, onSyncComplete: nil, store: recovered, pacing: .noWaits)
                nextRun.isOnline = true
                defer { nextRun.isOnline = false }

                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(3), timeout: Constants.deliveryTimeout)
                expect(customKeys(testContext.serviceMock.publishedEventPayloads.last!)) == ["kept"]
                expect(testContext.serviceMock.publishedPayloadIds.last) == payloadId
                expect(recovered.pendingEventCount).toEventually(equal(0), timeout: Constants.deliveryTimeout)
            }
        }
    }

    private func commitSpec() {
        describe("committing held events") {
            var testContext: TestContext!
            afterEach {
                testContext?.cleanUp()
                testContext = nil
            }

            it("leaves held events for the delivery to encode when they are not persisted") {
                let commits = DispatchQueue(label: "com.launchdarkly.tests.commits")
                testContext = TestContext(lastEventResponseDate: Date(),
                                          store: EventStore.temporary(capacity: .max, persistEvents: false),
                                          eventCapacity: .max,
                                          eventPersistence: .disabled,
                                          commitQueue: commits)
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)

                // Past the pending threshold and then a commit point: either would commit where events are persisted.
                for _ in 0..<100 {
                    testContext.eventProcessor.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                }
                testContext.eventProcessor.record(CustomEvent(key: "custom", context: testContext.context))
                testContext.eventProcessor.flush(completion: nil)
                commits.sync { }

                // Encoding them early would buy nothing, since a commit here writes nothing to disk.
                expect(testContext.store.pendingEventCount) == 0

                testContext.eventProcessor.isOnline = true
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flush(completion: done)
                }
                let published = try JSONDecoder().decode(LDValue.self, from: testContext.serviceMock.publishedEventData!)
                valueIsArray(published) { events in
                    expect(events.compactMap { $0.kindField }.filter { $0 == "feature" }.count) == 100
                    expect(events.compactMap { $0.kindField }.filter { $0 != "feature" }) == ["custom", "summary"]
                }
            }

            it("commits an evaluation's counter together with its full event") {
                testContext = TestContext(lastEventResponseDate: Date(),
                                          store: EventStore.temporary(capacity: .max),
                                          eventCapacity: .max)
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: true)
                let reporter = testContext.eventProcessor!
                let context = testContext.context!

                // Recording pauses halfway until a commit has taken the first half, so that at least two commits land
                // while it runs however the threads are scheduled. Otherwise the recording could finish before the
                // first commit, and the single summary that leaves would check nothing about concurrent commits.
                let halfway = DispatchSemaphore(value: 0)
                let resume = DispatchSemaphore(value: 0)
                let recorded = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    for index in 0..<2_000 {
                        if index == 1_000 {
                            halfway.signal()
                            resume.wait()
                        }
                        reporter.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                    }
                    recorded.signal()
                }
                while recorded.wait(timeout: .now()) == .timedOut {
                    reporter.commitRecordedEvents()
                    if halfway.wait(timeout: .now()) == .success {
                        reporter.commitRecordedEvents()
                        resume.signal()
                    }
                }
                reporter.commitRecordedEvents()

                // A commit stages its run and then its summary, so each summary has to count exactly the feature
                // events since the one before it; a commit that caught an evaluation half recorded would not.
                var featuresSinceSummary = 0
                var summaries = 0
                for event in recordedEvents(testContext.store) {
                    switch event.kindField {
                    case "feature":
                        featuresSinceSummary += 1
                    case "summary":
                        summaries += 1
                        expect(summaryCount(event)) == featuresSinceSummary
                        featuresSinceSummary = 0
                    default:
                        break
                    }
                }
                expect(featuresSinceSummary) == 0
                expect(summaries) > 1
            }

            it("counts a run toward capacity while it is being encoded") {
                var config = LDConfig.stub
                config.eventCapacity = 1
                config.eventPersistence = .deferred
                let serviceMock = DarklyServiceMock()
                serviceMock.config = config
                let diagnosticCache = DiagnosticCachingMock()
                serviceMock.diagnosticCache = diagnosticCache
                let store = EventStore.temporary(capacity: config.eventCapacity)
                defer { store.deleteEverything() }
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                defer { commits.resume() }
                let reporter = DirectEventProcessor(service: serviceMock, onSyncComplete: nil, store: store, encoding: .codable, commitQueue: commits, pacing: .noWaits)

                let slow = EncodingGate(key: "slow", context: LDContext.stub())
                reporter.record(slow)
                let committed = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    reporter.commitRecordedEvents()
                    committed.signal()
                }
                expect(slow.started.wait(timeout: .now() + 5)) == .success

                // Neither held nor staged at this moment, the slow event is only in the commit encoding it.
                reporter.record(CustomEvent(key: "late", context: LDContext.stub()))

                slow.proceed.signal()
                expect(committed.wait(timeout: .now() + 5)) == .success
                reporter.commitRecordedEvents()

                expect(store.pendingEventCount) == 1
                expect(diagnosticCache.incrementDroppedEventCountCallCount) == 1
            }

            it("does not close a batch partway through another commit's run") {
                var config = LDConfig.stub
                config.eventPersistence = .deferred
                let serviceMock = DarklyServiceMock()
                serviceMock.config = config
                serviceMock.stubEventResponse(success: true)
                let inner = EventStore.temporary(capacity: config.eventCapacity)
                defer { inner.deleteEverything() }
                let store = ClosingHookStore(inner)
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                defer { commits.resume() }
                let reporter = DirectEventProcessor(service: serviceMock, onSyncComplete: nil, store: store, encoding: .codable, commitQueue: commits, pacing: .noWaits)

                let slow = EncodingGate(key: "slow", context: LDContext.stub())
                let competingCommit = DispatchSemaphore(value: 0)
                store.beforeClosing = {
                    reporter.record(CustomEvent(key: "first", context: LDContext.stub()))
                    reporter.record(slow)
                    DispatchQueue.global().async {
                        reporter.commitRecordedEvents()
                        competingCommit.signal()
                    }
                    // Long enough for an unguarded commit to stage "first" and block encoding "slow".
                    _ = slow.started.wait(timeout: .now() + 0.5)
                }
                store.afterClosing = { slow.proceed.signal() }

                reporter.isOnline = true
                waitUntil(timeout: .seconds(10)) { done in
                    reporter.flushReportingOutcome { _ in done() }
                }
                expect(competingCommit.wait(timeout: .now() + 5)) == .success

                for keys in store.closedKeys {
                    expect(keys.contains("first")) == keys.contains("slow")
                }
                let rest = try inner.closeBatch().flatMap { try inner.body(of: $0) }.map(customKeys) ?? []
                expect(rest) == ["first", "slow"]
            }

            it("counts an event once while the commit that staged it is still running") {
                var config = LDConfig.stub
                config.eventCapacity = 3
                config.eventPersistence = .deferred
                let serviceMock = DarklyServiceMock()
                serviceMock.config = config
                let diagnosticCache = DiagnosticCachingMock()
                serviceMock.diagnosticCache = diagnosticCache
                let store = EventStore.temporary(capacity: config.eventCapacity)
                defer { store.deleteEverything() }
                let commits = DispatchQueue(label: "com.launchdarkly.tests.suspended")
                commits.suspend()
                defer { commits.resume() }
                let reporter = DirectEventProcessor(service: serviceMock, onSyncComplete: nil, store: store, encoding: .codable, commitQueue: commits, pacing: .noWaits)

                let slow = EncodingGate(key: "slow", context: LDContext.stub())
                reporter.record(CustomEvent(key: "first", context: LDContext.stub()))
                reporter.record(slow)
                let committed = DispatchSemaphore(value: 0)
                DispatchQueue.global().async {
                    reporter.commitRecordedEvents()
                    committed.signal()
                }
                expect(slow.started.wait(timeout: .now() + 5)) == .success

                // Paused with "first" staged and "slow" still encoding. Counted once each, they leave room for one more
                // under a capacity of three; "first" counted both as staged and as reserved would not.
                reporter.record(CustomEvent(key: "late", context: LDContext.stub()))

                slow.proceed.signal()
                expect(committed.wait(timeout: .now() + 5)) == .success
                reporter.commitRecordedEvents()

                expect(diagnosticCache.incrementDroppedEventCountCallCount) == 0
                expect(store.pendingEventCount) == 3
            }

            itPersisting("makes room in the summarizer at every commit point") {
                // Counters become summary events and are reset at every commit point, so the summarizer only holds the
                // contexts seen since the last one. Without the reset, an application identifying its way through more
                // contexts than the capacity would start losing counts partway through.
                testContext = TestContext(lastEventResponseDate: Date(), eventCapacity: 2)
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: false)
                let contexts = 6
                for index in 0..<contexts {
                    let context = LDContext.stub(key: "context-\(index)")
                    testContext.eventProcessor.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: context, includeReason: false)
                    testContext.eventProcessor.record(IdentifyEvent(context: context))
                }

                expect(testContext.committedEvents().filter { $0.kindField == "summary" }.count) == contexts
            }
        }
    }

    private func flushReportingOutcomeSpec() {
        describe("flush reporting outcome") {
            var testContext: TestContext!
            afterEach {
                testContext.cleanUp()
            }

            it("reports true when there is nothing to deliver") {
                testContext = TestContext()
                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
            }

            it("reports false while offline") {
                testContext = TestContext()
                testContext.recordEvents(1)
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
            }

            it("reports true when LaunchDarkly accepts the batch") {
                testContext = TestContext()
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
                expect(testContext.store.pendingEventCount) == 0
            }

            it("reports false and keeps the batch when it could not be read, and delivers it once it can be") {
                // Set from this thread and read on the reporter's, which reads files from the moment it is built.
                let failing = Answer()
                let store = EventStore.temporary(readFile: { url in
                    // What a process out of file descriptors gets for a file that is perfectly intact.
                    guard failing.value() != true
                    else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(EMFILE)) }
                    return try Data(contentsOf: url)
                })
                testContext = TestContext(store: store)
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true

                failing.record(true)
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
                expect(store.pendingBatches().count) == 1

                failing.record(false)
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                expect(store.pendingEventCount) == 0
            }

            it("passes by a stored batch it could not read, reading it once a flush, and still delivers the batches behind it") {
                let reads = FailingReads()
                let store = EventStore.temporary(readFile: { try reads.read($0) })
                testContext = TestContext(store: store)
                // Online, and past the check for what a previous run left, before there is a batch for that check to find.
                testContext.eventProcessor.isOnline = true
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { _ in done() }
                }
                testContext.recordEvents(1)
                testContext.eventProcessor.commitRecordedEvents()
                let unreadable = store.closeBatch()!
                reads.fail(unreadable.payloadId)
                testContext.recordEvents(1)

                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                expect(testContext.serviceMock.publishedPayloadIds).toNot(contain(unreadable.payloadId))
                expect(reads.failures) == 1
                expect(store.pendingBatches().map { $0.payloadId }) == [unreadable.payloadId]

                reads.fail(nil)
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
                expect(testContext.serviceMock.publishedPayloadIds.last) == unreadable.payloadId
            }

            it("drops a stored batch it could not read at three flushes in a row, and reports the loss once") {
                let reads = FailingReads()
                let store = EventStore.temporary(readFile: { try reads.read($0) })
                testContext = TestContext(store: store)
                testContext.eventProcessor.isOnline = true
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { _ in done() }
                }
                testContext.recordEvents(1)
                testContext.eventProcessor.commitRecordedEvents()
                reads.fail(store.closeBatch()!.payloadId)

                var answers: [Bool] = []
                for _ in 0..<DirectEventProcessor.readFailuresBeforeDropping {
                    expect(store.pendingBatches().count) == 1
                    waitUntil(timeout: Constants.deliveryTimeout) { done in
                        testContext.eventProcessor.flushReportingOutcome { result in
                            answers.append(result)
                            done()
                        }
                    }
                }
                expect(answers) == [false, false, false]
                expect(reads.failures) == DirectEventProcessor.readFailuresBeforeDropping
                expect(store.pendingBatches()).to(beEmpty())
                expect(testContext.serviceMock.publishEventDataCallCount) == 0

                testContext.recordEvents(1)
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
            }

            it("reports false and drops a stored batch this version cannot read, and still delivers the rest") {
                let store = EventStore.temporary()
                testContext = TestContext(store: store)
                // Online, and past the check for what a previous run left, before there is a batch for that check to
                // find. Found, it would be delivered on going online, ahead of the flush this test asks about.
                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { _ in done() }
                }

                testContext.recordEvents(1)
                testContext.eventProcessor.commitRecordedEvents()
                let damaged = store.closeBatch()!
                // Its name still counts it, so it is listed without being read; the damage is only found on sending.
                let damagedUrl = store.directory!.appendingPathComponent("ready-v1-\(damaged.payloadId).\(damaged.eventCount)")
                try Data("not an event log".utf8).write(to: damagedUrl)
                testContext.recordEvents(1)

                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                expect(FileManager.default.fileExists(atPath: damagedUrl.path)) == false
                expect(store.pendingEventCount) == 0
            }

            it("reports false when a stored batch damaged after its first frame is sent short") {
                let store = EventStore.temporary()
                testContext = TestContext(store: store)
                testContext.eventProcessor.isOnline = true
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { _ in done() }
                }

                testContext.recordEvents(3)
                testContext.eventProcessor.commitRecordedEvents()
                let damaged = store.closeBatch()!
                let damagedUrl = store.directory!.appendingPathComponent("ready-v1-\(damaged.payloadId).\(damaged.eventCount)")
                var bytes = try Data(contentsOf: damagedUrl)
                bytes[bytes.count - 1] ^= 0x01
                try bytes.write(to: damagedUrl)

                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                expect(testContext.diagnosticCache.recordEventsInLastBatchReceivedEventsInLastBatch) == damaged.eventCount - 1
                expect(FileManager.default.fileExists(atPath: damagedUrl.path)) == false
                expect(store.pendingEventCount) == 0
            }

            for shared in [false, true] {
                it("reports \(shared ? "true" : "false") for a stored batch gone before it was sent, where other processes \(shared ? "share" : "do not share") the directory") {
                    let store = EventStore.temporary()
                    store.sharesDirectoryWithOtherProcesses = shared
                    testContext = TestContext(store: store)
                    testContext.eventProcessor.isOnline = true
                    waitUntil(timeout: Constants.deliveryTimeout) { done in
                        testContext.eventProcessor.flushReportingOutcome { _ in done() }
                    }

                    testContext.recordEvents(1)
                    testContext.eventProcessor.commitRecordedEvents()
                    let gone = store.closeBatch()!
                    try FileManager.default.removeItem(
                        at: store.directory!.appendingPathComponent("ready-v1-\(gone.payloadId).\(gone.eventCount)"))
                    testContext.recordEvents(1)

                    var delivered: Bool?
                    waitUntil(timeout: Constants.deliveryTimeout) { done in
                        testContext.eventProcessor.flushReportingOutcome { result in
                            delivered = result
                            done()
                        }
                    }
                    // Where another process may have delivered it, it is taken to have been; otherwise its events are lost.
                    expect(delivered) == shared
                    expect(testContext.serviceMock.publishEventDataCallCount) == 1
                    expect(store.pendingEventCount) == 0
                }

                it("reports \(shared ? "true" : "false") for events whose open log was gone before it was closed, where other processes \(shared ? "may take" : "cannot take") it") {
                    let store = EventStore.temporary()
                    store.sharesDirectoryWithOtherProcesses = shared
                    testContext = TestContext(store: store)
                    testContext.eventProcessor.isOnline = true
                    waitUntil(timeout: Constants.deliveryTimeout) { done in
                        testContext.eventProcessor.flushReportingOutcome { _ in done() }
                    }

                    testContext.recordEvents(1)
                    testContext.eventProcessor.commitRecordedEvents()
                    try FileManager.default.removeItem(at: store.openLogUrl!)

                    var delivered: Bool?
                    waitUntil(timeout: Constants.deliveryTimeout) { done in
                        testContext.eventProcessor.flushReportingOutcome { result in
                            delivered = result
                            done()
                        }
                    }
                    expect(delivered) == shared
                    expect(testContext.serviceMock.publishEventDataCallCount) == 0
                    expect(store.pendingEventCount) == 0

                    // Told once: the next flush answers for its own events.
                    testContext.recordEvents(1)
                    waitUntil(timeout: Constants.deliveryTimeout) { done in
                        testContext.eventProcessor.flushReportingOutcome { result in
                            delivered = result
                            done()
                        }
                    }
                    expect(delivered) == true
                    expect(testContext.serviceMock.publishEventDataCallCount) == 1
                }
            }

            it("tells the next flush about a stored batch a delivery nobody waited on dropped") {
                let store = EventStore.temporary()
                testContext = TestContext(store: store)
                testContext.eventProcessor.isOnline = true
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { _ in done() }
                }

                testContext.recordEvents(1)
                testContext.eventProcessor.commitRecordedEvents()
                let damaged = store.closeBatch()!
                let damagedUrl = store.directory!.appendingPathComponent("ready-v1-\(damaged.payloadId).\(damaged.eventCount)")
                try Data("not an event log".utf8).write(to: damagedUrl)

                testContext.eventProcessor.flush(completion: nil)
                expect(FileManager.default.fileExists(atPath: damagedUrl.path)).toEventually(beFalse(), timeout: Constants.deliveryTimeout)

                var delivered: Bool?
                testContext.recordEvents(1)
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false

                testContext.recordEvents(1)
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
            }

            it("delivers what memory was left holding beside what the disk took, and reports true") {
                var writes = 0
                let store = EventStore.temporary(writeLog: { file, bytes in
                    writes += 1
                    // The file header and the first event land; the device is full from then on.
                    return writes > 2 ? ENOSPC : file.writeAll(bytes)
                })
                testContext = TestContext(store: store)
                testContext.eventProcessor.record(CustomEvent(key: "written", context: LDContext.stub()))
                // Its write fails, so persistence is given up with "written" in the log and this in memory.
                testContext.eventProcessor.record(CustomEvent(key: "held", context: LDContext.stub()))
                expect(store.isPersisting) == false

                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
                // Neither left behind, and oldest first.
                expect(testContext.serviceMock.publishedEventPayloads.flatMap(customKeys)) == ["written", "held"]
                expect(store.pendingEventCount) == 0
            }

            it("reports false when an event could not be serialized, though the rest were accepted") {
                testContext = TestContext()
                testContext.eventProcessor.record(CustomEvent(key: "poison", context: LDContext.stub(), metricValue: .nan))
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 1

                // Told once, to the caller who was there to hear it.
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true
            }

            it("reports false when an event serialized too large to store") {
                testContext = TestContext()
                // Larger than a log frame holds, so the store refuses it however much room is left.
                let oversized = String(repeating: "x", count: EventLogFormat.maxFrameSize)
                testContext.eventProcessor.record(CustomEvent(key: oversized, context: LDContext.stub()))
                testContext.eventProcessor.record(CustomEvent(key: "fine", context: LDContext.stub()))
                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                // The event beside it still went.
                expect(testContext.serviceMock.publishedEventPayloads.flatMap(customKeys)) == ["fine"]
            }

            it("sends a flush of more than a batch as requests no larger than a batch, every event once") {
                // Small enough that a batch closed at the limit is within one event of it, so a body that is short of
                // the limit by more than that shows the split happened somewhere else.
                let dataCharacters = EventLogFormat.maxBatchSize / 32
                let eventCount = 100
                testContext = TestContext(eventCapacity: eventCount)
                let padding = LDValue.string(String(repeating: "x", count: dataCharacters))
                for index in 1...eventCount {
                    testContext.eventProcessor.record(CustomEvent(key: "event-\(index)", context: LDContext.stub(),
                                                                  data: padding))
                }
                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: .seconds(30)) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true

                // Before the service compresses it, so the larger of the two sizes.
                let bodies = testContext.serviceMock.publishedEventPayloads
                let sizes = bodies.map(\.count).sorted()
                expect(sizes.count) > 1
                expect(sizes.last ?? .max) <= EventLogFormat.maxBatchSize
                // Only the batch the events ran out in may be short of full.
                expect(sizes.dropFirst().allSatisfy { $0 > EventLogFormat.maxBatchSize - dataCharacters - 4096 }) == true
                expect(Set(testContext.serviceMock.publishedPayloadIds).count) == bodies.count
                expect(bodies.flatMap(customKeys).sorted()) == (1...eventCount).map { "event-\($0)" }.sorted()
            }

            it("delivers a summary larger than a frame in pieces that count every flag once") {
                // Long keys, so that a few thousand flags take one context's summary past what a frame holds.
                let keyPrefix = String(repeating: "k", count: 1000)
                let flagCount = EventLogFormat.maxFrameSize / 1000 * 3 / 2
                testContext = TestContext()
                let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: false)
                let context = LDContext.stub()
                for index in 0..<flagCount {
                    testContext.eventProcessor.recordFlagEvaluationEvents(flagKey: "\(keyPrefix)\(index)", value: "a",
                                                                          defaultValue: "b", featureFlag: flag,
                                                                          context: context, includeReason: false)
                }
                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: .seconds(30)) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == true

                let summaries = testContext.serviceMock.publishedEventPayloads.flatMap { body -> [LDValue] in
                    guard case .array(let events)? = try? JSONDecoder().decode(LDValue.self, from: body)
                    else { return [] }
                    return events.filter { $0.kindField == "summary" }
                }
                let flagKeys = summaries.flatMap { summary -> [String] in
                    guard case .object(let fields) = summary, case .object(let features)? = fields["features"]
                    else { return [] }
                    return Array(features.keys)
                }
                expect(summaries.count) > 1
                expect(flagKeys.count) == flagCount
                expect(Set(flagKeys).count) == flagCount
            }

            it("reports false when a retryable failure leaves the batch on disk") {
                testContext = TestContext(stubResponseSuccess: false)
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: .seconds(10)) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.store.pendingBatches().count) == 1
            }

            it("reports false when LaunchDarkly refuses the batch with a 401, and keeps it") {
                testContext = TestContext()
                let unauthorized = HTTPURLResponse(url: testContext.serviceMock.config.eventsUrl,
                                                   statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                                   httpVersion: DarklyServiceMock.Constants.httpVersion,
                                                   headerFields: nil)
                testContext.serviceMock.stubbedEventResponse = (nil, unauthorized, nil, nil)
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                var delivered: Bool?
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { result in
                        delivered = result
                        done()
                    }
                }
                expect(delivered) == false
                expect(testContext.eventProcessor.isOnline) == true
                expect(testContext.store.pendingEventCount) == 1
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
            }

            it("starts no second request while a delivery is in flight, and sends what was recorded meanwhile after it") {
                testContext = TestContext()
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                testContext.serviceMock.holdsEventCompletions = true

                testContext.eventProcessor.flushReportingOutcome { _ in }
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                testContext.recordEvents(1)
                let second = Answer()
                testContext.eventProcessor.flushReportingOutcome(completion: second.record)
                Thread.sleep(forTimeInterval: 0.3)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                expect(second.value()).to(beNil())

                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()
                expect(second.value()).toEventually(beTrue(), timeout: Constants.deliveryTimeout)
                expect(testContext.serviceMock.publishEventDataCallCount) == 2
                expect(Set(testContext.serviceMock.publishedPayloadIds).count) == 2
            }

            // Every batch whose request is out stops counting against capacity. With a request per flush, a run of
            // flushes each held up by a slow response would take the store a batch past capacity per flush.
            it("holds the store to its capacity through flushes that each find a delivery in flight") {
                testContext = TestContext(eventCapacity: 2)
                testContext.eventProcessor.isOnline = true
                testContext.serviceMock.holdsEventCompletions = true
                testContext.eventProcessor.record(CustomEvent(key: "a-0", context: testContext.context))
                testContext.eventProcessor.record(CustomEvent(key: "a-1", context: testContext.context))
                testContext.eventProcessor.flush(completion: nil)
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                for round in 0..<3 {
                    testContext.eventProcessor.record(CustomEvent(key: "b\(round)-0", context: testContext.context))
                    testContext.eventProcessor.record(CustomEvent(key: "b\(round)-1", context: testContext.context))
                    testContext.eventProcessor.flush(completion: nil)
                }
                Thread.sleep(forTimeInterval: 0.3)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1

                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()
                waitUntil(timeout: Constants.deliveryTimeout) { done in
                    testContext.eventProcessor.flushReportingOutcome { _ in done() }
                }
                // The batch out made room for one store's worth, and nothing past it was taken.
                expect(testContext.serviceMock.publishedEventPayloads.flatMap(customKeys)) == ["a-0", "a-1", "b0-0", "b0-1"]
            }

            it("inherits the outcome of a delivery holding the batch it would have sent") {
                testContext = TestContext(stubResponseSuccess: false)
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                testContext.serviceMock.holdsEventCompletions = true

                testContext.eventProcessor.flushReportingOutcome { _ in }
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                // Everything on disk belongs to the delivery already running, and that may include this caller's
                // events: a commit only stages them, and whichever delivery runs next is what closes them into a
                // batch. So this caller is answered by that delivery rather than told its events arrived.
                let answer = Answer()
                testContext.eventProcessor.flushReportingOutcome(completion: answer.record)
                Thread.sleep(forTimeInterval: 0.3)
                expect(answer.value()).to(beNil())
                expect(testContext.serviceMock.publishEventDataCallCount) == 1

                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()
                // Allows for the one-second retry, after which the batch stays on disk and nobody was told it went.
                expect(answer.value()).toEventually(beFalse(), timeout: .seconds(10))
            }

            it("tells the caller whose delivery the loss happened before, not whichever answers first") {
                testContext = TestContext()
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                testContext.serviceMock.holdsEventCompletions = true

                // A closes a batch of its own and waits on it. Nothing has been lost at the point it closed.
                let first = Answer()
                testContext.eventProcessor.flushReportingOutcome(completion: first.record)
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                // B is asked for while A's post is out, with an event the store will never take among what it will
                // close. A's batch closed before that event was dropped, so the loss is B's.
                testContext.eventProcessor.record(CustomEvent(key: "poison", context: LDContext.stub(), metricValue: .nan))
                testContext.recordEvents(1)
                let second = Answer()
                testContext.eventProcessor.flushReportingOutcome(completion: second.record)

                // With one shared flag, whichever delivery answered first would take the loss, and B would report
                // success for the event it dropped.
                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()

                expect(first.value()).toEventually(beTrue(), timeout: Constants.deliveryTimeout)
                expect(second.value()).toEventually(beFalse(), timeout: Constants.deliveryTimeout)
                expect(testContext.serviceMock.publishEventDataCallCount) == 2
            }

            it("tells the caller whose delivery lost an event, not a later one with nothing of its own to send") {
                testContext = TestContext()
                testContext.eventProcessor.record(CustomEvent(key: "poison", context: LDContext.stub(), metricValue: .nan))
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                testContext.serviceMock.holdsEventCompletions = true

                // A drops the event the store will never take as it closes its batch, so the loss is A's.
                let first = Answer()
                testContext.eventProcessor.flushReportingOutcome(completion: first.record)
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                // B has nothing of its own. Answered as soon as A's batch is, it would take A's loss and leave A
                // reporting success for the event A dropped.
                let second = Answer()
                testContext.eventProcessor.flushReportingOutcome(completion: second.record)
                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()

                expect(first.value()).toEventually(beFalse(), timeout: Constants.deliveryTimeout)
                expect(second.value()).toEventually(beTrue(), timeout: Constants.deliveryTimeout)
            }

            it("answers away from the queue a delivery runs on, after a delivery") {
                testContext = TestContext()
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true

                expect(testContext.flushedFromACompletion()) == true
            }

            it("answers away from the queue a delivery runs on, with nothing to send") {
                testContext = TestContext()
                testContext.eventProcessor.isOnline = true

                // The path that answers without ever leaving the reporter's queue, so it is the one that would
                // deadlock while the delivery path, answering from the response, did not.
                expect(testContext.flushedFromACompletion()) == true
            }

            it("sends one delivery for the flushes that arrive before it starts, and answers them all") {
                testContext = TestContext(stubResponseSuccess: false)
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                let released = DispatchSemaphore(value: 0)
                testContext.eventProcessor.occupyQueue(until: released)

                // An application flushing in a loop would otherwise queue a delivery each time, leaving the flush
                // that matters waiting behind all of them, and growing the waiter list without bound.
                for _ in 0..<100 {
                    testContext.eventProcessor.flush(completion: nil)
                }
                expect(testContext.eventProcessor.queuedDeliveryWaiterCount) == 0

                // Both completions run at once, and the poll below reads from a third thread.
                let answers = Answers()
                for _ in 0..<2 {
                    testContext.eventProcessor.flushReportingOutcome(completion: answers.record)
                }
                expect(testContext.eventProcessor.queuedDeliveryWaiterCount) == 2

                released.signal()
                // Allows for the one-second retry, after which the batch stays on disk.
                expect(answers.value()).toEventually(equal([false, false]), timeout: .seconds(10))
                expect(testContext.eventProcessor.startedDeliveryCount) == 1
                expect(testContext.serviceMock.publishEventDataCallCount) == 2 // the first attempt and its retry
            }

            it("answers every flush that arrived during a refused delivery with its outcome") {
                testContext = TestContext(stubResponseSuccess: false)
                testContext.recordEvents(1)
                testContext.eventProcessor.isOnline = true
                testContext.serviceMock.holdsEventCompletions = true

                let answers = Answers()
                testContext.eventProcessor.flushReportingOutcome(completion: answers.record)
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                // Held on the first post, each of these finds the only batch claimed by it. None of them is told
                // its events arrived on the strength of having nothing left of its own to send.
                for _ in 0..<20 {
                    testContext.eventProcessor.flushReportingOutcome(completion: answers.record)
                }

                testContext.serviceMock.holdsEventCompletions = false
                testContext.serviceMock.releaseHeldEventCompletions()

                // Allows for the one-second retry the second delivery makes.
                expect(answers.value().count).toEventually(equal(21), timeout: .seconds(10))
                expect(answers.value().contains(true)) == false
            }
        }
    }

    private func outageSpec() {
        describe("delivering through an outage") {
            var testContext: TestContext!
            afterEach {
                testContext?.cleanUp()
                testContext = nil
            }

            /// Refuses a batch with `status` for several flushes in a row, each of which attempts it and retries it once,
            /// then lets the service recover and checks that the batch arrives exactly once, under the payload ID it was
            /// first sent with.
            func expectKeptThroughRefusals(status: Int, persistence: EventPersistence, refusedFlushes: Int) {
                testContext = TestContext(store: EventStore.temporary(persistEvents: persistence != .disabled),
                                          eventPersistence: persistence,
                                          retryState: DirectEventProcessorSpec.withoutBackoff())
                testContext.serviceMock.respondToEvents(with: status)
                testContext.eventProcessor.record(CustomEvent(key: "kept", context: testContext.context))
                testContext.eventProcessor.isOnline = true

                for flush in 0..<refusedFlushes {
                    expect(testContext.flushOutcome()).to(equal(false), description: "HTTP \(status), flush \(flush)")
                }
                // Every flush attempted the batch and retried it once, always as the same delivery.
                expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == Array(repeating: ["kept"], count: refusedFlushes * 2)
                expect(Set(testContext.serviceMock.publishedPayloadIds).count) == 1
                let payloadId = testContext.serviceMock.publishedPayloadIds.first

                testContext.serviceMock.stubEventResponse(success: true)
                expect(testContext.flushOutcome()).to(equal(true), description: "HTTP \(status): not delivered once the service recovered")
                expect(customKeys(testContext.serviceMock.publishedEventPayloads.last!)) == ["kept"]
                expect(testContext.serviceMock.publishedPayloadIds.last) == payloadId

                // Gone once accepted: nothing is left to send again.
                let posted = testContext.serviceMock.publishEventDataCallCount
                expect(testContext.flushOutcome()) == true
                expect(testContext.serviceMock.publishEventDataCallCount) == posted
            }

            it("keeps a batch through repeated refusals and delivers it once the service recovers") {
                expectKeptThroughRefusals(status: 503, persistence: .immediate, refusedFlushes: 3)
            }

            it("keeps a batch held in memory through repeated refusals where persistence is off") {
                expectKeptThroughRefusals(status: 503, persistence: .disabled, refusedFlushes: 3)
            }

            // Each has to keep the batch, not only 503: a refusal such as a 401 only waits longer. Not a 400, 413, 415 or
            // 422, which drop the batch when they come twice in a row; see below.
            for status in [401, 403, 404, 408, 429, 500, 502, 504] {
                it("keeps a batch refused with HTTP \(status) past the retry") {
                    expectKeptThroughRefusals(status: status, persistence: .immediate, refusedFlushes: 2)
                }
            }

            // Kept is not the same as resent on its own: a batch the service always refuses is posted a second after the
            // first failure and then twice as long after each one, and a flush in between posts nothing, or it would be
            // posted in a loop.
            for status in [503, 429] {
                it("posts a batch refused with HTTP \(status) only as the backoff allows") {
                    testContext = TestContext()
                    testContext.serviceMock.respondToEvents(with: status)
                    testContext.eventProcessor.record(CustomEvent(key: "refused", context: testContext.context))
                    testContext.eventProcessor.isOnline = true

                    // The attempt and the retry a second later, which the flush waits for.
                    expect(testContext.flushOutcome()) == false
                    expect(testContext.serviceMock.publishEventDataCallCount) == 2

                    // Two seconds now, which a flush neither posts in nor waits out.
                    let start = Date()
                    expect(testContext.flushOutcome()) == false
                    expect(Date().timeIntervalSince(start)) < 1
                    waitLettingTimersFire(1)
                    expect(testContext.serviceMock.publishEventDataCallCount) == 2

                    // The delivery set for when the two seconds are up, and then four seconds of nothing.
                    expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(3), timeout: .seconds(3))
                    waitLettingTimersFire(3)
                    expect(testContext.serviceMock.publishEventDataCallCount) == 3
                }
            }

            it("does not retry a failed post once the reporter has gone offline") {
                testContext = TestContext()
                testContext.serviceMock.respondToEvents(with: 503)
                testContext.eventProcessor.record(CustomEvent(key: "refused", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                testContext.eventProcessor.flush(completion: nil)
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                testContext.eventProcessor.isOnline = false

                waitLettingTimersFire(2)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
            }

            for status in [400, 413, 415, 422] {
                it("drops a batch refused with HTTP \(status) twice in a row, and no longer holds the ones behind it") {
                    testContext = TestContext(retryState: DirectEventProcessorSpec.withoutBackoff())
                    testContext.serviceMock.respondToEvents(with: status)
                    testContext.eventProcessor.record(CustomEvent(key: "refused", context: testContext.context))
                    testContext.eventProcessor.isOnline = true
                    expect(testContext.flushOutcome()) == false
                    expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == [["refused"], ["refused"]]
                    expect(Set(testContext.serviceMock.publishedPayloadIds).count) == 1
                    expect(testContext.store.pendingBatches()).to(beEmpty())
                    waitLettingTimersFire(0.3)
                    expect(testContext.serviceMock.publishEventDataCallCount) == 2
                    testContext.serviceMock.stubEventResponse(success: true)

                    // What was recorded since goes out alone, and that flush is the first a caller waits on since the
                    // loss, so it hears about it.
                    testContext.eventProcessor.record(CustomEvent(key: "next", context: testContext.context))
                    expect(testContext.flushOutcome()) == false
                    expect(testContext.serviceMock.publishedEventPayloads.dropFirst(2).map(customKeys)) == [["next"]]
                    expect(testContext.flushOutcome()) == true
                }
            }

            it("counts different refusals of the payload in a row together") {
                testContext = TestContext(retryState: DirectEventProcessorSpec.withoutBackoff())
                testContext.serviceMock.eventStatusForPost = { post in [1: 413, 2: 400][post] ?? 202 }
                testContext.eventProcessor.record(CustomEvent(key: "refused", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                expect(testContext.flushOutcome()) == false
                expect(testContext.store.pendingBatches()).to(beEmpty())
                testContext.eventProcessor.record(CustomEvent(key: "next", context: testContext.context))
                expect(testContext.flushOutcome()) == false
                expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == [["refused"], ["refused"], ["next"]]
            }

            it("leaves refusals of the payload in a row through a post that gets no response") {
                testContext = TestContext(retryState: DirectEventProcessorSpec.withoutBackoff())
                testContext.serviceMock.eventStatusForPost = { post in [1: 400, 2: 0, 3: 400][post] ?? 202 }
                testContext.eventProcessor.record(CustomEvent(key: "malformed", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                // A refusal, and its retry, which gets no response.
                expect(testContext.flushOutcome()) == false
                expect(testContext.store.pendingBatches()).toNot(beEmpty())

                // The second refusal drops the batch, which no longer holds back the one behind it.
                testContext.eventProcessor.record(CustomEvent(key: "next", context: testContext.context))
                expect(testContext.flushOutcome()) == false
                expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == [["malformed"], ["malformed"], ["malformed"], ["next"]]
                expect(testContext.flushOutcome()) == true
            }

            // The SDK's own backoff: a refusal such as a 401 would wait eight and a half minutes before the second post.
            it("retries a batch refused with HTTP 413 a second later, as it does a 400") {
                testContext = TestContext()
                testContext.serviceMock.respondToEvents(with: HTTPURLResponse.StatusCodes.contentTooLarge)
                testContext.eventProcessor.record(CustomEvent(key: "too-large", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                expect(testContext.flushOutcome()) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 2
                expect(testContext.store.pendingBatches()).to(beEmpty())
            }

            it("drops a batch only for two refusals of the payload in a row") {
                testContext = TestContext(retryState: DirectEventProcessorSpec.withoutBackoff())
                testContext.serviceMock.eventStatusForPost = { post in [1: 400, 2: 503, 3: 400][post] ?? 202 }
                testContext.eventProcessor.record(CustomEvent(key: "kept", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                expect(testContext.flushOutcome()) == false
                expect(testContext.flushOutcome()) == true
                expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == Array(repeating: ["kept"], count: 4)
                expect(Set(testContext.serviceMock.publishedPayloadIds).count) == 1
            }

            it("keeps a refused batch and posts it again once the longer wait is over") {
                // Cut to a second and a half here from the eight and a half minutes the SDK waits.
                testContext = TestContext(retryState: DeliveryRetryState(initialDelay: 1, normalCeiling: 1, extendedCeiling: 1.5))
                testContext.serviceMock.respondToEvents(with: HTTPURLResponse.StatusCodes.unauthorized)
                testContext.eventProcessor.record(CustomEvent(key: "refused", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                expect(testContext.flushOutcome()) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                let payloadId = testContext.serviceMock.publishedPayloadIds.first

                // Recording goes on, and a flush during the wait says it failed without posting.
                testContext.eventProcessor.record(CustomEvent(key: "recorded-meanwhile", context: testContext.context))
                expect(testContext.flushOutcome()) == false
                waitLettingTimersFire(0.5)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                testContext.serviceMock.stubEventResponse(success: true)
                testContext.serviceMock.eventStatusForPost = nil

                // The delivery the refusal set: the refused batch under the ID it was refused under, then what was
                // recorded since.
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(3), timeout: Constants.deliveryTimeout)
                expect(testContext.serviceMock.publishedEventPayloads.dropFirst().map(customKeys)) == [["refused"], ["recorded-meanwhile"]]
                expect(testContext.serviceMock.publishedPayloadIds[1]) == payloadId

                // One accepted delivery puts the backoff back: the next failure waits only the second a flush sits
                // out, so the flush hears that its retry worked.
                let posted = testContext.serviceMock.publishEventDataCallCount
                testContext.serviceMock.eventStatusForPost = { post in post == posted + 1 ? 503 : 202 }
                testContext.eventProcessor.record(CustomEvent(key: "after", context: testContext.context))
                expect(testContext.flushOutcome()) == true
            }

            it("posts what is buffered at close through the backoff's wait, though closing goes offline straight after") {
                testContext = TestContext(retryState: DeliveryRetryState(initialDelay: 1, normalCeiling: 1, extendedCeiling: 3600))
                testContext.serviceMock.respondToEvents(with: HTTPURLResponse.StatusCodes.unauthorized)
                testContext.eventProcessor.record(CustomEvent(key: "refused", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                // A refusal, after which the backoff allows nothing for about eight and a half minutes.
                expect(testContext.flushOutcome()) == false
                testContext.serviceMock.stubEventResponse(success: true)
                testContext.serviceMock.eventStatusForPost = nil
                testContext.eventProcessor.record(CustomEvent(key: "at-close", context: testContext.context))
                expect(testContext.flushOutcome()) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 1

                // What LDClient.close() does.
                testContext.eventProcessor.flushAtClose()
                testContext.eventProcessor.isOnline = false

                expect(testContext.serviceMock.publishedEventPayloads.dropFirst().flatMap(customKeys))
                    .toEventually(equal(["refused", "at-close"]), timeout: Constants.deliveryTimeout)
            }

            it("posts through the backoff's wait for a flush bypassing it, and answers whether the events got out") {
                testContext = TestContext(retryState: DeliveryRetryState(initialDelay: 1, normalCeiling: 1, extendedCeiling: 3600))
                testContext.serviceMock.respondToEvents(with: HTTPURLResponse.StatusCodes.unauthorized)
                testContext.eventProcessor.record(CustomEvent(key: "refused", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                expect(testContext.flushOutcome()) == false
                testContext.serviceMock.stubEventResponse(success: true)
                testContext.serviceMock.eventStatusForPost = nil
                testContext.eventProcessor.record(CustomEvent(key: "bypassing", context: testContext.context))

                expect(testContext.flushBypassingBackoffOutcome()) == true
                expect(testContext.serviceMock.publishedEventPayloads.dropFirst().flatMap(customKeys)) == ["refused", "bypassing"]
            }

            it("leaves ordinary flushes waiting out the backoff after a flush bypassing it is refused again") {
                testContext = TestContext(retryState: DeliveryRetryState(initialDelay: 1, normalCeiling: 1, extendedCeiling: 3600))
                testContext.serviceMock.respondToEvents(with: HTTPURLResponse.StatusCodes.unauthorized)
                testContext.eventProcessor.record(CustomEvent(key: "refused", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                expect(testContext.flushOutcome()) == false

                expect(testContext.flushBypassingBackoffOutcome()) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 2

                expect(testContext.flushOutcome()) == false
                testContext.eventProcessor.flush(completion: nil)
                waitLettingTimersFire(0.3)
                expect(testContext.serviceMock.publishEventDataCallCount) == 2
            }

            it("posts nothing for a flush bypassing the backoff while offline") {
                testContext = TestContext()
                testContext.eventProcessor.record(CustomEvent(key: "an-event", context: testContext.context))

                expect(testContext.flushBypassingBackoffOutcome()) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 0
            }

            it("posts nothing at close when the client was already offline") {
                testContext = TestContext()
                testContext.eventProcessor.record(CustomEvent(key: "an-event", context: testContext.context))

                testContext.eventProcessor.flushAtClose()
                waitLettingTimersFire(0.5)

                expect(testContext.serviceMock.publishEventDataCallCount) == 0
            }

            it("waits as long as a Retry-After asks before posting again") {
                testContext = TestContext()
                let busy = HTTPURLResponse(url: testContext.serviceMock.config.eventsUrl,
                                           statusCode: 503,
                                           httpVersion: DarklyServiceMock.Constants.httpVersion,
                                           headerFields: [HTTPURLResponse.HeaderKeys.retryAfter: "4"])
                testContext.serviceMock.stubbedEventResponse = (nil, busy, nil, nil)
                testContext.eventProcessor.record(CustomEvent(key: "an-event", context: testContext.context))
                testContext.eventProcessor.isOnline = true

                // Four seconds, jittered down to no less than two, which is past the second a flush waits out.
                expect(testContext.flushOutcome()) == false
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                testContext.serviceMock.stubEventResponse(success: true)
                waitLettingTimersFire(1.8)
                expect(testContext.serviceMock.publishEventDataCallCount) == 1
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(2), timeout: .seconds(5))
                expect(testContext.serviceMock.publishedEventPayloads.map(customKeys).last) == ["an-event"]
            }

            it("delivers events recorded during an outage after the batch refused before them, oldest first and once each") {
                testContext = TestContext(retryState: DirectEventProcessorSpec.withoutBackoff())
                testContext.serviceMock.respondToEvents(with: 503)
                testContext.eventProcessor.isOnline = true
                testContext.eventProcessor.record(CustomEvent(key: "first", context: testContext.context))
                expect(testContext.flushOutcome()) == false
                testContext.eventProcessor.record(CustomEvent(key: "second", context: testContext.context))
                expect(testContext.flushOutcome()) == false

                // Two flushes, each an attempt and a retry, all at the first batch: delivery stops at the oldest batch
                // that fails in a way that may pass.
                expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == Array(repeating: ["first"], count: 4)

                testContext.serviceMock.stubEventResponse(success: true)
                expect(testContext.flushOutcome()) == true

                expect(testContext.serviceMock.publishedEventPayloads.dropFirst(4).map(customKeys)) == [["first"], ["second"]]
            }

            // A batch per flush would grow without bound for as long as an outage lasts: files on the disk, or batches
            // held in memory, each with a summary of its own.
            for persistence in [EventPersistence.immediate, .disabled] {
                it("closes no batch behind the one blocked during an outage, persistence: \(persistence)") {
                    testContext = TestContext(store: EventStore.temporary(persistEvents: persistence != .disabled),
                                              eventPersistence: persistence,
                                              retryState: DirectEventProcessorSpec.withoutBackoff())
                    testContext.serviceMock.respondToEvents(with: 503)
                    testContext.eventProcessor.isOnline = true
                    testContext.eventProcessor.record(CustomEvent(key: "blocked", context: testContext.context))
                    for flush in 0..<3 {
                        expect(testContext.flushOutcome()) == false
                        testContext.eventProcessor.record(CustomEvent(key: "during-\(flush)", context: testContext.context))
                    }
                    // The attempt and its retry for each flush, all of the batch at the head.
                    expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == Array(repeating: ["blocked"], count: 6)
                    expect(testContext.store.listPendingBatches().batches.count) == 1

                    testContext.serviceMock.stubEventResponse(success: true)
                    expect(testContext.flushOutcome()) == true

                    expect(testContext.serviceMock.publishedEventPayloads.dropFirst(6).map(customKeys))
                        == [["blocked"], ["during-0", "during-1", "during-2"]]
                    expect(testContext.store.listPendingBatches().batches).to(beEmpty())
                }

                // Every flush of an outage is a commit point, and each stages a summary of the evaluations since the
                // last. Counted as events, they would leave a long outage refusing every track.
                it("leaves room for events beside the summaries an outage writes, persistence: \(persistence)") {
                    testContext = TestContext(lastEventResponseDate: Date(),
                                              store: EventStore.temporary(capacity: 2, persistEvents: persistence != .disabled),
                                              eventCapacity: 2, eventPersistence: persistence,
                                              retryState: DirectEventProcessorSpec.withoutBackoff())
                    testContext.serviceMock.respondToEvents(with: 503)
                    testContext.eventProcessor.isOnline = true
                    testContext.eventProcessor.record(CustomEvent(key: "blocked", context: testContext.context))
                    expect(testContext.flushOutcome()) == false
                    let flag = FeatureFlag(flagKey: "flag-key", value: nil, variation: 1, flagVersion: 2, trackEvents: false)
                    for _ in 0..<3 {
                        testContext.eventProcessor.recordFlagEvaluationEvents(flagKey: "flag-key", value: "a", defaultValue: "b", featureFlag: flag, context: testContext.context, includeReason: false)
                        expect(testContext.flushOutcome()) == false
                    }

                    testContext.eventProcessor.record(CustomEvent(key: "after-the-summaries", context: testContext.context))
                    testContext.serviceMock.stubEventResponse(success: true)
                    expect(testContext.flushOutcome()) == true
                    expect(testContext.serviceMock.publishedEventPayloads.flatMap(customKeys))
                        .to(contain("after-the-summaries"), description: "refused for room the summaries took")
                }
            }

            it("does not tell a flush its events arrived when an earlier delivery nobody waited on failed to send them") {
                testContext = TestContext()
                testContext.serviceMock.respondToEvents(with: 503)
                testContext.eventProcessor.record(CustomEvent(key: "kept", context: testContext.context))
                testContext.eventProcessor.isOnline = true

                // Stands in for the scheduled delivery, or the one at backgrounding: it closes the event into a batch,
                // fails to send it, and keeps it.
                waitUntil(timeout: .seconds(10)) { done in
                    testContext.eventProcessor.flush(completion: done)
                }
                expect(testContext.serviceMock.publishEventDataCallCount) == 2

                // There is nothing left to close, but the event is still waiting in its batch, not delivered.
                expect(testContext.flushOutcome()) == false
            }

            it("starts a delivery asked for while a refused post waits to retry once that retry is answered") {
                testContext = TestContext()
                testContext.serviceMock.respondToEvents(with: 503)
                testContext.eventProcessor.record(CustomEvent(key: "kept", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                testContext.eventProcessor.flush(completion: nil)
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: Constants.deliveryTimeout)

                // Well inside the one-second retry delay. The retry belongs to the delivery still running, so this
                // one waits for it rather than posting beside it.
                let answer = Answer()
                testContext.eventProcessor.flushReportingOutcome(completion: answer.record)
                Thread.sleep(forTimeInterval: 0.3)
                expect(testContext.eventProcessor.startedDeliveryCount) == 1

                // One retry and no more; the delivery behind it finds the backoff still waiting, and the batch then
                // waits for the delivery that wait sets.
                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(2), timeout: .seconds(3))
                expect(testContext.eventProcessor.startedDeliveryCount).toEventually(equal(2), timeout: Constants.deliveryTimeout)
                expect(answer.value()).toEventually(beFalse(), timeout: Constants.deliveryTimeout)
                waitLettingTimersFire(1.5)
                expect(testContext.serviceMock.publishEventDataCallCount) == 2
            }

            it("sends events recorded while offline with the next scheduled delivery") {
                testContext = TestContext(eventFlushInterval: Constants.eventFlushIntervalHalfSecond)
                testContext.eventProcessor.record(CustomEvent(key: "held", context: testContext.context))
                waitLettingTimersFire(2 * Constants.eventFlushIntervalHalfSecond)
                expect(testContext.serviceMock.publishEventDataCallCount) == 0

                testContext.eventProcessor.isOnline = true

                expect(testContext.serviceMock.publishEventDataCallCount).toEventually(equal(1), timeout: .seconds(3))
                expect(testContext.serviceMock.publishedEventPayloads.map(customKeys)) == [["held"]]
            }

            it("posts a refused batch no more often than the backoff allows, and not at all once offline") {
                let interval = 0.2
                let window = 2.5
                testContext = TestContext(eventFlushInterval: interval)
                testContext.serviceMock.respondToEvents(with: 503)
                testContext.eventProcessor.record(CustomEvent(key: "refused", context: testContext.context))
                testContext.eventProcessor.isOnline = true
                waitLettingTimersFire(window)

                // At most one post a second, the backoff's ceiling where the interval is shorter; a loop would be in the
                // hundreds by now.
                let posts = testContext.serviceMock.publishEventDataCallCount
                expect(posts) >= 2
                expect(posts) <= Int(window / 1.0) + 1

                // Offline stops it entirely, kept batch or not. Waits out a retry already scheduled before counting.
                testContext.eventProcessor.isOnline = false
                waitLettingTimersFire(1.0 + interval)
                let whenOffline = testContext.serviceMock.publishEventDataCallCount
                waitLettingTimersFire(interval * 3)
                expect(testContext.serviceMock.publishEventDataCallCount) == whenOffline
            }
        }
    }
}

/// The events a store is holding, as JSON with `creationDate` dropped.
///
/// Dropping the timestamp is what lets an expectation be written as the event the SDK should have produced, rather than
/// as a list of whichever fields the test remembered to check: the recorded event and the expected one are constructed
/// moments apart and differ only in when they were made.
private func recordedEvents(_ store: EventStore) -> [LDValue] {
    store.pendingEventPayloads()
        .compactMap { try? JSONDecoder().decode(LDValue.self, from: $0) }
        .map(withoutCreationDate)
}

/// How many evaluations a summary event counts, across all of its flags and variations.
private func summaryCount(_ summary: LDValue) -> Int {
    guard case .object(let fields) = summary, case .object(let features)? = fields["features"]
    else { return 0 }
    var total = 0
    for case .object(let flag) in features.values {
        guard case .array(let counters)? = flag["counters"] else { continue }
        for case .object(let counter) in counters {
            if case .number(let count)? = counter["count"] {
                total += Int(count)
            }
        }
    }
    return total
}

/// A custom event whose encoding waits to be let through, so a test can act while a commit is encoding it.
private final class EncodingGate: CustomEvent {
    let started = DispatchSemaphore(value: 0)
    let proceed = DispatchSemaphore(value: 0)

    override func encode(to encoder: Encoder) throws {
        started.signal()
        _ = proceed.wait(timeout: .now() + 5)
        try super.encode(to: encoder)
    }
}

/// A store that runs a hook on either side of closing a batch, and remembers the custom event keys of each batch closed.
private final class ClosingHookStore: EventStoring {
    let inner: EventStoring
    var beforeClosing: (() -> Void)?
    var afterClosing: (() -> Void)?
    /// Runs at the start of every commit.
    var beforeCommitting: (() -> Void)?
    private(set) var closedKeys: [[String]] = []

    init(_ inner: EventStoring) {
        self.inner = inner
    }

    var pendingEventCount: Int { inner.pendingEventCount }
    var hasRoomForEventBytes: Bool { inner.hasRoomForEventBytes }
    func admitsEvent(heldElsewhere: Int, capacity: Int) -> Bool { inner.admitsEvent(heldElsewhere: heldElsewhere, capacity: capacity) }
    var isPersisting: Bool { inner.isPersisting }
    func stage(_ encodedEvent: Data, bypassingCapacity: Bool) -> Bool { inner.stage(encodedEvent, bypassingCapacity: bypassingCapacity) }
    func reserve(_ events: Int) { inner.reserve(events) }
    func stageReserved(_ encodedEvent: Data) -> Bool { inner.stageReserved(encodedEvent) }
    func releaseReservations() { inner.releaseReservations() }
    func commit() {
        beforeCommitting?()
        inner.commit()
    }
    var holdsUnclosedEvents: Bool { inner.holdsUnclosedEvents }
    func takeVanishedLogEvents() -> Int { inner.takeVanishedLogEvents() }
    func listPendingBatches() -> BatchListing { inner.listPendingBatches() }
    func payload(of batch: EventBatch) throws -> BatchPayload? { try inner.payload(of: batch) }
    func remove(_ batch: EventBatch) { inner.remove(batch) }
    func startedSending(_ batch: EventBatch) { inner.startedSending(batch) }
    func stoppedSending(_ batch: EventBatch) { inner.stoppedSending(batch) }
    func preparePayloadsFromInterruptedLogs() { inner.preparePayloadsFromInterruptedLogs() }
    func discardExpired() -> Int { inner.discardExpired() }

    func closeBatch() -> EventBatch? {
        let before = beforeClosing
        beforeClosing = nil
        before?()
        let batch = inner.closeBatch()
        if let batch, let body = try? inner.body(of: batch) {
            closedKeys.append(customKeys(body))
        }
        let after = afterClosing
        afterClosing = nil
        after?()
        return batch
    }
}

/// What a flush was told, written from whichever thread answered it and read from the test's.
private final class Answer {
    private let lock = UnfairLock()
    private var answered: Bool?

    /// Pass as a `FlushOutcomeClosure`.
    func record(_ delivered: Bool) {
        lock.withLock { answered = delivered }
    }

    /// Nil until the flush has been answered.
    func value() -> Bool? {
        lock.withLock { answered }
    }
}

/// Reads that fail for one batch, as they do once a permission is taken away, counted. Set from the test's thread and
/// read on the reporter's.
private final class FailingReads {
    private let lock = UnfairLock()
    private var payloadId: String?
    private var failed = 0

    /// Fails every read of the batch from here on, or none where nil.
    func fail(_ payloadId: String?) {
        lock.withLock { self.payloadId = payloadId }
    }

    var failures: Int {
        lock.withLock { failed }
    }

    /// Pass as the store's `readFile`.
    func read(_ url: URL) throws -> Data {
        let fails = lock.withLock { () -> Bool in
            guard let payloadId, url.lastPathComponent.contains(payloadId)
            else { return false }
            failed += 1
            return true
        }
        if fails {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        }
        return try Data(contentsOf: url)
    }
}

/// What a run of flushes were told, written from whichever threads answered them and read from the test's.
private final class Answers {
    private let lock = UnfairLock()
    private var answered: [Bool] = []

    /// Pass as a `FlushOutcomeClosure`.
    func record(_ delivered: Bool) {
        lock.withLock { answered.append(delivered) }
    }

    /// In the order the flushes were answered, which is not the order they were asked in.
    func value() -> [Bool] {
        lock.withLock { answered }
    }
}

/// A store that holds a listing open, so a test can see what else is waiting while one is under way.
private final class SlowListingStore: EventStoring {
    let inner: EventStoring
    /// Signalled once a listing is being held.
    let listing = DispatchSemaphore(value: 0)
    /// Signal to let it finish.
    let release = DispatchSemaphore(value: 0)

    private let lock = UnfairLock()
    private var listings = 0

    init(_ inner: EventStoring) {
        self.inner = inner
    }

    var pendingEventCount: Int { inner.pendingEventCount }
    var hasRoomForEventBytes: Bool { inner.hasRoomForEventBytes }
    func admitsEvent(heldElsewhere: Int, capacity: Int) -> Bool { inner.admitsEvent(heldElsewhere: heldElsewhere, capacity: capacity) }
    var isPersisting: Bool { inner.isPersisting }
    func stage(_ encodedEvent: Data, bypassingCapacity: Bool) -> Bool { inner.stage(encodedEvent, bypassingCapacity: bypassingCapacity) }
    func reserve(_ events: Int) { inner.reserve(events) }
    func stageReserved(_ encodedEvent: Data) -> Bool { inner.stageReserved(encodedEvent) }
    func releaseReservations() { inner.releaseReservations() }
    func commit() { inner.commit() }
    func closeBatch() -> EventBatch? { inner.closeBatch() }
    var holdsUnclosedEvents: Bool { inner.holdsUnclosedEvents }
    func takeVanishedLogEvents() -> Int { inner.takeVanishedLogEvents() }
    func payload(of batch: EventBatch) throws -> BatchPayload? { try inner.payload(of: batch) }
    func remove(_ batch: EventBatch) { inner.remove(batch) }
    func startedSending(_ batch: EventBatch) { inner.startedSending(batch) }
    func stoppedSending(_ batch: EventBatch) { inner.stoppedSending(batch) }
    func preparePayloadsFromInterruptedLogs() { inner.preparePayloadsFromInterruptedLogs() }
    func discardExpired() -> Int { inner.discardExpired() }

    /// Every listing but the first is held, the first being the one the reporter makes as it starts up.
    func listPendingBatches() -> BatchListing {
        let held = lock.withLock { () -> Bool in
            listings += 1
            return listings > 1
        }
        if held {
            listing.signal()
            _ = release.wait(timeout: .now() + 5)
            // Once opened the gate stays open.
            release.signal()
        }
        return inner.listPendingBatches()
    }
}

/// Waits while letting the main run loop turn, since that is where the report timer fires.
private func waitLettingTimersFire(_ seconds: TimeInterval) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

private func customKeys(_ body: Data) -> [String] {
    guard case .array(let events)? = try? JSONDecoder().decode(LDValue.self, from: body)
    else { return [] }
    return events.compactMap { event in
        guard event.kindField == "custom", case .object(let fields) = event, case .string(let key) = fields["key"]
        else { return nil }
        return key
    }
}

private func expectedEvents(_ events: [Event]) -> [LDValue] {
    events.compactMap { encodeToLDValue($0) }.map(withoutCreationDate)
}

private func withoutCreationDate(_ value: LDValue) -> LDValue {
    guard case .object(var fields) = value
    else { return value }
    fields["creationDate"] = nil
    return .object(fields)
}

private extension LDValue {
    var kindField: String? {
        guard case .object(let fields) = self, case .string(let kind) = fields["kind"]
        else { return nil }
        return kind
    }

    var keyField: String? {
        guard case .object(let fields) = self, case .string(let key) = fields["key"]
        else { return nil }
        return key
    }
}

private extension DarklyServiceMock {
    /// Answers every event post with this status and no error, the way a service that is reachable answers.
    func respondToEvents(with status: Int) {
        stubbedEventResponse = (nil,
                                HTTPURLResponse(url: config.eventsUrl, statusCode: status, httpVersion: Constants.httpVersion, headerFields: nil),
                                nil,
                                nil)
    }
}

private extension Date {
    var adjustedForHttpUrlHeaderUse: Date {
        let headerDateFormatter = DateFormatter.httpUrlHeaderFormatter
        let dateString = headerDateFormatter.string(from: self)
        return headerDateFormatter.date(from: dateString) ?? self
    }
}

extension Event.Kind {
    static var nonSummaryKinds: [Event.Kind] {
        [feature, debug, identify, custom]
    }
}

/// `DirectEventProcessorSpec` with persistence off, which is what an application gets by default.
final class DirectEventProcessorWithoutPersistenceSpec: DirectEventProcessorSpec {
    override class var persistence: EventPersistence { .disabled }
}
