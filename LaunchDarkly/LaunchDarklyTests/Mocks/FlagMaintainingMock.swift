import Foundation
@testable import LaunchDarkly

final class FlagMaintainingMock: FlagMaintaining {
    let innerStore: FlagStore

    init() {
        innerStore = FlagStore()
    }

    init(storedItems: StoredItems) {
        innerStore = FlagStore(storedItems: storedItems)
    }

    var storedItems: StoredItems {
        innerStore.storedItems
    }

    var replaceStoreCallCount = 0
    var replaceStoreReceivedNewFlags: StoredItems?
    func replaceStore(newStoredItems: StoredItems) {
        replaceStoreCallCount += 1
        replaceStoreReceivedNewFlags = newStoredItems
        innerStore.replaceStore(newStoredItems: newStoredItems)
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

    static func stubStoredItems() -> StoredItems {
        let flags = DarklyServiceMock.Constants.stubFeatureFlags()
        var storedItems = StoredItems(items: flags)
        storedItems["userKey"] = .item(FeatureFlag(flagKey: "userKey",
                                       value: .string(UUID().uuidString),
                                       variation: DarklyServiceMock.Constants.variation,
                                       version: DarklyServiceMock.Constants.version,
                                       flagVersion: DarklyServiceMock.Constants.flagVersion,
                                       trackEvents: true,
                                       debugEventsUntilDate: Date().addingTimeInterval(30.0),
                                       reason: DarklyServiceMock.Constants.reason,
                                       trackReason: false))
        return storedItems
    }
}
