//
//  SynchronizingErrorSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
import LDSwiftEventSource
@testable import LaunchDarkly

final class SynchronizingErrorSpec: QuickSpec {
    override func spec() {
        isUnauthorizedSpec()
    }

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

    func isUnauthorizedSpec() {
        describe("isUnauthorized") {
            falseCases.forEach { testValue in
                context("with error: \(testValue)") {
                    it("returns false") {
                        expect(testValue.isClientUnauthorized) == false
                    }
                }
            }
            trueCases.forEach { testValue in
                context("with error: \(testValue)") {
                    it("returns true") {
                        expect(testValue.isClientUnauthorized) == true
                    }
                }
            }
        }
    }
}

struct DummyError: Error { }
