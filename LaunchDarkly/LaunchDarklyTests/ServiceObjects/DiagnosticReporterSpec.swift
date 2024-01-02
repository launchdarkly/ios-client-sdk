import Foundation
import XCTest

@testable import LaunchDarkly

final class DiagnosticReporterSpec: XCTestCase {
    final class TestContext {
        let awaiter = DispatchSemaphore(value: 0)
        let cachingMock = DiagnosticCachingMock()
        let diagnosticId = DiagnosticId(diagnosticId: "abc", sdkKey: "fake_mobile_key")
        var queuedResponses: [ServiceResponse] = []
        var receivedEvents: [DiagnosticEvent] = []
        var subject: DiagnosticReporter
        var service: DarklyServiceMock

        init() {
            service = DarklyServiceMock()
            subject = DiagnosticReporter(service: service, environmentReporting: EnvironmentReportingMock())

            cachingMock.getDiagnosticIdReturnValue = diagnosticId
            service.diagnosticCache = cachingMock
            service.publishDiagnosticCallback = {
                if self.queuedResponses.first != nil {
                    self.service.stubbedDiagnosticResponse = self.queuedResponses.removeFirst()
                } else {
                    XCTFail("Unexpected request to diagnostic endpoint during test")
                }
                XCTAssertNotNil(self.service.stubbedDiagnosticResponse)
                self.receivedEvents.append(self.service.publishedDiagnostic!)
                self.awaiter.signal()
            }
        }

        func queueResponse(status: Int? = nil, withError: Bool = false) {
            var response: HTTPURLResponse? = nil
            var error: Error? = nil
            if let status = status {
                response = HTTPURLResponse(url: service.config.eventsUrl,
                                           statusCode: status,
                                           httpVersion: DarklyServiceMock.Constants.httpVersion,
                                           headerFields: [:])
            }
            if withError {
                error = DarklyServiceMock.Constants.error
            }
            queuedResponses.append((nil, response, error, nil))
        }

        func takeEvent() -> DiagnosticEvent {
            awaiter.wait()
            if receivedEvents.first == nil {
                XCTFail("Missing expected diagnostic event")
            }
            return receivedEvents.remove(at: 0)
        }

        func expectNoEvent() {
            XCTAssertEqual(awaiter.wait(timeout: DispatchTime.now() + 0.1), .timedOut)
            XCTAssertTrue(receivedEvents.isEmpty)
        }
    }

    func testInitEvent() {
        let tst = TestContext()
        tst.queueResponse(status: 202)
        tst.subject.setMode(.foreground, online: true)

        let published = tst.takeEvent()
        XCTAssertEqual(published.kind, .diagnosticInit)
        XCTAssertEqual(published.id.diagnosticId, tst.diagnosticId.diagnosticId)
        XCTAssertEqual(published.id.sdkKeySuffix, tst.diagnosticId.sdkKeySuffix)
        XCTAssertTrue(published is DiagnosticInit)

        // Test that init is not sent again when client changes online state
        tst.subject.setMode(.foreground, online: true)
        tst.subject.setMode(.foreground, online: false)
        tst.subject.setMode(.foreground, online: true)

        tst.expectNoEvent()
    }

    func testInitInBackground() {
        let tst = TestContext()
        tst.queueResponse(status: 202)
        tst.subject.setMode(.background, online: true)
        // Should not send init event while in background, even if set to background again.
        tst.subject.setMode(.background, online: true)

        tst.expectNoEvent()

        // Should sent init once in foreground
        tst.subject.setMode(.foreground, online: true)
        let published = tst.takeEvent()
        XCTAssertEqual(published.kind, .diagnosticInit)
        XCTAssertEqual(published.id.diagnosticId, tst.diagnosticId.diagnosticId)
        XCTAssertEqual(published.id.sdkKeySuffix, tst.diagnosticId.sdkKeySuffix)
        XCTAssertTrue(published is DiagnosticInit)
    }

    func testLastStatsSent() {
        let tst = TestContext()
        let now = Date().millisSince1970
        let stats = DiagnosticStats(id: tst.diagnosticId, creationDate: now, dataSinceDate: now, droppedEvents: 0, eventsInLastBatch: 0, streamInits: [])
        tst.cachingMock.lastStats = stats
        tst.queueResponse(status: 202)
        tst.queueResponse(status: 202)
        tst.subject.setMode(.foreground, online: true)

        var published = tst.takeEvent()
        XCTAssertEqual(published.kind, .diagnosticStats)
        XCTAssertEqual(published.id.diagnosticId, tst.diagnosticId.diagnosticId)
        XCTAssertTrue(published is DiagnosticStats)
        if let published = published as? DiagnosticStats {
            XCTAssertEqual(published.creationDate, now)
        }

        published = tst.takeEvent()
        XCTAssertEqual(published.kind, .diagnosticInit)
        XCTAssertEqual(published.id.diagnosticId, tst.diagnosticId.diagnosticId)
        XCTAssertEqual(published.id.sdkKeySuffix, tst.diagnosticId.sdkKeySuffix)
        XCTAssertTrue(published is DiagnosticInit)

        tst.expectNoEvent()
    }

    func testRetries() {
        let tst = TestContext()
        tst.queueResponse(status: 500)
        tst.queueResponse(withError: true)
        tst.subject.setMode(.foreground, online: true)

        var published = tst.takeEvent()
        XCTAssertEqual(published.kind, .diagnosticInit)
        published = tst.takeEvent()
        XCTAssertEqual(published.kind, .diagnosticInit)

        tst.expectNoEvent()
    }
}
