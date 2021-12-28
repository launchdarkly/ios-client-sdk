import Foundation
import XCTest

@testable import LaunchDarkly

final class ErrorNotifierSpec: XCTestCase {
    func testAddAndRemoveObservers() {
        let errorNotifier = ErrorNotifier()
        XCTAssertEqual(errorNotifier.errorObservers.count, 0)

        errorNotifier.removeObservers(for: ErrorObserverOwner())
        XCTAssertEqual(errorNotifier.errorObservers.count, 0)

        let firstContext = ErrorObserverContext()
        let secondContext = ErrorObserverContext()
        errorNotifier.addErrorObserver(firstContext.observer())
        errorNotifier.addErrorObserver(secondContext.observer())
        errorNotifier.addErrorObserver(firstContext.observer())
        errorNotifier.addErrorObserver(secondContext.observer())
        XCTAssertEqual(errorNotifier.errorObservers.count, 4)

        errorNotifier.removeObservers(for: ErrorObserverOwner())
        XCTAssertEqual(errorNotifier.errorObservers.count, 4)

        errorNotifier.removeObservers(for: firstContext.owner!)
        XCTAssertEqual(errorNotifier.errorObservers.count, 2)
        XCTAssert(!errorNotifier.errorObservers.contains { $0.owner !== secondContext.owner })

        errorNotifier.removeObservers(for: secondContext.owner!)
        XCTAssertEqual(errorNotifier.errorObservers.count, 0)

        XCTAssertEqual(firstContext.errors.count, 0)
        XCTAssertEqual(secondContext.errors.count, 0)
    }

    func testNotifyObservers() {
        let errorNotifier = ErrorNotifier()
        let firstContext = ErrorObserverContext()
        let secondContext = ErrorObserverContext()
        let thirdContext = ErrorObserverContext()

        (0..<2).forEach { _ in
            [firstContext, secondContext, thirdContext].forEach {
                errorNotifier.addErrorObserver($0.observer())
            }
        }
        // remove reference to owner in secondContext
        secondContext.owner = nil

        let errorMock = ErrorMock()
        errorNotifier.notifyObservers(of: errorMock)
        [firstContext, thirdContext].forEach {
            XCTAssertEqual($0.errors.count, 2)
            XCTAssert($0.errors[0] as? ErrorMock === errorMock)
            XCTAssert($0.errors[1] as? ErrorMock === errorMock)
        }

        // Ownerless observer should not be notified
        XCTAssertEqual(secondContext.errors.count, 0)
        // Should remove the observers that no longer have an owner
        XCTAssertEqual(errorNotifier.errorObservers.count, 4)
        XCTAssert(!errorNotifier.errorObservers.contains { $0.owner !== firstContext.owner && $0.owner !== thirdContext.owner })
    }
}

private class ErrorMock: Error { }
