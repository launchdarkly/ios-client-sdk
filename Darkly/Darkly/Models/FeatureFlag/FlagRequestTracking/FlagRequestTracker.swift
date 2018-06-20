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
            flagCounters[flagKey] = FlagCounter(flagKey: flagKey)
        }
        guard let flagCounter = flagCounters[flagKey] else { return }
        flagCounter.logRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
    }

    var dictionaryValue: [String: Any] {
        return [CodingKeys.startDate.rawValue: startDate.millisSince1970,
                CodingKeys.features.rawValue: flagCounters.dictionaryValues]
    }
}

extension Dictionary where Key == String, Value == FlagCounter {
    var dictionaryValues: [LDFlagKey: Any] {
        return mapValues { (flagCounter) in return flagCounter.dictionaryValue }
    }
}
