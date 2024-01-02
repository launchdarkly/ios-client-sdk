import Foundation

// sourcery: autoMockable
protocol CacheConverting {
    func convertCacheData(serviceFactory: ClientServiceCreating, keysToConvert: [MobileKey], maxCachedContexts: Int)
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

    static let latestCacheVersion = 9
    // The key used for storing data in the cache changed starting in v9. All caches prior to this version should be removed.
    static let fullHashCacheVersion = 9

    init() { }

    func convertCacheData(serviceFactory: ClientServiceCreating, keysToConvert: [MobileKey], maxCachedContexts: Int) {
        // Remove V5 cache data
        let standardDefaults = serviceFactory.makeKeyedValueCache(cacheKey: nil)
        standardDefaults.removeObject(forKey: "com.launchdarkly.dataManager.userEnvironments")

        var cachesToDelete: [String: FeatureFlagCaching] = [:]
        var cachesToConvert: [String: FeatureFlagCaching] = [:]
        keysToConvert.forEach { mobileKey in
            let flagCache = serviceFactory.makeFeatureFlagCache(mobileKey: mobileKey, maxCachedContexts: maxCachedContexts)

            guard let cacheVersionData = flagCache.keyedValueCache.data(forKey: "ld-cache-metadata")
            else { cachesToDelete[mobileKey] = flagCache; return }

            guard let cacheVersion = (try? JSONDecoder().decode([String: Int].self, from: cacheVersionData))?["version"]
            else { cachesToDelete[mobileKey] = flagCache; return }

            if cacheVersion == CacheConverter.latestCacheVersion {
                return
            } else if cacheVersion < CacheConverter.fullHashCacheVersion {
                cachesToDelete[mobileKey] = flagCache
            } else {
                cachesToConvert[mobileKey] = flagCache
            }
        }

        if let versionMetadata = try? JSONEncoder().encode(["version": CacheConverter.latestCacheVersion]) {
            cachesToDelete.forEach { (_, cache) in
                cache.keyedValueCache.removeAll()
                cache.keyedValueCache.set(versionMetadata, forKey: "ld-cache-metadata")
            }

            // Update cachesToConvert once we have something that needs migrating
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
