//
//  FlagCollectionCache.swift
//  Darkly_iOS
//
//  Created by Mark Pokorny on 12/6/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol FlagCollectionCaching {
    //Responsibility: store & retrieve flag collection using KeyedValueStoring
    //controls the number of user flag sets stored in the flag collection
    //sourcery: DefaultReturnValue = [:]
    func retrieveFlags() -> [String: UserFlags]
    func storeFlags(_ flags: [String: UserFlags])
}

final class FlagCollectionCache: FlagCollectionCaching {
    struct Constants {
        public static let maxCachedValues = 5
    }

    private let keyStore: KeyedValueCaching
    let maxCachedValues: Int

    init(keyStore: KeyedValueCaching, maxCachedValues: Int = Constants.maxCachedValues) {
        self.keyStore = keyStore
        self.maxCachedValues = maxCachedValues
    }

    func retrieveFlags() -> [String: UserFlags] {
        return [:]
    }

    func storeFlags(_ flags: [String: UserFlags]) {

    }
}
