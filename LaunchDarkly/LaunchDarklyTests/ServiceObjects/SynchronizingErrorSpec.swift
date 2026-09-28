import Foundation
import XCTest

import LDSwiftEventSource
@testable import LaunchDarkly

final class SynchronizingErrorSpec: XCTestCase {
    private let falseCases: [SynchronizingError] =
        [.isOffline,
         .streamEventWhilePolling,
         .data(nil),
         .data("data".data(using: .utf8)),
         .request(DummyError()),
         .unknownEventType("update"),
         .response(HTTPURLResponse(url: LDConfig.stub.streamUrl,
                                   statusCode: HTTPURLResponse.StatusCodes.internalServerError,
                                   httpVersion: "1.1",
                                   headerFields: nil)),
         .streamError(UnsuccessfulResponseError(responseCode: 500))
         ]
    private let trueCases: [SynchronizingError] =
        [.response(HTTPURLResponse(url: LDConfig.stub.streamUrl,
                                   statusCode: HTTPURLResponse.StatusCodes.unauthorized,
                                   httpVersion: "1.1",
                                   headerFields: nil)),
         .streamError(UnsuccessfulResponseError(responseCode: 401))
         ]

    func testErrorShouldBeUnauthorized() {
        trueCases.forEach { testValue in
            XCTAssertTrue(testValue.isClientUnauthorized, "\(testValue) should be unauthorized")
        }
    }

    func testErrorShouldNotBeUnauthorized() {
        falseCases.forEach { testValue in
            XCTAssertFalse(testValue.isClientUnauthorized, "\(testValue) should not be unauthorized")
        }
    }

    private func httpURLResponse(_ statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: LDConfig.stub.streamUrl, statusCode: statusCode, httpVersion: "1.1", headerFields: nil)!
    }

    func testErrorShouldBeTerminal() {
        let terminalCases: [SynchronizingError] = [
            .response(httpURLResponse(401)),
            .response(httpURLResponse(403)),
            .response(httpURLResponse(404)),
            .streamError(UnsuccessfulResponseError(responseCode: 401)),
            .streamError(UnsuccessfulResponseError(responseCode: 403))
        ]
        terminalCases.forEach { testValue in
            XCTAssertTrue(testValue.isTerminal, "\(testValue) should be terminal")
        }
    }

    func testErrorShouldNotBeTerminal() {
        let nonTerminalCases: [SynchronizingError] = [
            .isOffline,
            .streamEventWhilePolling,
            .data(nil),
            .request(DummyError()),
            .unknownEventType("update"),
            .response(httpURLResponse(400)),
            .response(httpURLResponse(429)),
            .response(httpURLResponse(500)),
            .streamError(UnsuccessfulResponseError(responseCode: 408)),
            .streamError(UnsuccessfulResponseError(responseCode: 500))
        ]
        nonTerminalCases.forEach { testValue in
            XCTAssertFalse(testValue.isTerminal, "\(testValue) should not be terminal")
        }
    }
}

struct DummyError: Error { }
