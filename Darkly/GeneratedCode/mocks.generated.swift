// Generated using Sourcery 0.9.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

//swiftlint:disable vertical_whitespace


@testable import Darkly

// MARK: - LDFlagMaintainingMock
final class LDFlagMaintainingMock: LDFlagMaintaining {

    // MARK: replaceStore
    var replaceStoreCallCount = 0
    var replaceStoreReceivedArguments: (newFlags: [String: Any]?, source: LDFlagValueSource, completion: (() -> Void)?)?
    func replaceStore(newFlags: [String: Any]?, source: LDFlagValueSource, completion: (() -> Void)?) {
        replaceStoreCallCount += 1
        replaceStoreReceivedArguments = (newFlags: newFlags, source: source, completion: completion)
    }

    // MARK: updateStore
    var updateStoreCallCount = 0
    var updateStoreReceivedArguments: (newFlags: [String: Any], source: LDFlagValueSource, completion: (() -> Void)?)?
    func updateStore(newFlags: [String: Any], source: LDFlagValueSource, completion: (() -> Void)?) {
        updateStoreCallCount += 1
        updateStoreReceivedArguments = (newFlags: newFlags, source: source, completion: completion)
    }

    // MARK: deleteFlag
    var deleteFlagCallCount = 0
    var deleteFlagReceivedArguments: (name: String, completion: (() -> Void)?)?
    func deleteFlag(name: String, completion: (() -> Void)?) {
        deleteFlagCallCount += 1
        deleteFlagReceivedArguments = (name: name, completion: completion)
    }
}
