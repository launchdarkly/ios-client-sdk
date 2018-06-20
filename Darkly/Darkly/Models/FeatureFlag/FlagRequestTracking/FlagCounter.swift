//
//  FlagCounter.swift
//  Darkly
//
//  Created by Mark Pokorny on 6/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

final class FlagCounter {
    let flagKey: String
    var defaultValue: Any? = nil
    var flagValueCounters = [FlagValueCounter]()

    init(flagKey: String) {
        self.flagKey = flagKey
    }

    func logRequest(reportedValue: Any?, featureFlag: FeatureFlag?, defaultValue: Any?) {
        self.defaultValue = defaultValue
        var flagValueCounter = flagValueCounters.flagValueCounter(for: featureFlag)
        if flagValueCounter == nil {
            let newFlagValueCounter = FlagValueCounter(reportedValue: reportedValue, featureFlag: featureFlag)
            flagValueCounters.append(newFlagValueCounter)
            flagValueCounter = newFlagValueCounter
        }
        flagValueCounter?.count += 1

        //TODO: Remove when implementing Summary Event, this is for testing the FlagRequestTracker
        Log.debug(typeName(and: #function) + "flagKey: \(flagKey), " + "reportedValue: \(String(describing: reportedValue)), " + "variation: \(String(describing: featureFlag?.variation)), "
            + "version: \(String(describing: featureFlag?.version)), " + "isKnown: \(String(describing: flagValueCounter?.isKnown)), " + "count: \(String(describing: flagValueCounter?.count)), "
            + "defaultValue: \(String(describing: defaultValue))")
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
        guard selectedFlagValueCounters.count == 1 else { return nil }
        return selectedFlagValueCounters.first
    }
}

extension FlagCounter: TypeIdentifying { }
