import Foundation
import XCTest

@testable import LaunchDarkly

final class FlagStoreSpec: XCTestCase {
    let stubFlags = DarklyServiceMock.Constants.stubFeatureFlags()

    func testInit() {
        XCTAssertEqual(FlagStore().storedItems, [:])
        XCTAssertEqual(FlagStore(storedItems: StoredItems(items: self.stubFlags)).storedItems.featureFlags, self.stubFlags)
    }

    func testReplaceStore() {
        let featureFlags = StoredItems(items: DarklyServiceMock.Constants.stubFeatureFlags())
        let flagStore = FlagStore()
        flagStore.replaceStore(newStoredItems: featureFlags)
        XCTAssertEqual(flagStore.storedItems, featureFlags)
    }

    func testUpdateStoreNewFlag() {
        let flagStore = FlagStore(storedItems: StoredItems(items: stubFlags))
        let flagUpdate = FeatureFlag(flagKey: "new-int-flag", value: "abc", version: 0)
        flagStore.updateStore(updatedFlag: flagUpdate)
        XCTAssertEqual(flagStore.storedItems.count, stubFlags.count + 1)
        XCTAssertEqual(flagStore.storedItems.featureFlags["new-int-flag"], flagUpdate)
    }

    func testUpdateStoreNewerVersion() {
        let flagStore = FlagStore(storedItems: StoredItems(items: stubFlags))
        let flagUpdate = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.int, useAlternateVersion: true)
        flagStore.updateStore(updatedFlag: flagUpdate)
        XCTAssertEqual(flagStore.storedItems.count, stubFlags.count)
        XCTAssertEqual(flagStore.storedItems.featureFlags[DarklyServiceMock.FlagKeys.int], flagUpdate)
    }

    func testUpdateStoreNoVersion() {
        let flagStore = FlagStore(storedItems: StoredItems(items: stubFlags))
        let flagUpdate = FeatureFlag(flagKey: DarklyServiceMock.FlagKeys.int, value: "abc", version: nil)
        flagStore.updateStore(updatedFlag: flagUpdate)
        XCTAssertEqual(flagStore.storedItems.count, stubFlags.count)
        XCTAssertEqual(flagStore.storedItems.featureFlags[DarklyServiceMock.FlagKeys.int], flagUpdate)
    }

    func testUpdateStoreEarlierOrSameVersion() {
        let testFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.int)
        let initialVersion = testFlag.version!
        let flagStore = FlagStore(storedItems: StoredItems(items: stubFlags))
        let flagUpdateSameVersion = FeatureFlag(flagKey: DarklyServiceMock.FlagKeys.int, value: "abc", version: initialVersion)
        let flagUpdateOlderVersion = FeatureFlag(flagKey: DarklyServiceMock.FlagKeys.int, value: "abc", version: initialVersion - 1)
        flagStore.updateStore(updatedFlag: flagUpdateSameVersion)
        flagStore.updateStore(updatedFlag: flagUpdateOlderVersion)
        XCTAssertEqual(flagStore.storedItems.featureFlags, self.stubFlags)
    }

    func testDeleteFlagNewerVersion() {
        let flagStore = FlagStore(storedItems: StoredItems(items: stubFlags))
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1))
        XCTAssertEqual(flagStore.storedItems.count, self.stubFlags.count)
        XCTAssertEqual(flagStore.storedItems.featureFlags.count, self.stubFlags.count - 1)
        XCTAssertEqual(StorageItem.tombstone(5), flagStore.storedItems[DarklyServiceMock.FlagKeys.int])
    }

    func testDeleteFlagMissingVersion() {
        let flagStore = FlagStore(storedItems: StoredItems(items: stubFlags))
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: DarklyServiceMock.FlagKeys.int, version: nil))
        XCTAssertEqual(flagStore.storedItems.count, self.stubFlags.count)
        XCTAssertEqual(flagStore.storedItems.featureFlags.count, self.stubFlags.count - 1)
        XCTAssertEqual(StorageItem.tombstone(0), flagStore.storedItems[DarklyServiceMock.FlagKeys.int])
    }

    func testDeleteOlderOrNonExistent() {
        let flagStore = FlagStore(storedItems: StoredItems(items: stubFlags))
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version))
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version - 1))
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: "new-int-flag", version: DarklyServiceMock.Constants.version + 1))
        XCTAssertEqual(flagStore.storedItems.featureFlags, self.stubFlags)
    }

    func testCannotReplaceDeletedFlagWithOlderVersion() {
        let flagStore = FlagStore(storedItems: StoredItems(items: stubFlags))
        let flagUpdate = FeatureFlag(flagKey: "new-int-flag", value: "abc", version: 0)
        flagStore.updateStore(updatedFlag: flagUpdate)
        XCTAssertEqual(stubFlags.count + 1, flagStore.storedItems.count)
        XCTAssertEqual(stubFlags.count + 1, flagStore.storedItems.featureFlags.count)

        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: "new-int-flag", version: 1))
        XCTAssertEqual(stubFlags.count + 1, flagStore.storedItems.count)
        XCTAssertEqual(stubFlags.count, flagStore.storedItems.featureFlags.count)

        flagStore.updateStore(updatedFlag: flagUpdate)
        XCTAssertEqual(stubFlags.count + 1, flagStore.storedItems.count)
        XCTAssertEqual(stubFlags.count, flagStore.storedItems.featureFlags.count)
    }

    func testFeatureFlag() {
        let flagStore = FlagStore(storedItems: StoredItems(items: stubFlags))
        flagStore.storedItems.forEach { flagKey, featureFlag in
            guard case .item(let flag) = featureFlag
            else {
                XCTAssertNil(flagStore.featureFlag(for: flagKey))
                return
            }

            XCTAssertEqual(flagStore.featureFlag(for: flagKey), flag)
        }
        XCTAssertNil(flagStore.featureFlag(for: DarklyServiceMock.FlagKeys.unknown))
    }
}
