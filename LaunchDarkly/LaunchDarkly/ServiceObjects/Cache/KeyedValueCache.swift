//
//  KeyedValueCache.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

// sourcery: autoMockable
protocol KeyedValueCaching {
    func set(_ value: Any?, forKey: String)
    // sourcery: DefaultReturnValue = nil
    func dictionary(forKey: String) -> [String: Any]?
    func removeObject(forKey: String)
}

extension UserDefaults: KeyedValueCaching { }
