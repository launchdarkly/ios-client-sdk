//
//  ErrorObserverSpec.swift
//  DarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class ErrorOwnerMock {
    var errors = [Error]()
    func handle(error: Error) {
        errors.append(error)
    }
}

final class ErrorObserverSpec: QuickSpec {

    override func spec() {
        initSpec()
        equalSpec()
    }

    private func initSpec() {
        var errorOwner: ErrorOwnerMock?
        var errorObserver: ErrorObserver!
        describe("init") {
            beforeEach {
                errorOwner = ErrorOwnerMock()
                errorObserver = ErrorObserver(owner: errorOwner!, errorHandler: errorOwner!.handle)
            }
            it("sets the error owner") {
                expect(errorObserver.key).toNot(beNil())
                expect(errorObserver.owner) === errorOwner
                expect(errorObserver.errorHandler).toNot(beNil())
            }
        }
    }

    private func equalSpec() {
        var errorOwner: ErrorOwnerMock?
        var errorObserver: ErrorObserver!
        describe("equals") {
            context("same observer") {
                beforeEach {
                    errorOwner = ErrorOwnerMock()
                    errorObserver = ErrorObserver(owner: errorOwner!, errorHandler: errorOwner!.handle)
                }
                it("returns true") {
                    expect(errorObserver == errorObserver) == true
                }
            }
            context("same observer") {
                var otherErrorObserver: ErrorObserver!
                beforeEach {
                    errorOwner = ErrorOwnerMock()
                    errorObserver = ErrorObserver(owner: errorOwner!, errorHandler: errorOwner!.handle)
                    otherErrorObserver = ErrorObserver(owner: errorOwner!, errorHandler: errorOwner!.handle)
                }
                it("returns false") {
                    expect(errorObserver == otherErrorObserver) == false
                }
            }
        }
    }
}
