//
//  ErrorObserverSpec.swift
//  DarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import XCTest

@testable import LaunchDarkly

final class ErrorObserverContext {
    var owner: ErrorObserverOwner? = ErrorObserverOwner()
    var errors = [Error]()

    func handler(error: Error) { errors.append(error) }
    func observer() -> ErrorObserver { ErrorObserver(owner: owner!, errorHandler: handler) }
}

class ErrorObserverOwner { }
private class ErrorMock: Error { }

final class ErrorObserverSpec: XCTestCase {
    func testInit() {
        let context = ErrorObserverContext()
        let errorObserver = context.observer()
        XCTAssert(errorObserver.owner === context.owner)
        XCTAssertNotNil(errorObserver.errorHandler)

        let errorMock = ErrorMock()
        errorObserver.errorHandler(errorMock)
        XCTAssertEqual(context.errors.count, 1)
        XCTAssert(context.errors[0] as? ErrorMock === errorMock)
    }
}
