import Foundation
import OSLog

enum StorageItem: Codable {
    case item(FeatureFlag)
    case tombstone(Int)

    var version: Int {
        switch self {
        case .item(let flag):
            return flag.version ?? 0
        case .tombstone(let version):
            return version
        }
    }

    enum CodingKeys: CodingKey {
        case item, tombstone
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .item(flag):
            try container.encode(flag, forKey: .item)
        case let .tombstone(version):
            try container.encode(version, forKey: .tombstone)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.allKeys.count != 1 {
            let context = DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Invalid number of keys found, expected one.")
            throw DecodingError.typeMismatch(StorageItem.self, context)
        }

        switch container.allKeys.first.unsafelyUnwrapped {
        case .item:
            self = .item(try container.decode(FeatureFlag.self, forKey: .item))
        case .tombstone:
            self = .tombstone(try container.decode(Int.self, forKey: .tombstone))
        }
    }
}

typealias StoredItems = [LDFlagKey: StorageItem]
extension StoredItems {
    var featureFlags: [LDFlagKey: FeatureFlag] {
        self.compactMapValues {
            guard case .item(let flag) = $0 else { return nil }
            return flag
        }
    }

    init(items: [LDFlagKey: FeatureFlag]) {
        self = items.mapValues { .item($0) }
    }
}

protocol FlagMaintaining {
    var storedItems: StoredItems { get }

    func replaceStore(newStoredItems: StoredItems)
    func updateStore(updatedFlag: FeatureFlag)
    func deleteFlag(deleteResponse: DeleteResponse)
    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag?
}

final class FlagStore: FlagMaintaining {
    struct Constants {
        fileprivate static let flagQueueLabel = "com.launchdarkly.flagStore.flagQueue"
    }

    var storedItems: StoredItems { flagQueue.sync { _storedItems } }

    private var _storedItems: StoredItems = [:]
    // Used with .barrier as reader writer lock on _featureFlags
    private var flagQueue = DispatchQueue(label: Constants.flagQueueLabel, attributes: .concurrent)

    private let logger: OSLog

    init(logger: OSLog) {
        self.logger = logger
    }

    init(logger: OSLog, storedItems: StoredItems) {
        self.logger = logger
        self._storedItems = storedItems
        os_log("%s with %d items", log: logger, type: .debug, typeName(and: #function), storedItems.count)
    }

    func replaceStore(newStoredItems: StoredItems) {
        os_log("%s replacing %d items", log: logger, type: .debug, typeName(and: #function), newStoredItems.count)
        flagQueue.sync(flags: .barrier) {
            self._storedItems = newStoredItems
        }
    }

    func updateStore(updatedFlag: FeatureFlag) {
        flagQueue.sync(flags: .barrier) {
            guard self.isValidVersion(for: updatedFlag.flagKey, newVersion: updatedFlag.version)
            else {
                os_log("%s aborted. Invalid version. updateDictionary: %s existing flag: %s", log: logger, type: .debug, typeName(and: #function), String(describing: updatedFlag), String(describing: self._storedItems[updatedFlag.flagKey]))
                return
            }

            os_log("%s updated flag %s", log: logger, type: .debug, typeName(and: #function), updatedFlag.flagKey)
            self._storedItems.updateValue(StorageItem.item(updatedFlag), forKey: updatedFlag.flagKey)
        }
    }

    func deleteFlag(deleteResponse: DeleteResponse) {
        flagQueue.sync(flags: .barrier) {
            guard self.isValidVersion(for: deleteResponse.key, newVersion: deleteResponse.version)
            else {
                os_log("%s aborted. Invalid version. deleteResponse: %s existing flag: %s", log: logger, type: .debug, typeName(and: #function), String(describing: deleteResponse), String(describing: self._storedItems[deleteResponse.key]))
                return
            }

            os_log("%s deleted flag %s", log: logger, type: .debug, typeName(and: #function), deleteResponse.key)
            self._storedItems.updateValue(StorageItem.tombstone(deleteResponse.version ?? 0), forKey: deleteResponse.key)
        }
    }

    private func isValidVersion(for flagKey: LDFlagKey, newVersion: Int?) -> Bool {
        // Currently only called from within barrier, only call on flagQueue
        // Use only the version, here called "environmentVersion" for comparison. The flagVersion is only used for event reporting.
        if let environmentVersion = _storedItems[flagKey]?.version,
           let newEnvironmentVersion = newVersion {
            return newEnvironmentVersion > environmentVersion
        }
        // Always update if either environment version is missing, or updating non-existent flag
        return true
    }

    func featureFlag(for flagKey: LDFlagKey) -> FeatureFlag? {
        flagQueue.sync {
            guard case let .item(flag) = _storedItems[flagKey] else {
                return nil
            }
            return flag
        }
    }
}

extension FlagStore: TypeIdentifying { }
