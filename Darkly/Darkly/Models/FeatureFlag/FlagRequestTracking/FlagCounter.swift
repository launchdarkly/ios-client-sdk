//
//  FlagCounter.swift
//  Darkly
//
//  Created by Mark Pokorny on 6/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
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

extension Array where Element == FlagValueCounter {
    func flagValueCounter(for featureFlag: FeatureFlag?) -> FlagValueCounter? {
        let selectedFlagValueCounters: [FlagValueCounter]
        if featureFlag == nil {
            selectedFlagValueCounters = self.filter { (flagValueCounter) in
                return flagValueCounter.isKnown == false
            }
        } else {
            selectedFlagValueCounters = self.filter { (flagValueCounter) in
                return flagValueCounter.featureFlag == featureFlag
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
