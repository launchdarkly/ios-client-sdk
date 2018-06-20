//
//  FlagRequestTracker.swift
//  Darkly
//
//  Created by Mark Pokorny on 6/20/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

struct FlagRequestTracker {
    enum CodingKeys: String, CodingKey {
        case startDate, features
    }

    let startDate = Date()
    var flagCounters = [LDFlagKey: FlagCounter]()

    mutating func logRequest(flagKey: LDFlagKey, reportedValue: Any?, featureFlag: FeatureFlag?, defaultValue: Any?) {
        if flagCounters[flagKey] == nil {
            flagCounters[flagKey] = FlagCounter()
        }
        guard let flagCounter = flagCounters[flagKey] else { return }
        flagCounter.logRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)

        //TODO: Remove when implementing Summary Event, this is for testing the FlagRequestTracker
        let flagValueCounter = flagCounter.flagValueCounters.flagValueCounter(for: featureFlag)
        Log.debug(typeName(and: #function) + "\n\tflagKey: \(flagKey)" + "\n\treportedValue: \(String(describing: reportedValue)), " + "\n\tvariation: \(String(describing: featureFlag?.variation)), "
            + "\n\tversion: \(String(describing: featureFlag?.version)), " + "\n\tisKnown: \(String(describing: flagValueCounter?.isKnown)), "
            + "\n\tcount: \(String(describing: flagValueCounter?.count)), " + "\n\tdefaultValue: \(String(describing: defaultValue))\n")

    }

    var dictionaryValue: [String: Any] {
        return [CodingKeys.startDate.rawValue: startDate.millisSince1970,
                CodingKeys.features.rawValue: flagCounters.dictionaryValues]
    }
}

extension FlagRequestTracker: TypeIdentifying { }

extension Dictionary where Key == String, Value == FlagCounter {
    var dictionaryValues: [LDFlagKey: Any] {
        return mapValues { (flagCounter) in return flagCounter.dictionaryValue }
    }
}
