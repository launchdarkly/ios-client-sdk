//
//  KeyedValueCache.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 12/6/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol KeyedValueCaching {
    func set(_ value: Any?, forKey: String)
    //sourcery: DefaultReturnValue = nil
    func dictionary(forKey: String) -> [String: Any]?
    func removeObject(forKey: String)
}

extension UserDefaults: KeyedValueCaching { }
