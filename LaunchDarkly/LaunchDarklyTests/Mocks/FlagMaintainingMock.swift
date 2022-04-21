import Foundation
@testable import LaunchDarkly

final class FlagMaintainingMock: FlagMaintaining {
    let innerStore: FlagStore

    init() {
        innerStore = FlagStore()
    }

    init(flags: [LDFlagKey: FeatureFlag]) {
        innerStore = FlagStore(featureFlags: flags)
    }

    var featureFlags: [LDFlagKey: FeatureFlag] {
        innerStore.featureFlags
    }

    var replaceStoreCallCount = 0
    var replaceStoreReceivedNewFlags: FeatureFlagCollection?
    func replaceStore(newFlags: FeatureFlagCollection) {
        replaceStoreCallCount += 1
        replaceStoreReceivedNewFlags = newFlags
        innerStore.replaceStore(newFlags: newFlags)
    }

    var updateStoreCallCount = 0
    var updateStoreReceivedUpdatedFlag: FeatureFlag?
    func updateStore(updatedFlag: FeatureFlag) {
        updateStoreCallCount += 1
        updateStoreReceivedUpdatedFlag = updatedFlag
        innerStore.updateStore(updatedFlag: updatedFlag)
    }

    var deleteFlagCallCount = 0
    var deleteFlagReceivedDeleteResponse: DeleteResponse?
    func deleteFlag(deleteResponse: DeleteResponse) {
        deleteFlagCallCount += 1
        deleteFlagReceivedDeleteResponse = deleteResponse
        innerStore.deleteFlag(deleteResponse: deleteResponse)
    }

    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag? {
        innerStore.featureFlag(for: flagKey)
    }

    static func stubFlags() -> [LDFlagKey: FeatureFlag] {
        var flags = DarklyServiceMock.Constants.stubFeatureFlags()
        flags["userKey"] = FeatureFlag(flagKey: "userKey",
                                       value: .string(UUID().uuidString),
                                       variation: DarklyServiceMock.Constants.variation,
                                       version: DarklyServiceMock.Constants.version,
                                       flagVersion: DarklyServiceMock.Constants.flagVersion,
                                       trackEvents: true,
                                       debugEventsUntilDate: Date().addingTimeInterval(30.0),
                                       reason: DarklyServiceMock.Constants.reason,
                                       trackReason: false)
        return flags
    }
}
