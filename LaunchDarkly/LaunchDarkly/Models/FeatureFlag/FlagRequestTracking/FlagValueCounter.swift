//
//  FlagValueCounter.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 6/19/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation

final class FlagValueCounter {
    enum CodingKeys: String, CodingKey {
        case value, variation, version, unknown, count
    }

    var reportedValue: Any?
    let featureFlag: FeatureFlag?
    let isKnown: Bool
    var count: Int

    init(reportedValue: Any?, featureFlag: FeatureFlag?) {
        self.reportedValue = reportedValue
        self.featureFlag = featureFlag
        isKnown = featureFlag != nil
        count = 0
    }

    var dictionaryValue: [String: Any] {
        var counterDictionary = [String: Any]()
        counterDictionary[CodingKeys.value.rawValue] = reportedValue ?? NSNull()
        counterDictionary[CodingKeys.count.rawValue] = count
        if isKnown {
            counterDictionary[CodingKeys.variation.rawValue] = featureFlag?.variation
            //If the flagVersion exists, it is reported as the "version". If not, the version is reported using the "version" key.
            counterDictionary[CodingKeys.version.rawValue] = featureFlag?.flagVersion ?? featureFlag?.version
        } else {
            counterDictionary[CodingKeys.unknown.rawValue] = true
        }

        return counterDictionary
    }
}
