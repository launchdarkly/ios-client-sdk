//
//  FlagObserverSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 3/6/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
@testable import Darkly

final class FlagChangeObserverSpec: QuickSpec {
    override func spec() {
        equalsSpec()
    }

    private func equalsSpec() {
        var leftObserver: FlagChangeObserver!
        var rightObserver: FlagChangeObserver!
        var ownerMock: FlagChangeHandlerOwnerMock!
        var otherOwnerMock: FlagChangeHandlerOwnerMock!

        describe("equals") {
            //swiftlint:disable unused_closure_parameter
            beforeEach {
                ownerMock = FlagChangeHandlerOwnerMock()
                otherOwnerMock = FlagChangeHandlerOwnerMock()
            }
            context("when observers are the same item") {
                beforeEach {
                    leftObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: ownerMock, changeObserver: { (changedFlag) in })
                }
                it("returns true") {
                    expect(leftObserver) == leftObserver
                }
            }
            context("when observers have the same key and owner") {
                beforeEach {
                    leftObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: ownerMock, changeObserver: { (changedFlag) in })
                    rightObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: ownerMock, changeObserver: { (changedFlag) in })
                }
                it("returns true") {
                    expect(leftObserver) == rightObserver
                }
            }
            context("when observers has a different key and the same owner") {
                beforeEach {
                    leftObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: ownerMock, changeObserver: { (changedFlag) in })
                    rightObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.int, owner: ownerMock, changeObserver: { (changedFlag) in })
                }
                it("returns false") {
                    expect(leftObserver) != rightObserver
                }
            }
            context("when observers have the same key and different owner") {
                beforeEach {
                    leftObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: ownerMock, changeObserver: { (changedFlag) in })
                    rightObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: otherOwnerMock, changeObserver: { (changedFlag) in })
                }
                it("returns false") {
                    expect(leftObserver) != rightObserver
                }
            }
            context("when observers have the same keys and owner") {
                beforeEach {
                    leftObserver = FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.all, owner: ownerMock, collectionChangeObserver: { (changedFlags) in })
                    rightObserver = FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.all, owner: ownerMock, collectionChangeObserver: { (changedFlags) in })
                }
                it("returns true") {
                    expect(leftObserver) == rightObserver
                }
            }
            context("when observers have different keys and the same owner") {
                beforeEach {
                    leftObserver = FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.all, owner: ownerMock, collectionChangeObserver: { (changedFlags) in })
                    rightObserver = FlagChangeObserver(keys: [DarklyServiceMock.FlagKeys.bool], owner: ownerMock, collectionChangeObserver: { (changedFlags) in })
                }
                it("returns false") {
                    expect(leftObserver) != rightObserver
                }
            }
            context("when observers have the same keys and a different owner") {
                beforeEach {
                    leftObserver = FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.all, owner: ownerMock, collectionChangeObserver: { (changedFlags) in })
                    rightObserver = FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.all, owner: otherOwnerMock, collectionChangeObserver: { (changedFlags) in })
                }
                it("returns false") {
                    expect(leftObserver) != rightObserver
                }
            }
            //swiftlint:enable unused_closure_parameter
        }
    }
}

final class FlagChangeHandlerOwnerMock { }
