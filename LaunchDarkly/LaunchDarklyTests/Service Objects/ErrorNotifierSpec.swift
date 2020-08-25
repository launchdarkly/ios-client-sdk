//
//  ErrorNotifyingSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation
import XCTest

@testable import LaunchDarkly

final class ErrorNotifierSpec: XCTestCase {

    func testInit() {
        let errorNotifier = ErrorNotifier()
        XCTAssertEqual(errorNotifier.errorObservers.count, 0)
    }

    func testAddErrorObserver() {
        let errorNotifier = ErrorNotifier()
        for index in 0..<4 {
            let owner = ErrorOwnerMock()
            errorNotifier.addErrorObserver(ErrorObserver(owner: owner, errorHandler: { _ in }))
            XCTAssertEqual(errorNotifier.errorObservers.count, index + 1)
            XCTAssert(errorNotifier.errorObservers[index].owner === owner)
        }
    }

    func testRemoveObserversNoObservers() {
        let errorNotifier = ErrorNotifier()
        let owner = ErrorOwnerMock()
        errorNotifier.removeObservers(for: owner)
        XCTAssertEqual(errorNotifier.errorObservers.count, 0)
    }

    func testRemoveObserversMatchingAll() {
        let errorNotifier = ErrorNotifier()
        let owner = ErrorOwnerMock()
        errorNotifier.addErrorObserver(ErrorObserver(owner: owner, errorHandler: { _ in }))
        errorNotifier.removeObservers(for: owner)
        XCTAssertEqual(errorNotifier.errorObservers.count, 0)
    }

    func testRemoveObserversMatchingNone() {
        let errorNotifier = ErrorNotifier()
        (0..<4).forEach { _ in
            errorNotifier.addErrorObserver(ErrorObserver(owner: ErrorOwnerMock(), errorHandler: { _ in }))
        }
        let owner = ErrorOwnerMock()
        errorNotifier.removeObservers(for: owner)
        XCTAssertEqual(errorNotifier.errorObservers.count, 4)
    }

    func testRemoveObserversMatchingSome() {
        let errorNotifier = ErrorNotifier()
        let owner = ErrorOwnerMock()
        (0..<4).forEach { _ in
            errorNotifier.addErrorObserver(ErrorObserver(owner: ErrorOwnerMock(), errorHandler: { _ in }))
            errorNotifier.addErrorObserver(ErrorObserver(owner: owner, errorHandler: { _ in }))
        }
        errorNotifier.removeObservers(for: owner)
        XCTAssertEqual(errorNotifier.errorObservers.count, 4)
        XCTAssert(!errorNotifier.errorObservers.contains { $0.owner === owner })
    }

    func testNotifyObservers() {
        let errorNotifier = ErrorNotifier()
        let owner = ErrorOwnerMock()
        var otherOwners: [ErrorOwnerMock] = []
        (0..<4).forEach { _ in
            let newOwner = ErrorOwnerMock()
            otherOwners.append(newOwner)
            errorNotifier.addErrorObserver(ErrorObserver(owner: newOwner, errorHandler: newOwner.handle))
            errorNotifier.addErrorObserver(ErrorObserver(owner: owner, errorHandler: owner.handle))
        }
        errorNotifier.erase(owner: owner)
        let errorMock = ErrorMock()
        errorNotifier.notifyObservers(of: errorMock)
        XCTAssertEqual(errorNotifier.errorObservers.count, 4)
        XCTAssert(!errorNotifier.errorObservers.contains { $0.owner === owner })
        XCTAssertEqual(owner.errors.count, 0)
        for owner in otherOwners {
            XCTAssertEqual(owner.errors.count, 1)
            XCTAssert(owner.errors[0] as? ErrorMock === errorMock)
        }
    }
}

private class ErrorMock: Error { }
