//
//  FlagCounter.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 6/19/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation

final class FlagCounter {
    enum CodingKeys: String, CodingKey {
        case defaultValue = "default", counters
    }

    var defaultValue: Any? = nil
    var flagValueCounters = [FlagValueCounter]()

    func trackRequest(reportedValue: Any?, featureFlag: FeatureFlag?, defaultValue: Any?) {
        self.defaultValue = defaultValue
        var flagValueCounter = flagValueCounters.flagValueCounter(for: featureFlag)
        if flagValueCounter == nil {
            let newFlagValueCounter = FlagValueCounter(reportedValue: reportedValue, featureFlag: featureFlag)
            flagValueCounters.append(newFlagValueCounter)
            flagValueCounter = newFlagValueCounter
        }
        if flagValueCounter?.isKnown == false { //keep the last reported value
            flagValueCounter?.reportedValue = reportedValue
        }
        flagValueCounter?.count += 1
    }

    /* Creates a dictionary of the form
        "default": "default-value",
        "counters": [
            {
                "value": "result-value"
                "version": 17,
                "count": 23,
                "variation": 1,
            },
            {
                "value": "another-value"
                "version": 17,
                "count": 3,
                "variation": 0,
            },
            {   //If the flag-key isn't a part of the flag store, the flag is unknown.
                //This could happen on the very first app launch if the client app asks for flags before the server responds
                //or if the client app requests a flag that doesn't exist.
                "unknown": true,
                "value": "default-value",
                "count": 1
            }
        ]
    */
    var dictionaryValue: [String: Any] {
        return [CodingKeys.defaultValue.rawValue: defaultValue ?? NSNull(),
                CodingKeys.counters.rawValue: flagValueCounters.dictionaryValues]
    }
}

private extension Optional where Wrapped == Int {
    ///Returns true if both values are nil, or if both values are the same
    func isEqualMatchingNil(to other: Int?) -> Bool {
        guard let myself = self, let otherSelf = other
        else {
            return self == nil && other == nil
        }
        return myself == otherSelf
    }
}

private extension FeatureFlag {
    func isEqualUsingFlagVersion(to other: FeatureFlag?) -> Bool {
        if !variation.isEqualMatchingNil(to: other?.variation) {
            return false
        }
        if flagVersion == nil && other?.flagVersion == nil {
            return version.isEqualMatchingNil(to: other?.version)   //compare the version since the flagVersion is missing in both flags
        } else {
            return flagVersion.isEqualMatchingNil(to: other?.flagVersion)
        }
    }
}

private extension Optional where Wrapped == FeatureFlag {
    func isEqualUsingFlagVersion(to other: FeatureFlag?) -> Bool {
        guard let featureFlag = self
        else {
            return false
        }
        return featureFlag.isEqualUsingFlagVersion(to: other)
    }
}

extension Array where Element == FlagValueCounter {
    func flagValueCounter(for featureFlag: FeatureFlag?) -> FlagValueCounter? {
        let selectedFlagValueCounters: [FlagValueCounter]
        if featureFlag == nil {
            selectedFlagValueCounters = self.filter { (flagValueCounter) in
                return flagValueCounter.isKnown == false
            }
        } else {
            selectedFlagValueCounters = self.filter { (flagValueCounter) in
                return flagValueCounter.featureFlag.isEqualUsingFlagVersion(to: featureFlag)
            }
        }
        guard selectedFlagValueCounters.count == 1
        else {
            if selectedFlagValueCounters.count > 1 {
                Log.debug(typeName(and: #function) + "found multiple flagValueCounters for featureFlag: \(String(describing: featureFlag))")
            }
            return nil
        }
        return selectedFlagValueCounters.first
    }

    var dictionaryValues: [[String: Any]] {
        return map { (flagValueCounter) in
            return flagValueCounter.dictionaryValue
        }
    }
}

extension Array: TypeIdentifying { }
