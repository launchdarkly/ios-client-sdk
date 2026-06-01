import Foundation
import OSLog
import Quick
import Nimble
import LDSwiftEventSource
import XCTest
@testable import LaunchDarkly

final class LDClientTrackHookSpec: XCTestCase {
    func testAfterTrackIsCalled() {
        var count = 0
        let hook = MockTrackHook(afterTrack: { _ in count += 1 })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [hook]
        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        testContext.subject.track(key: "event-key")
        expect(count).toEventually(equal(1))
    }

    func testAfterTrackReceivesContext() {
        var captured: TrackSeriesContext? = nil
        let hook = MockTrackHook(afterTrack: { sc in captured = sc })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [hook]
        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        let data: LDValue = ["some-key": "some-value"]
        testContext.subject.track(key: "event-key", data: data, metricValue: 2.5)

        expect(captured).toEventuallyNot(beNil())
        expect(captured?.key).to(equal("event-key"))
        expect(captured?.data).to(equal(data))
        expect(captured?.metricValue).to(equal(2.5))
        expect(captured?.context.fullyQualifiedKey()).to(equal(testContext.subject.context.fullyQualifiedKey()))
    }

    func testTrackHookOrder() {
        var callRecord: [String] = []
        let firstHook = MockTrackHook(afterTrack: { _ in callRecord.append("first afterTrack") })
        let secondHook = MockTrackHook(afterTrack: { _ in callRecord.append("second afterTrack") })
        var config = LDConfig(mobileKey: "mobile-key", autoEnvAttributes: .disabled)
        config.hooks = [firstHook, secondHook]

        var testContext: TestContext!
        waitUntil { done in
            testContext = TestContext(newConfig: config)
            testContext.start(completion: done)
        }

        testContext.subject.track(key: "event-key")
        // The track series has only an after stage, so hooks run in registration order
        // (as required by the shared SDK contract tests).
        expect(callRecord).toEventually(equal(["first afterTrack", "second afterTrack"]))
    }

    typealias AfterTrackHook = (_: TrackSeriesContext) -> Void

    class MockTrackHook: Hook {
        let afterTrackHandler: AfterTrackHook

        init(afterTrack: @escaping AfterTrackHook) {
            self.afterTrackHandler = afterTrack
        }

        func metadata() -> LaunchDarkly.Metadata {
            return Metadata(name: "track-hook")
        }

        func afterTrack(seriesContext: LaunchDarkly.TrackSeriesContext) {
            self.afterTrackHandler(seriesContext)
        }
    }
}
