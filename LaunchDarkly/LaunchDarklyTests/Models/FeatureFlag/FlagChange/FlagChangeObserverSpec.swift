import Foundation
import XCTest

@testable import LaunchDarkly

private final class ObserverOwnerMock {
    var changedFlagCount = 0
    var changedCollectionCount = 0

    func handleFlagChange(changedFlag: LDChangedFlag) {
        changedFlagCount += 1
    }

    func handleCollectionChange(changedFlags: [LDFlagKey: LDChangedFlag]) {
        changedCollectionCount += 1
    }
}

final class FlagChangeObserverSpec: XCTestCase {
    let testChangedFlag = LDChangedFlag(key: "key1", oldValue: nil, newValue: nil)

    func testInit() {
        let ownerMock = ObserverOwnerMock()
        let flagChangeObserver = FlagChangeObserver(key: "key1", owner: ownerMock, flagChangeHandler: ownerMock.handleFlagChange)
        XCTAssert(flagChangeObserver.owner === ownerMock)
        XCTAssertEqual(flagChangeObserver.flagKeys, ["key1"])
        XCTAssertNil(flagChangeObserver.flagCollectionChangeHandler)
        flagChangeObserver.flagChangeHandler?(testChangedFlag)
        XCTAssertEqual(ownerMock.changedFlagCount, 1)
    }

    func testInitCollection() {
        let ownerMock = ObserverOwnerMock()
        let flagChangeObserver = FlagChangeObserver(keys: ["key1"], owner: ownerMock, flagCollectionChangeHandler: ownerMock.handleCollectionChange)
        XCTAssert(flagChangeObserver.owner === ownerMock)
        XCTAssertEqual(flagChangeObserver.flagKeys, ["key1"])
        XCTAssertNil(flagChangeObserver.flagChangeHandler)
        flagChangeObserver.flagCollectionChangeHandler?(["key1": testChangedFlag])
        XCTAssertEqual(ownerMock.changedCollectionCount, 1)
    }
}
