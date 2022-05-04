import Foundation
import XCTest

@testable import LaunchDarkly

final class FlagStoreSpec: XCTestCase {
    let stubFlags = DarklyServiceMock.Constants.stubFeatureFlags()

    func testInit() {
        XCTAssertEqual(FlagStore().featureFlags, [:])
        XCTAssertEqual(FlagStore(featureFlags: self.stubFlags).featureFlags, self.stubFlags)
    }

    func testReplaceStore() {
        let featureFlags: [LDFlagKey: FeatureFlag] = DarklyServiceMock.Constants.stubFeatureFlags()
        let flagStore = FlagStore()
        flagStore.replaceStore(newFlags: FeatureFlagCollection(featureFlags))
        XCTAssertEqual(flagStore.featureFlags, featureFlags)
    }

    func testUpdateStoreNewFlag() {
        let flagStore = FlagStore(featureFlags: stubFlags)
        let flagUpdate = FeatureFlag(flagKey: "new-int-flag", value: "abc", version: 0)
        flagStore.updateStore(updatedFlag: flagUpdate)
        XCTAssertEqual(flagStore.featureFlags.count, stubFlags.count + 1)
        XCTAssertEqual(flagStore.featureFlags["new-int-flag"], flagUpdate)
    }

    func testUpdateStoreNewerVersion() {
        let flagStore = FlagStore(featureFlags: stubFlags)
        let flagUpdate = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.int, useAlternateVersion: true)
        flagStore.updateStore(updatedFlag: flagUpdate)
        XCTAssertEqual(flagStore.featureFlags.count, stubFlags.count)
        XCTAssertEqual(flagStore.featureFlags[DarklyServiceMock.FlagKeys.int], flagUpdate)
    }

    func testUpdateStoreNoVersion() {
        let flagStore = FlagStore(featureFlags: stubFlags)
        let flagUpdate = FeatureFlag(flagKey: DarklyServiceMock.FlagKeys.int, value: "abc", version: nil)
        flagStore.updateStore(updatedFlag: flagUpdate)
        XCTAssertEqual(flagStore.featureFlags.count, stubFlags.count)
        XCTAssertEqual(flagStore.featureFlags[DarklyServiceMock.FlagKeys.int], flagUpdate)
    }

    func testUpdateStoreEarlierOrSameVersion() {
        let testFlag = DarklyServiceMock.Constants.stubFeatureFlag(for: DarklyServiceMock.FlagKeys.int)
        let initialVersion = testFlag.version!
        let flagStore = FlagStore(featureFlags: stubFlags)
        let flagUpdateSameVersion = FeatureFlag(flagKey: DarklyServiceMock.FlagKeys.int, value: "abc", version: initialVersion)
        let flagUpdateOlderVersion = FeatureFlag(flagKey: DarklyServiceMock.FlagKeys.int, value: "abc", version: initialVersion - 1)
        flagStore.updateStore(updatedFlag: flagUpdateSameVersion)
        flagStore.updateStore(updatedFlag: flagUpdateOlderVersion)
        XCTAssertEqual(flagStore.featureFlags, self.stubFlags)
    }

    func testDeleteFlagNewerVersion() {
        let flagStore = FlagStore(featureFlags: stubFlags)
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1))
        XCTAssertEqual(flagStore.featureFlags.count, self.stubFlags.count - 1)
        XCTAssertNil(flagStore.featureFlags[DarklyServiceMock.FlagKeys.int])
    }

    func testDeleteFlagMissingVersion() {
        let flagStore = FlagStore(featureFlags: stubFlags)
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: DarklyServiceMock.FlagKeys.int, version: nil))
        XCTAssertEqual(flagStore.featureFlags.count, self.stubFlags.count - 1)
        XCTAssertNil(flagStore.featureFlags[DarklyServiceMock.FlagKeys.int])
    }

    func testDeleteOlderOrNonExistent() {
        let flagStore = FlagStore(featureFlags: stubFlags)
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version))
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version - 1))
        flagStore.deleteFlag(deleteResponse: DeleteResponse(key: "new-int-flag", version: DarklyServiceMock.Constants.version + 1))
        XCTAssertEqual(flagStore.featureFlags, self.stubFlags)
    }

    func testFeatureFlag() {
        let flagStore = FlagStore(featureFlags: stubFlags)
        flagStore.featureFlags.forEach { flagKey, featureFlag in
            XCTAssertEqual(flagStore.featureFlag(for: flagKey), featureFlag)
        }
        XCTAssertNil(flagStore.featureFlag(for: DarklyServiceMock.FlagKeys.unknown))
    }
}
