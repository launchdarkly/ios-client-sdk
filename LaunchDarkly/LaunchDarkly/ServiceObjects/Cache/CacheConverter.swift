import Foundation

// sourcery: autoMockable
protocol CacheConverting {
    func convertCacheData(serviceFactory: ClientServiceCreating, keysToConvert: [MobileKey], maxCachedUsers: Int)
}

// Cache model in SDK versions >=4.0.0 <6.0.0. Migration is not supported for earlier versions.
//
//     [<userKey>: [
//         “userKey”: <userKey>,
//         “environmentFlags”: [
//             <mobileKey>: [
//                 “userKey”: <userKey>,
//                 “mobileKey”: <mobileKey>,
//                 “featureFlags”: [
//                     <flagKey>: [
//                         “key”: <flagKey>,
//                         “version”: <modelVersion>,
//                         “flagVersion”: <flagVersion>,
//                         “variation”: <variation>,
//                         “value”: <value>,
//                         “trackEvents”: <trackEvents>,
//                         “debugEventsUntilDate”: <debugEventsUntilDate>,
//                         "reason: <reason>,
//                         "trackReason": <trackReason>
//                         ]
//                     ]
//                 ]
//             ],
//         “lastUpdated”: <lastUpdated>
//         ]
//     ]

final class CacheConverter: CacheConverting {

    init() { }

    private func convertValue(_ value: Any?) -> LDValue {
        guard let value = value, !(value is NSNull)
        else { return .null }
        if let boolValue = value as? Bool { return .bool(boolValue) }
        if let numValue = value as? NSNumber { return .number(Double(truncating: numValue)) }
        if let stringValue = value as? String { return .string(stringValue) }
        if let arrayValue = value as? [Any?] { return .array(arrayValue.map { convertValue($0) }) }
        if let dictValue = value as? [String: Any?] { return .object(dictValue.mapValues { convertValue($0) }) }
        return .null
    }

    private func convertV6Data(v6cache: KeyedValueCaching, flagCaches: [MobileKey: FeatureFlagCaching]) {
        guard let cachedV6Data = v6cache.dictionary(forKey: "com.launchDarkly.cachedUserEnvironmentFlags")
        else { return }

        var cachedEnvData: [MobileKey: [String: (updated: Date, flags: [LDFlagKey: FeatureFlag])]] = [:]
        cachedV6Data.forEach { userKey, userDict in
            guard let userDict = userDict as? [String: Any],
                  let userDictUserKey = userDict["userKey"] as? String,
                  let lastUpdated = (userDict["lastUpdated"] as? String)?.dateValue,
                  let envsDict = userDict["environmentFlags"] as? [String: Any],
                  userKey == userDictUserKey
            else { return }
            envsDict.forEach { mobileKey, envDict in
                guard flagCaches.keys.contains(mobileKey),
                      let envDict = envDict as? [String: Any],
                      let envUserKey = envDict["userKey"] as? String,
                      let envMobileKey = envDict["mobileKey"] as? String,
                      let envFlags = envDict["featureFlags"] as? [String: Any],
                      envUserKey == userKey && envMobileKey == mobileKey
                else { return }

                var userEnvFlags: [LDFlagKey: FeatureFlag] = [:]
                envFlags.forEach { flagKey, flagDict in
                    guard let flagDict = flagDict as? [String: Any]
                    else { return }
                    let flag = FeatureFlag(flagKey: flagKey,
                                           value: convertValue(flagDict["value"]),
                                           variation: flagDict["variation"] as? Int,
                                           version: flagDict["version"] as? Int,
                                           flagVersion: flagDict["flagVersion"] as? Int,
                                           trackEvents: flagDict["trackEvents"] as? Bool ?? false,
                                           debugEventsUntilDate: Date(millisSince1970: flagDict["debugEventsUntilDate"] as? Int64),
                                           reason: (flagDict["reason"] as? [String: Any])?.mapValues { convertValue($0) },
                                           trackReason: flagDict["trackReason"] as? Bool ?? false)
                    userEnvFlags[flagKey] = flag
                }
                var otherEnvData = cachedEnvData[mobileKey] ?? [:]
                otherEnvData[userKey] = (lastUpdated, userEnvFlags)
                cachedEnvData[mobileKey] = otherEnvData
            }
        }

        cachedEnvData.forEach { mobileKey, users in
            users.forEach { userKey, data in
                flagCaches[mobileKey]?.storeFeatureFlags(StoredItems(items: data.flags), userKey: userKey, lastUpdated: data.updated)
            }
        }

        v6cache.removeObject(forKey: "com.launchDarkly.cachedUserEnvironmentFlags")
    }

    private func convertV7Data(flagCaches: inout [MobileKey: FeatureFlagCaching]) {
        for (_, flagCaching) in flagCaches {
            flagCaching.keyedValueCache.keys().forEach { key in
                guard let cachedData = flagCaching.keyedValueCache.data(forKey: key),
                      let cachedFlags = try? JSONDecoder().decode(FeatureFlagCollection.self, from: cachedData)
                else { return }

                guard let encoded = try? JSONEncoder().encode(StoredItemCollection(cachedFlags))
                else { return }

                flagCaching.keyedValueCache.set(encoded, forKey: key)
            }
        }
    }

    func convertCacheData(serviceFactory: ClientServiceCreating, keysToConvert: [MobileKey], maxCachedUsers: Int) {
        var flagCaches: [String: FeatureFlagCaching] = [:]
        keysToConvert.forEach { mobileKey in
            let flagCache = serviceFactory.makeFeatureFlagCache(mobileKey: mobileKey, maxCachedUsers: maxCachedUsers)
            flagCaches[mobileKey] = flagCache
            // Get current cache version and return if up to date
            guard let cacheVersionData = flagCache.keyedValueCache.data(forKey: "ld-cache-metadata")
            else { return } // Convert those that do not have a version
            guard let cacheVersion = (try? JSONDecoder().decode([String: Int].self, from: cacheVersionData))?["version"],
                  cacheVersion == 7 || cacheVersion == 8
            else {
                // Metadata is invalid, remove existing data and attempt migration
                flagCache.keyedValueCache.removeAll()
                return
            }

            if cacheVersion == 8 {
                // Already up to date
                flagCaches.removeValue(forKey: mobileKey)
            }
        }

        // Skip migration if all environments are V8
        if flagCaches.isEmpty { return }

        // Remove V5 cache data (migration not supported)
        let standardDefaults = serviceFactory.makeKeyedValueCache(cacheKey: nil)
        standardDefaults.removeObject(forKey: "com.launchdarkly.dataManager.userEnvironments")

        convertV6Data(v6cache: standardDefaults, flagCaches: flagCaches)
        convertV7Data(flagCaches: &flagCaches)

        // Set cache version to skip this logic in the future
        if let versionMetadata = try? JSONEncoder().encode(["version": 8]) {
            flagCaches.forEach {
                $0.value.keyedValueCache.set(versionMetadata, forKey: "ld-cache-metadata")
            }
        }
    }
}

extension Date {
    func isExpired(expirationDate: Date) -> Bool {
        self.stringEquivalentDate < expirationDate.stringEquivalentDate
    }
}

extension DateFormatter {
    /// Date formatter configured to format dates to/from the format 2018-08-13T19:06:38.123Z
    class var ldDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }
}

extension Date {
    /// Date string using the format 2018-08-13T19:06:38.123Z
    var stringValue: String { DateFormatter.ldDateFormatter.string(from: self) }

    // When a date is converted to JSON, the resulting string is not as precise as the original date (only to the nearest .001s)
    // By converting the date to json, then back into a date, the result can be compared with any date re-inflated from json
    /// Date truncated to the nearest millisecond, which is the precision for string formatted dates
    var stringEquivalentDate: Date { stringValue.dateValue }
}

extension String {
    /// Date converted from a string using the format 2018-08-13T19:06:38.123Z
    var dateValue: Date { DateFormatter.ldDateFormatter.date(from: self) ?? Date() }
}
