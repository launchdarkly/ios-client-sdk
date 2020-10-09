//
//  ErrorObserverSpec.swift
//  DarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import XCTest

@testable import LaunchDarkly

final class ErrorOwnerMock {
    var errors = [Error]()
    func handle(error: Error) {
        errors.append(error)
    }
}

private class ErrorMock: Error { }

final class ErrorObserverSpec: XCTestCase {
    func testInit() {
        let errorOwner = ErrorOwnerMock()
        let errorObserver = ErrorObserver(owner: errorOwner, errorHandler: errorOwner.handle)
        XCTAssert(errorObserver.owner === errorOwner)

        let errorMock = ErrorMock()
        XCTAssertNotNil(errorObserver.errorHandler)
        errorObserver.errorHandler?(errorMock)
        XCTAssertEqual(errorOwner.errors.count, 1)
        XCTAssert(errorOwner.errors[0] as? ErrorMock === errorMock)
    }
}
