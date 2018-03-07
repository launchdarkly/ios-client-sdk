//
//  FlagChangeNotifierSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 12/14/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import Darkly

final class FlagChangeNotifierSpec: QuickSpec {
    struct TestContext {
        var subject: FlagChangeNotifier!
        var strongOwners = [LDFlagChangeOwner?]()
        var weakOwners = [LDFlagChangeOwner?]()
        var changedFlag: LDChangedFlag?
        var customFlagChangeHandler: LDFlagChangeHandler?
        var changedFlags: [LDFlagKey: LDChangedFlag]?
        var customFlagCollectionChangeHandler: LDFlagCollectionChangeHandler?

        init(observers observerCount: Int = 0) {
            subject = FlagChangeNotifier()
            guard observerCount > 0 else { return }
            var observers = [FlagChangeObserver]()
            while observers.count < observerCount {
                if observers.count % 2 == 0 {
                    observers.append(FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: stubOwner(), flagChangeHandler: flagChangeHandler))
                } else {
                    observers.append(FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.all, owner: stubOwner(), flagCollectionChangeHandler: flagCollectionChangeHandler))
                }
            }
            subject = FlagChangeNotifier(observers: observers)
        }

        mutating func stubOwner() -> FlagChangeHandlerOwnerMock {
            let owner = FlagChangeHandlerOwnerMock()
            weak var weakOwner = owner
            strongOwners.append(owner)
            weakOwners.append(weakOwner)

            return owner
        }

        func flagChangeHandler(changedFlag: LDChangedFlag) {
            customFlagChangeHandler?(changedFlag)
        }

        func flagCollectionChangeHandler(changedFlags: [LDFlagKey: LDChangedFlag]) {
            customFlagCollectionChangeHandler?(changedFlags)
        }
    }

    struct Constants {
        static let observerCount = 3
    }

    override func spec() {
        addObserverSpec()
    }

    private func addObserverSpec() {
        var testContext: TestContext!

        beforeEach {
            testContext = TestContext()
        }

        describe("add observer") {
            var observer: FlagChangeObserver!
            context("when no observers exist") {
                beforeEach {
                    observer = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: testContext.stubOwner(), flagChangeHandler: testContext.flagChangeHandler)
                    testContext.subject.add(observer)
                }
                it("adds the observer") {
                    expect(testContext.subject.flagObservers.first) == observer
                }
            }
            context("when observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount)
                    observer = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: testContext.stubOwner(), flagChangeHandler: testContext.flagChangeHandler)
                    testContext.subject.add(observer)
                }
                it("adds the observer") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount + 1
                    expect(testContext.subject.flagObservers.last) == observer
                }
            }
        }
    }
}
