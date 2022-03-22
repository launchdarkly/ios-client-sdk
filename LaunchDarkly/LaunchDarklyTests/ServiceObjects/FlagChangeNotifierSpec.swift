import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

private class CallTracker<T> {
    var callCount = 0
    var lastCallArg: T?
}

private class MockFlagChangeObserver {
    let key: LDFlagKey
    let observer: FlagChangeObserver
    var owner: LDObserverOwner?

    private var tracker: CallTracker<LDChangedFlag>?
    var callCount: Int { tracker!.callCount }
    var lastCallArg: LDChangedFlag? { tracker!.lastCallArg }

    init(_ key: LDFlagKey, owner: LDObserverOwner = FlagChangeHandlerOwnerMock()) {
        self.key = key
        self.owner = owner
        let tracker = CallTracker<LDChangedFlag>()
        self.observer = FlagChangeObserver(key: key, owner: owner) {
            tracker.callCount += 1
            tracker.lastCallArg = $0
        }
        self.tracker = tracker
    }
}

private class MockFlagCollectionChangeObserver {
    let keys: [LDFlagKey]
    let observer: FlagChangeObserver
    var owner: LDObserverOwner?

    private var tracker: CallTracker<[LDFlagKey: LDChangedFlag]>
    var callCount: Int { tracker.callCount }
    var lastCallArg: [LDFlagKey: LDChangedFlag]? { tracker.lastCallArg }

    init(_ keys: [LDFlagKey], owner: LDObserverOwner = FlagChangeHandlerOwnerMock()) {
        self.keys = keys
        self.owner = owner
        let tracker = CallTracker<[LDFlagKey: LDChangedFlag]>()
        self.observer = FlagChangeObserver(keys: keys, owner: owner) {
            tracker.callCount += 1
            tracker.lastCallArg = $0
        }
        self.tracker = tracker
    }
}

private class MockFlagsUnchangedObserver {
    let observer: FlagsUnchangedObserver
    var owner: LDObserverOwner?

    private var tracker: CallTracker<Void>
    var callCount: Int { tracker.callCount }

    init(owner: LDObserverOwner = FlagChangeHandlerOwnerMock()) {
        self.owner = owner
        let tracker = CallTracker<Void>()
        self.observer = FlagsUnchangedObserver(owner: owner) {
            tracker.callCount += 1
        }
        self.tracker = tracker
    }
}

private class MockConnectionModeChangedObserver {
    let observer: ConnectionModeChangedObserver
    var owner: LDObserverOwner?

    private var tracker: CallTracker<ConnectionInformation.ConnectionMode>
    var callCount: Int { tracker.callCount }
    var lastCallArg: ConnectionInformation.ConnectionMode? { tracker.lastCallArg }

    init(owner: LDObserverOwner = FlagChangeHandlerOwnerMock()) {
        self.owner = owner
        let tracker = CallTracker<ConnectionInformation.ConnectionMode>()
        self.observer = ConnectionModeChangedObserver(owner: owner) {
            tracker.callCount += 1
            tracker.lastCallArg = $0
        }
        self.tracker = tracker
    }
}

final class FlagChangeNotifierSpec: QuickSpec {
    struct TestContext {
        let subject: FlagChangeNotifier = FlagChangeNotifier()
        fileprivate var flagChangeObservers: [LDFlagKey: MockFlagChangeObserver] = [:]
        fileprivate var flagCollectionChangeObservers: [MockFlagCollectionChangeObserver] = []
        fileprivate var flagsUnchangedObservers: [MockFlagsUnchangedObserver] = []
        fileprivate var connectionModeObservers: [MockConnectionModeChangedObserver] = []

        fileprivate mutating func addChangeObserver(forKey key: LDFlagKey, owner: LDObserverOwner = FlagChangeHandlerOwnerMock()) {
            let changeObserver = MockFlagChangeObserver(key, owner: owner)
            flagChangeObservers[key] = changeObserver
            subject.addFlagChangeObserver(changeObserver.observer)
        }

        fileprivate mutating func addChangeObservers(forKeys keys: [LDFlagKey], owner: LDObserverOwner? = nil) {
            keys.forEach { self.addChangeObserver(forKey: $0, owner: owner ?? FlagChangeHandlerOwnerMock()) }
        }

        fileprivate mutating func addCollectionChangeObserver(forKeys keys: [LDFlagKey], owner: LDObserverOwner = FlagChangeHandlerOwnerMock()) {
            let changeObserver = MockFlagCollectionChangeObserver(keys, owner: owner)
            flagCollectionChangeObservers.append(changeObserver)
            subject.addFlagChangeObserver(changeObserver.observer)
        }

        fileprivate mutating func addUnchangedObserver(owner: LDObserverOwner = FlagChangeHandlerOwnerMock()) {
            let unchangedObserver = MockFlagsUnchangedObserver(owner: owner)
            flagsUnchangedObservers.append(unchangedObserver)
            subject.addFlagsUnchangedObserver(unchangedObserver.observer)
        }

        fileprivate mutating func addConnectionModeObserver(owner: LDObserverOwner = FlagChangeHandlerOwnerMock()) {
            let connectionModeObserver = MockConnectionModeChangedObserver(owner: owner)
            connectionModeObservers.append(connectionModeObserver)
            subject.addConnectionModeChangedObserver(connectionModeObserver.observer)
        }

        func awaitNotify(oldFlags: [LDFlagKey: FeatureFlag], newFlags: [LDFlagKey: FeatureFlag]) {
            subject.notifyObservers(oldFlags: oldFlags, newFlags: newFlags)
            awaitNotifications()
        }

        func awaitNotifications() {
            // Notifications run on the main thread, so if there are still queued notifications, they will run before this
            waitUntil { DispatchQueue.main.async(execute: $0) }
        }
    }

    override func spec() {
        describe("init") {
            it("no initial observers") {
                let notifier = FlagChangeNotifier()
                expect(notifier.flagChangeObservers).to(beEmpty())
                expect(notifier.flagsUnchangedObservers).to(beEmpty())
                expect(notifier.connectionModeChangedObservers).to(beEmpty())
            }
        }

        removeObserverSpec()
        notifyObserverSpec()
        notifyConnectionSpec()
    }

    private func removeObserverSpec() {
        describe("removeObserver") {
            var testContext: TestContext!
            var removedOwner: FlagChangeHandlerOwnerMock!
            beforeEach {
                testContext = TestContext()
                removedOwner = FlagChangeHandlerOwnerMock()
            }
            it("works when no observers exist") {
                testContext.subject.removeObserver(owner: removedOwner)
            }
            it("does not remove any when owner unused") {
                testContext.addConnectionModeObserver()
                testContext.addUnchangedObserver()
                testContext.addChangeObservers(forKeys: ["a", "b", "c"])
                testContext.addCollectionChangeObserver(forKeys: LDFlagKey.anyKey)
                testContext.addCollectionChangeObserver(forKeys: ["a", "b"])
                testContext.subject.removeObserver(owner: removedOwner)
                expect(testContext.subject.connectionModeChangedObservers.count) == 1
                expect(testContext.subject.flagsUnchangedObservers.count) == 1
                expect(testContext.subject.flagChangeObservers.count) == 5
            }
            it("can remove all observers") {
                testContext.addConnectionModeObserver(owner: removedOwner)
                testContext.addUnchangedObserver(owner: removedOwner)
                testContext.addChangeObservers(forKeys: ["a", "b", "c"], owner: removedOwner)
                testContext.addCollectionChangeObserver(forKeys: LDFlagKey.anyKey, owner: removedOwner)
                testContext.addCollectionChangeObserver(forKeys: ["a", "b"], owner: removedOwner)
                testContext.subject.removeObserver(owner: removedOwner)
                expect(testContext.subject.connectionModeChangedObservers.count) == 0
                expect(testContext.subject.flagsUnchangedObservers.count) == 0
                expect(testContext.subject.flagChangeObservers.count) == 0
            }
            it("can remove selected observers") {
                testContext.addUnchangedObserver()
                testContext.addChangeObserver(forKey: "a", owner: removedOwner)
                testContext.addCollectionChangeObserver(forKeys: LDFlagKey.anyKey)
                testContext.addCollectionChangeObserver(forKeys: ["a", "b"], owner: removedOwner)
                testContext.addConnectionModeObserver()
                testContext.subject.removeObserver(owner: removedOwner)
                expect(testContext.subject.connectionModeChangedObservers.count) == 1
                expect(testContext.subject.flagsUnchangedObservers.count) == 1
                expect(testContext.subject.flagChangeObservers.count) == 1
                expect(testContext.subject.flagChangeObservers.first!.flagKeys) == LDFlagKey.anyKey
            }
        }
    }

    private func notifyObserverSpec() {
        describe("notifyObservers") {
            var testContext: TestContext!
            beforeEach {
                testContext = TestContext()
            }
            context("singular flag observer") {
                beforeEach {
                    testContext.addChangeObservers(forKeys: ["a", "b"])
                    testContext.addCollectionChangeObserver(forKeys: LDFlagKey.anyKey)
                }
                it("is not called on unchanged") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: [:])
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)],
                                            newFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 2, flagVersion: 1)])
                    testContext.flagChangeObservers.forEach { expect($0.value.callCount) == 0 }
                }
                it("is called on creation") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)])
                    let expectedChange = LDChangedFlag(key: "a", oldValue: nil, newValue: 1)
                    expect(testContext.flagChangeObservers["a"]!.callCount) == 1
                    expect(testContext.flagChangeObservers["a"]!.lastCallArg) == expectedChange
                }
                it("is called on deletion") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)], newFlags: [:])
                    let expectedChange = LDChangedFlag(key: "a", oldValue: 1, newValue: nil)
                    expect(testContext.flagChangeObservers["a"]!.callCount) == 1
                    expect(testContext.flagChangeObservers["a"]!.lastCallArg) == expectedChange
                }
                it("is called on update") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)],
                                            newFlags: ["a": FeatureFlag(flagKey: "a", value: 2, variation: 1, version: 2, flagVersion: 1)])
                    let expectedChange = LDChangedFlag(key: "a", oldValue: 1, newValue: 2)
                    expect(testContext.flagChangeObservers["a"]!.callCount) == 1
                    expect(testContext.flagChangeObservers["a"]!.lastCallArg) == expectedChange
                }
                it("calls multiple singular observers") {
                    let changeObserver = MockFlagChangeObserver("a")
                    testContext.subject.addFlagChangeObserver(changeObserver.observer)
                    testContext.awaitNotify(oldFlags: [:], newFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)])
                    let expectedChange = LDChangedFlag(key: "a", oldValue: nil, newValue: 1)
                    expect(testContext.flagChangeObservers["a"]!.callCount) == 1
                    expect(testContext.flagChangeObservers["a"]!.lastCallArg) == expectedChange
                    expect(changeObserver.callCount) == 1
                    expect(changeObserver.lastCallArg) == expectedChange
                }
                afterEach {
                    expect(testContext.flagChangeObservers["b"]!.callCount) == 0
                }
            }
            context("multi flag observer") {
                beforeEach {
                    testContext.addCollectionChangeObserver(forKeys: ["a", "b"])
                }
                it("is not called on unchanged") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: [:])
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)],
                                            newFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 2, flagVersion: 1)])
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 0
                }
                it("is not called on unrelated") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: ["c": FeatureFlag(flagKey: "c", value: 1, variation: 1, version: 1, flagVersion: 1)])
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 0
                }
                it("is called on creation") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)])
                    let expectedChanges = ["a": LDChangedFlag(key: "a", oldValue: nil, newValue: 1)]
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 1
                    expect(testContext.flagCollectionChangeObservers.first!.lastCallArg) == expectedChanges
                }
                it("is called on deletion") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)], newFlags: [:])
                    let expectedChanges = ["a": LDChangedFlag(key: "a", oldValue: 1, newValue: nil)]
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 1
                    expect(testContext.flagCollectionChangeObservers.first!.lastCallArg) == expectedChanges
                }
                it("is called on update") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)],
                                            newFlags: ["a": FeatureFlag(flagKey: "a", value: 2, variation: 1, version: 2, flagVersion: 1)])
                    let expectedChanges = ["a": LDChangedFlag(key: "a", oldValue: 1, newValue: 2)]
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 1
                    expect(testContext.flagCollectionChangeObservers.first!.lastCallArg) == expectedChanges
                }
                it("called once with all updates") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1),
                                                       "b": FeatureFlag(flagKey: "b", value: "a", variation: 1, version: 1, flagVersion: 1)],
                                            newFlags: ["b": FeatureFlag(flagKey: "b", value: "b", variation: 1, version: 2, flagVersion: 1),
                                                       "c": FeatureFlag(flagKey: "c", value: false, variation: 1, version: 1, flagVersion: 1)])
                    let expectedChanges = ["a": LDChangedFlag(key: "a", oldValue: 1, newValue: nil),
                                           "b": LDChangedFlag(key: "b", oldValue: "a", newValue: "b")]
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 1
                    expect(testContext.flagCollectionChangeObservers.first!.lastCallArg) == expectedChanges
                }
            }
            context("any flag observer") {
                beforeEach {
                    testContext.addCollectionChangeObserver(forKeys: LDFlagKey.anyKey)
                }
                it("is not called on unchanged") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: [:])
                    testContext.flagCollectionChangeObservers.forEach { expect($0.callCount) == 0 }
                }
                it("is called on creation") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)])
                    let expectedChanges = ["a": LDChangedFlag(key: "a", oldValue: nil, newValue: 1)]
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 1
                    expect(testContext.flagCollectionChangeObservers.first!.lastCallArg) == expectedChanges
                }
                it("is called on deletion") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)], newFlags: [:])
                    let expectedChanges = ["a": LDChangedFlag(key: "a", oldValue: 1, newValue: nil)]
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 1
                    expect(testContext.flagCollectionChangeObservers.first!.lastCallArg) == expectedChanges
                }
                it("is called on update") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)],
                                            newFlags: ["a": FeatureFlag(flagKey: "a", value: 2, variation: 1, version: 2, flagVersion: 1)])
                    let expectedChanges = ["a": LDChangedFlag(key: "a", oldValue: 1, newValue: 2)]
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 1
                    expect(testContext.flagCollectionChangeObservers.first!.lastCallArg) == expectedChanges
                }
                it("called once with all updates") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1),
                                                       "b": FeatureFlag(flagKey: "b", value: "a", variation: 1, version: 1, flagVersion: 1)],
                                            newFlags: ["b": FeatureFlag(flagKey: "b", value: "b", variation: 1, version: 2, flagVersion: 1),
                                                       "c": FeatureFlag(flagKey: "c", value: false, variation: 1, version: 1, flagVersion: 1)])
                    let expectedChanges = ["a": LDChangedFlag(key: "a", oldValue: 1, newValue: nil),
                                           "b": LDChangedFlag(key: "b", oldValue: "a", newValue: "b"),
                                           "c": LDChangedFlag(key: "c", oldValue: nil, newValue: false)]
                    expect(testContext.flagCollectionChangeObservers.first!.callCount) == 1
                    expect(testContext.flagCollectionChangeObservers.first!.lastCallArg) == expectedChanges
                }
            }
            context("unchanged observer") {
                beforeEach {
                    testContext.addChangeObservers(forKeys: ["a", "b"])
                    testContext.addCollectionChangeObserver(forKeys: ["a", "b"])
                    testContext.addCollectionChangeObserver(forKeys: LDFlagKey.anyKey)
                    testContext.addUnchangedObserver()
                    testContext.addUnchangedObserver()
                }
                it("is not called on changes") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: ["c": FeatureFlag(flagKey: "c", value: 1, variation: 1, version: 1, flagVersion: 1)])
                    testContext.awaitNotify(oldFlags: ["c": FeatureFlag(flagKey: "c", value: 1, variation: 1, version: 1, flagVersion: 1)], newFlags: [:])
                    testContext.awaitNotify(oldFlags: ["c": FeatureFlag(flagKey: "c", value: 1, variation: 1, version: 1, flagVersion: 1)],
                                            newFlags: ["c": FeatureFlag(flagKey: "c", value: 2, variation: 1, version: 2, flagVersion: 1)])
                    testContext.flagsUnchangedObservers.forEach { expect($0.callCount) == 0 }
                }
                it("is called when flags unchanged") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: [:])
                    testContext.flagsUnchangedObservers.forEach { expect($0.callCount) == 1 }
                }
                it("is called when explicitly unchanged") {
                    testContext.subject.notifyUnchanged()
                    testContext.awaitNotifications()
                    testContext.flagsUnchangedObservers.forEach { expect($0.callCount) == 1 }
                }
            }
            context("removes and does not notify expired observers") {
                beforeEach {
                    testContext.addChangeObservers(forKeys: ["a", "b"])
                    testContext.addCollectionChangeObserver(forKeys: ["a", "b"])
                    testContext.addCollectionChangeObserver(forKeys: LDFlagKey.anyKey)
                    testContext.addUnchangedObserver()
                    // Set expired
                    testContext.flagChangeObservers.forEach { $0.value.owner = nil }
                    testContext.flagCollectionChangeObservers.forEach { $0.owner = nil }
                    testContext.flagsUnchangedObservers.forEach { $0.owner = nil }
                }
                it("for added") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)])
                }
                it("for removed") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)], newFlags: [:])
                }
                it("for updated") {
                    testContext.awaitNotify(oldFlags: ["a": FeatureFlag(flagKey: "a", value: 1, variation: 1, version: 1, flagVersion: 1)],
                                            newFlags: ["a": FeatureFlag(flagKey: "a", value: 2, variation: 1, version: 1, flagVersion: 1)])
                }
                it("for unchanged") {
                    testContext.awaitNotify(oldFlags: [:], newFlags: [:])
                }
                it("for explicit unchanged") {
                    testContext.subject.notifyUnchanged()
                    testContext.awaitNotifications()
                }
                afterEach {
                    testContext.flagChangeObservers.forEach { expect($0.value.callCount) == 0 }
                    testContext.flagCollectionChangeObservers.forEach { expect($0.callCount) == 0 }
                    testContext.flagsUnchangedObservers.forEach { expect($0.callCount) == 0 }

                    expect(testContext.subject.flagChangeObservers).to(beEmpty())
                    expect(testContext.subject.flagsUnchangedObservers).to(beEmpty())
                }
            }
        }
    }

    private func notifyConnectionSpec() {
        describe("notifyConnectionModeChangedObservers") {
            it("removes and does not notify expired observers") {
                let testContext = TestContext()
                let nonExpiredObserver = MockConnectionModeChangedObserver()
                let expiredObserver = MockConnectionModeChangedObserver()
                testContext.subject.addConnectionModeChangedObserver(nonExpiredObserver.observer)
                testContext.subject.addConnectionModeChangedObserver(expiredObserver.observer)
                expiredObserver.owner = nil
                testContext.subject.notifyConnectionModeChangedObservers(connectionMode: .polling)
                testContext.awaitNotifications()
                expect(expiredObserver.callCount) == 0
                expect(testContext.subject.connectionModeChangedObservers.count) == 1
                expect(nonExpiredObserver.callCount) == 1
                expect(nonExpiredObserver.lastCallArg) == .polling
            }
        }
    }
}

private final class FlagChangeHandlerOwnerMock { }

extension LDChangedFlag: Equatable {
    public static func == (lhs: LDChangedFlag, rhs: LDChangedFlag) -> Bool {
        lhs.key == rhs.key && lhs.oldValue == rhs.oldValue && lhs.newValue == rhs.newValue
    }
}
