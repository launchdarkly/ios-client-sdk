//
//  FlagChangeNotifierSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 12/14/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Quick
import Nimble
import Foundation
@testable import LaunchDarkly

final class FlagChangeNotifierSpec: QuickSpec {
    enum ObserverType {
        case singleKey, multipleKey, any
    }

    struct TestContext {
        var subject: FlagChangeNotifier!
        var originalFlagChangeObservers = [FlagChangeObserver]()
        var owners = [String: LDObserverOwner?]()
        var changedFlag: LDChangedFlag?
        var flagChangeHandlerCallCount = 0
        var changedFlags: [LDFlagKey: LDChangedFlag]?
        var flagCollectionChangeHandlerCallCount = 0
        var flagsUnchangedHandlerCallCount = 0
        var flagsUnchangedOwnerKey: String?
        var featureFlags: [LDFlagKey: FeatureFlag] = DarklyServiceMock.Constants.stubFeatureFlags()
        var user: LDUser = LDUser.stub(key: Constants.userKey, includeNullValue: true)
        var flagStoreMock: FlagMaintainingMock! {
            return (user.flagStore as! FlagMaintainingMock)
        }
        let alternateFlagKeys = ["flag-key-1", "flag-key-2", "flag-key-3"]

        //Use this initializer when stubbing observers for observer add & remove tests
        init(observers observerCount: Int = 0, observerType: ObserverType = .any, repeatFirstObserver: Bool = false) {
            subject = FlagChangeNotifier()
            guard observerCount > 0
            else {
                return
            }
            var flagChangeObservers = [FlagChangeObserver]()
            while flagChangeObservers.count < observerCount {
                if observerType == .singleKey || (observerType == .any && flagChangeObservers.count % 2 == 0) {
                    flagChangeObservers.append(FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool,
                                                        owner: stubOwner(key: DarklyServiceMock.FlagKeys.bool),
                                                        flagChangeHandler: flagChangeHandler))
                } else {
                    flagChangeObservers.append(FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.knownFlags,
                                                                  owner: stubOwner(keys: DarklyServiceMock.FlagKeys.knownFlags),
                                                                  flagCollectionChangeHandler: flagCollectionChangeHandler))
                }
            }
            if repeatFirstObserver {
                flagChangeObservers[observerCount - 1] = flagChangeObservers.first!
            }
            flagsUnchangedOwnerKey = flagChangeObservers.first!.flagKeys.observerKey

            var flagsUnchangedObservers = [FlagsUnchangedObserver]()
            //use the flag change observer owners to own the flagsUnchangedObservers
            flagChangeObservers.forEach { (flagChangeObserver) in
                flagsUnchangedObservers.append(FlagsUnchangedObserver(owner: flagChangeObserver.owner!, flagsUnchangedHandler: flagsUnchangedHandler))
            }
            subject = FlagChangeNotifier(flagChangeObservers: flagChangeObservers, flagsUnchangedObservers: flagsUnchangedObservers)
            originalFlagChangeObservers = subject.flagObservers
        }

        //Use this initializer when stubbing observers that should execute a LDFlagChangeHandler during the test
        init(keys: [LDFlagKey], flagChangeHandler: @escaping LDFlagChangeHandler, flagsUnchangedHandler: @escaping LDFlagsUnchangedHandler) {
            flagStoreMock.flagValueSource = .server
            subject = FlagChangeNotifier()
            guard !keys.isEmpty
            else {
                return
            }
            var flagChangeObservers = [FlagChangeObserver]()
            keys.forEach { (key) in
                flagChangeObservers.append(FlagChangeObserver(key: key,
                                                    owner: self.stubOwner(key: key),
                                                    flagChangeHandler: flagChangeHandler))
            }
            flagsUnchangedOwnerKey = flagChangeObservers.first!.flagKeys.observerKey
            var flagsUnchangedObservers = [FlagsUnchangedObserver]()
            //use the flag change observer owners to own the flagsUnchangedObservers
            flagChangeObservers.forEach { (flagChangeObserver) in
                flagsUnchangedObservers.append(FlagsUnchangedObserver(owner: flagChangeObserver.owner!, flagsUnchangedHandler: flagsUnchangedHandler))
            }
            subject = FlagChangeNotifier(flagChangeObservers: flagChangeObservers, flagsUnchangedObservers: flagsUnchangedObservers)
            originalFlagChangeObservers = subject.flagObservers
        }

        //Use this initializer when stubbing observers that should execute a LDFlagCollectionChangeHandler during the test
        //This initializer sets 2 observers, one for the specified flags, and a second for a disjoint set of flags. That way tests verify the notifier is choosing the correct observers
        init(keys: [LDFlagKey], flagCollectionChangeHandler: @escaping LDFlagCollectionChangeHandler, flagsUnchangedHandler: @escaping LDFlagsUnchangedHandler) {
            flagStoreMock.flagValueSource = .server
            subject = FlagChangeNotifier()
            guard !keys.isEmpty
            else {
                return
            }
            var observers = [FlagChangeObserver]()
            observers.append(FlagChangeObserver(keys: keys,
                                                owner: self.stubOwner(keys: keys),
                                                flagCollectionChangeHandler: flagCollectionChangeHandler))
            observers.append(FlagChangeObserver(keys: alternateFlagKeys,
                                                owner: self.stubOwner(keys: alternateFlagKeys),
                                                flagCollectionChangeHandler: flagCollectionChangeHandler))
            flagsUnchangedOwnerKey = observers.first!.flagKeys.observerKey
            let flagsUnchangedObservers = [FlagsUnchangedObserver(owner: observers.first!.owner!, flagsUnchangedHandler: flagsUnchangedHandler)]
            subject = FlagChangeNotifier(flagChangeObservers: observers, flagsUnchangedObservers: flagsUnchangedObservers)
            originalFlagChangeObservers = subject.flagObservers
        }

        mutating func stubOwner(key: String) -> FlagChangeHandlerOwnerMock {
            let owner = FlagChangeHandlerOwnerMock()
            owners[key] = owner

            return owner
        }

        mutating func stubOwner(keys: [String]) -> FlagChangeHandlerOwnerMock {
            return stubOwner(key: keys.observerKey)
        }

        //Flag change handler stubs
        func flagChangeHandler(changedFlag: LDChangedFlag) { }

        func flagCollectionChangeHandler(changedFlags: [LDFlagKey: LDChangedFlag]) { }

        func flagsUnchangedHandler() { }
    }

    struct Constants {
        static let observerCount = 3
        static let userKey = "flagChangeNotifierSpecUserKey"
    }

    override func spec() {
        addObserverSpec()
        removeObserverSpec()
        notifyObserverSpec()
    }

    private func addObserverSpec() {
        var testContext: TestContext!

        describe("add flag change observer") {
            var observer: FlagChangeObserver!
            context("when no observers exist") {
                beforeEach {
                    testContext = TestContext()
                    observer = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool,
                                                  owner: testContext.stubOwner(key: DarklyServiceMock.FlagKeys.bool),
                                                  flagChangeHandler: testContext.flagChangeHandler)
                    testContext.subject.addFlagChangeObserver(observer)
                }
                it("adds the observer") {
                    expect(testContext.subject.flagObservers.count) == 1
                    expect(testContext.subject.flagObservers.first) == observer
                }
            }
            context("when observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount)
                    observer = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.bool,
                                                  owner: testContext.stubOwner(key: DarklyServiceMock.FlagKeys.bool),
                                                  flagChangeHandler: testContext.flagChangeHandler)
                    testContext.subject.addFlagChangeObserver(observer)
                }
                it("adds the observer") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount + 1
                    expect(testContext.subject.flagObservers.last) == observer
                }
            }
        }
        describe("add flags unchanged observer") {
            var observer: FlagsUnchangedObserver!
            context("when no observers exist") {
                beforeEach {
                    testContext = TestContext()
                    observer = FlagsUnchangedObserver(owner: testContext.stubOwner(key: DarklyServiceMock.FlagKeys.bool),
                                                      flagsUnchangedHandler: testContext.flagsUnchangedHandler)
                    testContext.subject.addFlagsUnchangedObserver(observer)
                }
                it("adds the observer") {
                    expect(testContext.subject.noChangeObservers.count) == 1
                    expect(testContext.subject.noChangeObservers.first?.owner) === observer.owner
                }
            }
            context("when observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount)
                    observer = FlagsUnchangedObserver(owner: testContext.stubOwner(key: DarklyServiceMock.FlagKeys.bool),
                                                      flagsUnchangedHandler: testContext.flagsUnchangedHandler)
                    testContext.subject.addFlagsUnchangedObserver(observer)
                }
                it("adds the observer") {
                    expect(testContext.subject.noChangeObservers.count) == Constants.observerCount + 1
                    expect(testContext.subject.noChangeObservers.last?.owner) === observer.owner
                }
            }
        }
    }

    private func removeObserverSpec() {
        describe("remove observer") {
            removeObserverForKeySpec()
            removeObserverForKeysSpec()
            removeObserverForOwnerSpec()
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
                        owner = (testContext.subject.flagObservers.first!.owner as! FlagChangeHandlerOwnerMock)
                        targetObserver = FlagChangeObserver(key: DarklyServiceMock.FlagKeys.int, owner: owner, flagChangeHandler: testContext.flagChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys.first!, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalFlagChangeObservers
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
                        expect(testContext.subject.flagObservers) == testContext.originalFlagChangeObservers
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
                        expect(testContext.subject.flagObservers) == testContext.originalFlagChangeObservers
                    }
                }
            }
            context("when 2 target observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount, observerType: .singleKey, repeatFirstObserver: true)
                    targetObserver = testContext.subject.flagObservers.first!

                    testContext.subject.removeObserver(targetObserver.flagKeys.first!, owner: targetObserver.owner!)
                }
                it("removes both observers") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount - 2
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
                        owner = (testContext.subject.flagObservers.first!.owner as! FlagChangeHandlerOwnerMock)
                        var keys = DarklyServiceMock.FlagKeys.knownFlags
                        keys.remove(at: 0)
                        targetObserver = FlagChangeObserver(keys: keys, owner: owner, flagCollectionChangeHandler: testContext.flagCollectionChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalFlagChangeObservers
                    }
                }
                context("because the target has a different owner") {
                    beforeEach {
                        testContext = TestContext(observers: Constants.observerCount, observerType: .multipleKey)
                        owner = FlagChangeHandlerOwnerMock()
                        targetObserver = FlagChangeObserver(keys: DarklyServiceMock.FlagKeys.knownFlags,
                                                            owner: owner,
                                                            flagCollectionChangeHandler: testContext.flagCollectionChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalFlagChangeObservers
                    }
                }
                context("because the target has different keys and owner") {
                    beforeEach {
                        testContext = TestContext(observers: Constants.observerCount, observerType: .multipleKey)
                        owner = FlagChangeHandlerOwnerMock()
                        var keys = DarklyServiceMock.FlagKeys.knownFlags
                        keys.remove(at: 0)
                        targetObserver = FlagChangeObserver(keys: keys, owner: owner, flagCollectionChangeHandler: testContext.flagCollectionChangeHandler)

                        testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                    }
                    it("leaves the observers unchanged") {
                        expect(testContext.subject.flagObservers.count) == Constants.observerCount
                        expect(testContext.subject.flagObservers) == testContext.originalFlagChangeObservers
                    }
                }
            }
            context("when 2 target observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount, observerType: .multipleKey, repeatFirstObserver: true)
                    targetObserver = testContext.subject.flagObservers.first!

                    testContext.subject.removeObserver(targetObserver.flagKeys, owner: targetObserver.owner!)
                }
                it("removes both observers") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount - 2
                    expect(testContext.subject.flagObservers.contains(targetObserver)).to(beFalse())
                }
            }
        }
    }

    private func removeObserverForOwnerSpec() {
        var testContext: TestContext!
        var targetObserver: FlagChangeObserver!
        var targetOwner: FlagChangeHandlerOwnerMock!

        context("with owner") {
            context("when several observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount)
                    targetObserver = testContext.subject.flagObservers[Constants.observerCount - 2]  //Take the middle one

                    testContext.subject.removeObserver(owner: targetObserver.owner!)
                }
                it("removes the observer") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount - 1
                    expect(testContext.subject.flagObservers.contains(targetObserver)).to(beFalse())
                    expect(testContext.subject.noChangeObservers.count) == Constants.observerCount - 1
                }
            }
            context("when 1 observer exists") {
                beforeEach {
                    testContext = TestContext(observers: 1)
                    targetObserver = testContext.subject.flagObservers.first!

                    testContext.subject.removeObserver(owner: targetObserver.owner!)
                }
                it("removes the observer") {
                    expect(testContext.subject.flagObservers.isEmpty).to(beTrue())
                    expect(testContext.subject.noChangeObservers.isEmpty).to(beTrue())
                }
            }
            context("when the target observer doesnt exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount)
                    targetOwner = FlagChangeHandlerOwnerMock()

                    testContext.subject.removeObserver(owner: targetOwner!)
                }
                it("leaves the observers unchanged") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount
                    expect(testContext.subject.flagObservers) == testContext.originalFlagChangeObservers
                    expect(testContext.subject.noChangeObservers.count) == Constants.observerCount
                }
            }
            context("when 2 target observers exist") {
                beforeEach {
                    testContext = TestContext(observers: Constants.observerCount, repeatFirstObserver: true)
                    targetObserver = testContext.subject.flagObservers.first!

                    testContext.subject.removeObserver(owner: targetObserver.owner!)
                }
                it("removes both observers") {
                    expect(testContext.subject.flagObservers.count) == Constants.observerCount - 2
                    expect(testContext.subject.flagObservers.contains(targetObserver)).to(beFalse())
                    expect(testContext.subject.noChangeObservers.count) == Constants.observerCount - 2
                }
            }
        }
    }

    private func notifyObserverSpec() {
        describe("notify observers") {
            notifyObserversWithSingleFlagObserverSpec()
            notifyObserversWithMultipleFlagsObserverSpec()
            notifyObserversWithAllFlagsObserverSpec()
        }
    }

    private func notifyObserversWithSingleFlagObserverSpec() {
        var testContext: TestContext!
        var targetChangedFlag: LDChangedFlag?
        var oldFlags: [LDFlagKey: FeatureFlag]!

        context("with single flag observers") {
            context("that are active") {
                context("and different flags") {
                    it("activates the change handler") {
                        DarklyServiceMock.FlagKeys.flagsWithAnAlternateValue.forEach { (key) in
                            testContext = TestContext(
                                keys: DarklyServiceMock.FlagKeys.knownFlags,
                                flagChangeHandler: { (changedFlag) in
                                    testContext.flagChangeHandlerCallCount += 1
                                    testContext.changedFlag = changedFlag
                            },
                                flagsUnchangedHandler: {
                                    testContext.flagsUnchangedHandlerCallCount += 1
                            })
                            oldFlags = DarklyServiceMock.Constants.stubFeatureFlags(alternateValuesForKeys: [key])
                            targetChangedFlag = LDChangedFlag.stub(key: key, oldFlags: oldFlags, newFlags: testContext.user.flagStore.featureFlags)

                            waitUntil { done in
                                testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                            }

                            expect(testContext.flagChangeHandlerCallCount) == 1
                            expect(testContext.changedFlag) == targetChangedFlag
                            expect(testContext.flagsUnchangedHandlerCallCount) == 0
                        }
                    }
                }
                context("and unchanged flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: DarklyServiceMock.FlagKeys.knownFlags,
                            flagChangeHandler: { (_) in
                                testContext.flagChangeHandlerCallCount += 1
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        oldFlags = testContext.user.flagStore.featureFlags

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("activates the flags unchanged handler") {
                        expect(testContext.flagChangeHandlerCallCount) == 0
                        expect(testContext.flagsUnchangedHandlerCallCount) == DarklyServiceMock.FlagKeys.knownFlags.count
                    }
                }
            }
            context("that are inactive") {
                context("and different flags") {
                    it("does nothing") {
                        DarklyServiceMock.FlagKeys.flagsWithAnAlternateValue.forEach { (key) in
                            testContext = TestContext(
                                keys: DarklyServiceMock.FlagKeys.knownFlags,
                                flagChangeHandler: { (changedFlag) in
                                    testContext.flagChangeHandlerCallCount += 1
                                    testContext.changedFlag = changedFlag
                            },
                                flagsUnchangedHandler: {
                                    testContext.flagsUnchangedHandlerCallCount += 1
                            })
                            oldFlags = DarklyServiceMock.Constants.stubFeatureFlags(alternateValuesForKeys: [key])
                            testContext.owners[key] = nil

                            waitUntil { done in
                                testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                            }

                            expect(testContext.flagChangeHandlerCallCount) == 0
                            expect(testContext.flagsUnchangedHandlerCallCount) == 0
                        }
                    }
                }
                context("and unchanged flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: DarklyServiceMock.FlagKeys.knownFlags,
                            flagChangeHandler: { (_) in
                                testContext.flagChangeHandlerCallCount += 1
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        oldFlags = testContext.user.flagStore.featureFlags
                        testContext.owners[testContext.flagsUnchangedOwnerKey!] = nil

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("does nothing") {
                        expect(testContext.flagChangeHandlerCallCount) == 0
                        expect(testContext.flagsUnchangedHandlerCallCount) == DarklyServiceMock.FlagKeys.knownFlags.count - 1
                    }
                }
            }
        }
    }

    private func notifyObserversWithMultipleFlagsObserverSpec() {
        var testContext: TestContext!
        var targetChangedFlags: [LDFlagKey: LDChangedFlag]?
        var oldFlags: [LDFlagKey: FeatureFlag]!

        context("with multiple flag observers") {
            context("that are active") {
                context("and different single flags") {
                    it("activates the change handler") {
                        DarklyServiceMock.FlagKeys.flagsWithAnAlternateValue.forEach { (key) in
                            testContext = TestContext(
                                keys: DarklyServiceMock.FlagKeys.knownFlags,
                                flagCollectionChangeHandler: { (changedFlags) in
                                    testContext.flagCollectionChangeHandlerCallCount += 1
                                    testContext.changedFlags = changedFlags
                            },
                                flagsUnchangedHandler: {
                                    testContext.flagsUnchangedHandlerCallCount += 1
                            })
                            oldFlags = DarklyServiceMock.Constants.stubFeatureFlags(alternateValuesForKeys: [key])
                            targetChangedFlags = [key: LDChangedFlag.stub(key: key, oldFlags: oldFlags, newFlags: testContext.user.flagStore.featureFlags)]

                            waitUntil { done in
                                testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                            }

                            expect(testContext.flagCollectionChangeHandlerCallCount) == 1
                            expect(testContext.changedFlags) == targetChangedFlags
                            expect(testContext.flagsUnchangedHandlerCallCount) == 0
                        }
                    }
                }
                context("and different multiple flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: DarklyServiceMock.FlagKeys.knownFlags,
                            flagCollectionChangeHandler: { (changedFlags) in
                                testContext.flagCollectionChangeHandlerCallCount += 1
                                testContext.changedFlags = changedFlags
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        let changedFlagKeys = [DarklyServiceMock.FlagKeys.bool, DarklyServiceMock.FlagKeys.int, DarklyServiceMock.FlagKeys.double]
                        oldFlags = DarklyServiceMock.Constants.stubFeatureFlags(alternateValuesForKeys: changedFlagKeys)
                        targetChangedFlags = [LDFlagKey: LDChangedFlag](uniqueKeysWithValues: changedFlagKeys.map { (flagKey) in
                            return (flagKey, LDChangedFlag.stub(key: flagKey, oldFlags: oldFlags, newFlags: testContext.user.flagStore.featureFlags))
                        })

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("activates the change handler") {
                        expect(testContext.flagCollectionChangeHandlerCallCount) == 1
                        expect(testContext.changedFlags) == targetChangedFlags
                        expect(testContext.flagsUnchangedHandlerCallCount) == 0
                    }
                }
                context("and unchanged flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: DarklyServiceMock.FlagKeys.knownFlags,
                            flagCollectionChangeHandler: { (changedFlags) in
                                testContext.flagCollectionChangeHandlerCallCount += 1
                                testContext.changedFlags = changedFlags
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        oldFlags = testContext.user.flagStore.featureFlags

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("activates the flags unchanged handler") {
                        expect(testContext.flagCollectionChangeHandlerCallCount) == 0
                        expect(testContext.flagsUnchangedHandlerCallCount) == 1
                    }
                }
            }
            context("that are inactive") {
                context("and different flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: DarklyServiceMock.FlagKeys.knownFlags,
                            flagCollectionChangeHandler: { (changedFlags) in
                                testContext.flagCollectionChangeHandlerCallCount += 1
                                testContext.changedFlags = changedFlags
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        let changedFlagKeys = [DarklyServiceMock.FlagKeys.bool, DarklyServiceMock.FlagKeys.int, DarklyServiceMock.FlagKeys.double]
                        oldFlags = DarklyServiceMock.Constants.stubFeatureFlags(alternateValuesForKeys: changedFlagKeys)
                        testContext.owners[DarklyServiceMock.FlagKeys.knownFlags.observerKey] = nil

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("does nothing") {
                        expect(testContext.flagCollectionChangeHandlerCallCount) == 0
                        expect(testContext.flagsUnchangedHandlerCallCount) == 0
                    }
                }
                context("and unchanged flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: DarklyServiceMock.FlagKeys.knownFlags,
                            flagCollectionChangeHandler: { (changedFlags) in
                                testContext.flagCollectionChangeHandlerCallCount += 1
                                testContext.changedFlags = changedFlags
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        oldFlags = testContext.user.flagStore.featureFlags
                        testContext.owners[testContext.flagsUnchangedOwnerKey!] = nil

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("does nothing") {
                        expect(testContext.flagCollectionChangeHandlerCallCount) == 0
                        expect(testContext.flagsUnchangedHandlerCallCount) == 0
                    }
                }
            }
        }
    }

    private func notifyObserversWithAllFlagsObserverSpec() {
        var testContext: TestContext!
        var targetChangedFlags: [LDFlagKey: LDChangedFlag]?
        var oldFlags: [LDFlagKey: FeatureFlag]!

        context("with all flags observers") {
            context("that are active") {
                context("and different single flags") {
                    it("activates the change handler") {
                        DarklyServiceMock.FlagKeys.flagsWithAnAlternateValue.forEach { (key) in
                            testContext = TestContext(
                                keys: LDFlagKey.anyKey,
                                flagCollectionChangeHandler: { (changedFlags) in
                                    testContext.flagCollectionChangeHandlerCallCount += 1
                                    testContext.changedFlags = changedFlags
                            },
                                flagsUnchangedHandler: {
                                    testContext.flagsUnchangedHandlerCallCount += 1
                            })
                            oldFlags = DarklyServiceMock.Constants.stubFeatureFlags(alternateValuesForKeys: [key])
                            targetChangedFlags = [key: LDChangedFlag.stub(key: key, oldFlags: oldFlags, newFlags: testContext.user.flagStore.featureFlags)]
                            targetChangedFlags![LDUser.StubConstants.userKey] = LDChangedFlag.stub(key: LDUser.StubConstants.userKey,
                                                                                                   oldFlags: oldFlags,
                                                                                                   newFlags: testContext.user.flagStore.featureFlags)

                            waitUntil { done in
                                testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                            }

                            expect(testContext.flagCollectionChangeHandlerCallCount) == 1
                            expect(testContext.changedFlags) == targetChangedFlags
                            expect(testContext.flagsUnchangedHandlerCallCount) == 0
                        }
                    }
                }
                context("and different multiple flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: LDFlagKey.anyKey,
                            flagCollectionChangeHandler: { (changedFlags) in
                                testContext.flagCollectionChangeHandlerCallCount += 1
                                testContext.changedFlags = changedFlags
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        let changedFlagKeys = [DarklyServiceMock.FlagKeys.bool, DarklyServiceMock.FlagKeys.int, DarklyServiceMock.FlagKeys.double]
                        oldFlags = DarklyServiceMock.Constants.stubFeatureFlags(alternateValuesForKeys: changedFlagKeys)
                        targetChangedFlags = [LDFlagKey: LDChangedFlag](uniqueKeysWithValues: changedFlagKeys.map { (flagKey) in
                            return (flagKey, LDChangedFlag.stub(key: flagKey, oldFlags: oldFlags, newFlags: testContext.user.flagStore.featureFlags))
                        })
                        targetChangedFlags![LDUser.StubConstants.userKey] = LDChangedFlag.stub(key: LDUser.StubConstants.userKey,
                                                                                               oldFlags: oldFlags,
                                                                                               newFlags: testContext.user.flagStore.featureFlags)

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("activates the change handler") {
                        expect(testContext.flagCollectionChangeHandlerCallCount) == 1
                        expect(testContext.changedFlags) == targetChangedFlags
                        expect(testContext.flagsUnchangedHandlerCallCount) == 0
                    }
                }
                context("and unchanged flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: LDFlagKey.anyKey,
                            flagCollectionChangeHandler: { (changedFlags) in
                                testContext.flagCollectionChangeHandlerCallCount += 1
                                testContext.changedFlags = changedFlags
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        oldFlags = testContext.user.flagStore.featureFlags

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("activates the flags unchanged handler") {
                        expect(testContext.flagCollectionChangeHandlerCallCount) == 0
                        expect(testContext.flagsUnchangedHandlerCallCount) == 1
                    }
                }
            }
            context("that are inactive") {
                context("and different flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: LDFlagKey.anyKey,
                            flagCollectionChangeHandler: { (changedFlags) in
                                testContext.flagCollectionChangeHandlerCallCount += 1
                                testContext.changedFlags = changedFlags
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        let changedFlagKeys = [DarklyServiceMock.FlagKeys.bool, DarklyServiceMock.FlagKeys.int, DarklyServiceMock.FlagKeys.double]
                        oldFlags = DarklyServiceMock.Constants.stubFeatureFlags(alternateValuesForKeys: changedFlagKeys)
                        testContext.owners[LDFlagKey.anyKey.observerKey] = nil

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("does nothing") {
                        expect(testContext.flagCollectionChangeHandlerCallCount) == 0
                        expect(testContext.flagsUnchangedHandlerCallCount) == 0
                    }
                }
                context("and unchanged flags") {
                    beforeEach {
                        testContext = TestContext(
                            keys: LDFlagKey.anyKey,
                            flagCollectionChangeHandler: { (changedFlags) in
                                testContext.flagCollectionChangeHandlerCallCount += 1
                                testContext.changedFlags = changedFlags
                        },
                            flagsUnchangedHandler: {
                                testContext.flagsUnchangedHandlerCallCount += 1
                        })
                        oldFlags = testContext.user.flagStore.featureFlags
                        testContext.owners[testContext.flagsUnchangedOwnerKey!] = nil

                        waitUntil { done in
                            testContext.subject.notifyObservers(user: testContext.user, oldFlags: oldFlags, oldFlagSource: .server, completion: done)
                        }
                    }
                    it("does nothing") {
                        expect(testContext.flagCollectionChangeHandlerCallCount) == 0
                        expect(testContext.flagsUnchangedHandlerCallCount) == 0
                    }
                }
            }
        }
    }
}

fileprivate extension DarklyServiceMock.FlagKeys {
    static let extra = "extra-key"
}

fileprivate extension DarklyServiceMock.FlagValues {
    static let extra = "extra-key-value"
}

fileprivate extension LDChangedFlag {
    static func stub(key: LDFlagKey, oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag]) -> LDChangedFlag {
        return LDChangedFlag(key: key, oldValue: oldFlags[key]?.value, oldValueSource: .server, newValue: newFlags[key]?.value, newValueSource: .server)
    }
}

extension LDChangedFlag: Equatable {
    public static func == (lhs: LDChangedFlag, rhs: LDChangedFlag) -> Bool {
        return lhs.key == rhs.key
            && AnyComparer.isEqual(lhs.oldValue, to: rhs.oldValue)
            && lhs.oldValueSource == rhs.oldValueSource
            && AnyComparer.isEqual(lhs.newValue, to: rhs.newValue)
            && lhs.newValueSource == rhs.newValueSource
    }
}

fileprivate extension Array where Element == LDFlagKey {
    var observerKey: String { return joined(separator: ".") }
}
