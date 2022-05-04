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
}

struct DummyError: Error { }
