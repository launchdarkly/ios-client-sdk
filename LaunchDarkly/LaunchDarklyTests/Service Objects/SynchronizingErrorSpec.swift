//
//  SynchronizingErrorSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 2/27/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import DarklyEventSource
@testable import LaunchDarkly

final class SynchronizingErrorSpec: QuickSpec {
    override func spec() {
        isUnauthorizedSpec()
    }

    func isUnauthorizedSpec() {
        let config = LDConfig.stub
        var subject: SynchronizingError!
        describe("isUnauthorized") {
            context("when created with a 401 URL response") {
                beforeEach {
                    subject = .response(HTTPURLResponse(url: config.streamUrl, statusCode: HTTPURLResponse.StatusCodes.unauthorized, httpVersion: "1.1", headerFields: nil))
                }
                it("returns true") {
                    expect(subject.isClientUnauthorized) == true
                }
            }
            context("when created with a isUnauthorized event") {
                beforeEach {
                    subject = .event(DarklyEventSource.LDEvent.stubUnauthorizedEvent())
                }
                it("returns true") {
                    expect(subject.isClientUnauthorized) == true
                }
            }
            context("when created with a request error") {
                beforeEach {
                    subject = .request(DummyError())
                }
                it("returns false") {
                    expect(subject.isClientUnauthorized) == false
                }
            }
            context("when created with a 500 URL response") {
                beforeEach {
                    subject = .response(HTTPURLResponse(url: config.streamUrl, statusCode: HTTPURLResponse.StatusCodes.internalServerError, httpVersion: "1.1", headerFields: nil))
                }
                it("returns false") {
                    expect(subject.isClientUnauthorized) == false
                }
            }
            context("when created with a data error") {
                beforeEach {
                    subject = .data(nil)
                }
                it("returns false") {
                    expect(subject.isClientUnauthorized) == false
                }
            }
            context("when created with a non-isUnauthorized event") {
                beforeEach {
                    subject = .event(DarklyEventSource.LDEvent.stubErrorEvent())
                }
                it("returns false") {
                    expect(subject.isClientUnauthorized) == false
                }
            }
        }
    }
}

struct DummyError: Error { }
