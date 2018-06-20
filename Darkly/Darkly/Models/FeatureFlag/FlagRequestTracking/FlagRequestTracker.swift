//
//  FlagRequestTracker.swift
//  Darkly
//
//  Created by Mark Pokorny on 6/20/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation

struct FlagRequestTracker {
    let startDate = Date()
    var flagCounters = [FlagCounter]()

    mutating func logRequest(flagKey: LDFlagKey, reportedValue: Any?, featureFlag: FeatureFlag?, defaultValue: Any?) {
        if flagCounters.flagCounter(for: flagKey) == nil {
            flagCounters.append(FlagCounter(flagKey: flagKey))
        }
        guard let flagCounter = flagCounters.flagCounter(for: flagKey) else { return }
        flagCounter.logRequest(reportedValue: reportedValue, featureFlag: featureFlag, defaultValue: defaultValue)
    }
}

extension Array where Element == FlagCounter {
    func flagCounter(for flagKey: LDFlagKey) -> FlagCounter? {
        let selectedCounters = filter { (flagCounter) in
            return flagCounter.flagKey == flagKey
        }
        guard selectedCounters.count == 1 else { return nil }
        return selectedCounters.first
    }
}
