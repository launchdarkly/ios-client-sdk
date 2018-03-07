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
    enum ObserverType {
        case singleKey, multipleKey, any
    }

    struct TestContext {
        var subject: FlagChangeNotifier!
        var originalObservers = [FlagChangeObserver]()
        var strongOwners = [LDFlagChangeOwner?]()
        var weakOwners = [LDFlagChangeOwner?]()
        var changedFlag: LDChangedFlag?
        var customFlagChangeHandler: LDFlagChangeHandler?
        var changedFlags: [LDFlagKey: LDChangedFlag]?
        var customFlagCollectionChangeHandler: LDFlagCollectionChangeHandler?

        init(observers observerCount: Int = 0, observerType: ObserverType = .any, repeatFirstObserver: Bool = false) {
            subject = FlagChangeNotifier()
            guard observerCount > 0 else { return }
            var observers = [FlagChangeObserver]()
            while observers.count < observerCount {
                if observerType == .singleKey || (observerType == .any && observers.count % 2 == 0) {
                    observers.append(FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: stubOwner(), flagChangeHandler: flagChangeHandler))
                } else {
                    observers.append(FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.all, owner: stubOwner(), flagCollectionChangeHandler: flagCollectionChangeHandler))
                }
            }
            if repeatFirstObserver { observers[observerCount - 1] = observers.first! }
            subject = FlagChangeNotifier(observers: observers)
            originalObservers = subject.flagObservers
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
        removeObserverSpec()
    }

    private func addObserverSpec() {
        var testContext: TestContext!

        describe("add observer") {
            var observer: FlagChangeObserver!
            context("when no observers exist") {
                beforeEach {
                    testContext = TestContext()
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

    private func removeObserverSpec() {
        describe("remove observer") {
            removeObserverForKeySpec()
            removeObserverForKeysSpec()
        }
    }

    private func removeObserverForKeySpec() {
        var testContext: TestContext!
        var targetObserver: FlagChangeObserver!

        context("with a single flag key") {
            context("when several observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount, observerType: .singleKey)
                    targetObserver = testContext.subject.flagObservers[Constants.observerCount - 2] //Take the middle one

                    testContext.subject.removeObserver(targetObserver.flagKeys.first!, owner: targetObserver.owner!)
                }
                it("removes the observer") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount - 1
                    expect(testContext.subject.flagObservers.contains(targetObserver)).to(beFalse())
                }
            }
            context("when 1 observer exists") {
                beforeEach {
                    testContext = TestContext(observers: 1, observerType: .singleKey)
                    targetObserver = testContext.subject.flagObservers.first!

                    testContext.subject.removeObserver(targetObserver.flagKeys.first!, owner: targetObserver.owner!)
                }
                it("removes the observer") {
                    expect(testContext.subject.flagObservers.isEmpty).to(beTrue())
                }
            }
            context("when the target observer doesnt exist") {
                var owner: FlagChangeHandlerOwnerMock!
                context("because the target has a different key") {
                    beforeEach {
                        testContext = TestContext(observers: Constants.observerCount, observerType: .singleKey)
                        owner = testContext.subject.flagObservers.first!.owner as! FlagChangeHandlerOwnerMock
                        targetObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.int, owner: owner, flagChangeHandler: testContext.flagChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys.first!, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalObservers
                    }
                }
                context("because the target has a different owner") {
                    beforeEach {
                        testContext = TestContext(observers: Constants.observerCount, observerType: .singleKey)
                        owner = FlagChangeHandlerOwnerMock()
                        targetObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool, owner: owner, flagChangeHandler: testContext.flagChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys.first!, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalObservers
                    }
                }
                context("because the target has a different key and owner") {
                    beforeEach {
                        testContext = TestContext(observers: Constants.observerCount, observerType: .singleKey)
                        owner = FlagChangeHandlerOwnerMock()
                        targetObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.int, owner: owner, flagChangeHandler: testContext.flagChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys.first!, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalObservers
                    }
                }
            }
            context("when multiple target observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount + 1, observerType: .singleKey, repeatFirstObserver: true)
                    targetObserver = testContext.subject.flagObservers.first!

                    testContext.subject.removeObserver(targetObserver.flagKeys.first!, owner: targetObserver.owner!)
                }
                it("removes the observers") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount - 1
                    expect(testContext.subject.flagObservers.contains(targetObserver)).to(beFalse())
                }
            }
        }
    }

    private func removeObserverForKeysSpec() {
        var testContext: TestContext!
        var targetObserver: FlagChangeObserver!

        context("with multiple flag keys") {
            context("when several observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount, observerType: .multipleKey)
                    targetObserver = testContext.subject.flagObservers[Constants.observerCount - 2] //Take the middle one

                    testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                }
                it("removes the observer") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount - 1
                    expect(testContext.subject.flagObservers.contains(targetObserver)).to(beFalse())
                }
            }
            context("when 1 observer exists") {
                beforeEach {
                    testContext = TestContext(observers: 1, observerType: .multipleKey)
                    targetObserver = testContext.subject.flagObservers.first!

                    testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                }
                it("removes the observer") {
                    expect(testContext.subject.flagObservers.isEmpty).to(beTrue())
                }
            }
            context("when the target observer doesnt exist") {
                var owner: FlagChangeHandlerOwnerMock!
                context("because the target has different keys") {
                    beforeEach {
                        testContext = TestContext(observers: Constants.observerCount, observerType: .multipleKey)
                        owner = testContext.subject.flagObservers.first!.owner as! FlagChangeHandlerOwnerMock
                        var keys = DarklyServiceMock.FlagKeys.all
                        keys.remove(at: 0)
                        targetObserver = FlagChangeObserver(keys: keys, owner: owner, flagCollectionChangeHandler: testContext.flagCollectionChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalObservers
                    }
                }
                context("because the target has a different owner") {
                    beforeEach {
                        testContext = TestContext(observers: Constants.observerCount, observerType: .multipleKey)
                        owner = FlagChangeHandlerOwnerMock()
                        targetObserver = FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.all, owner: owner, flagCollectionChangeHandler: testContext.flagCollectionChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalObservers
                    }
                }
                context("because the target has different keys and owner") {
                    beforeEach {
                        testContext = TestContext(observers: Constants.observerCount, observerType: .multipleKey)
                        owner = FlagChangeHandlerOwnerMock()
                        var keys = DarklyServiceMock.FlagKeys.all
                        keys.remove(at: 0)
                        targetObserver = FlagChangeObserver(keys: keys, owner: owner, flagCollectionChangeHandler: testContext.flagCollectionChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalObservers
                    }
                }
            }
            context("when multiple target observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount + 1, observerType: .multipleKey, repeatFirstObserver: true)
                    targetObserver = testContext.subject.flagObservers.first!

                    testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                }
                it("removes the observer") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount - 1
                    expect(testContext.subject.flagObservers.contains(targetObserver)).to(beFalse())
                }
            }
        }
    }
}
