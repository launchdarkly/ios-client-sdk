//
//  FeatureFlag.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

struct FeatureFlag {

    enum CodingKeys: String, CodingKey {
        case value, version
    }

    struct Constants {
        static let nilVersionPlaceholder = -1
    }
    
    let value: Any?
    let version: Int?

    init(value: Any?, version: Int?) {
        self.value = value is NSNull ? nil : value
        self.version = version
    }

    init?(dictionary: [String: Any]?) {
        guard let dictionary = dictionary else { return nil }
        let selectedKeys = dictionary.keys.filter { (key) in [CodingKeys.value.rawValue, CodingKeys.version.rawValue].contains(key) }
        if selectedKeys.contains(CodingKeys.value.rawValue) && selectedKeys.contains(CodingKeys.version.rawValue) {
            self.init(value: dictionary[CodingKeys.value.rawValue], version: dictionary[CodingKeys.version.rawValue] as? Int)
            return
        }
        guard selectedKeys.isEmpty else { return nil }
        self.init(value: dictionary, version: nil)
    }

    init?(object: Any?) {
        if let object = object as? [String: Any] {
            self.init(dictionary: object)
            return
        }
        if let object = object {
            self.init(value: object, version: nil)
            return
        }
        return nil
    }

    func dictionaryValue(exciseNil: Bool) -> [String: Any]? {
        if exciseNil && value == nil { return nil }
        var dict = [String: Any]()
        var nilExcisedValue = value
        if exciseNil, let dictionaryValue = value as? [LDFlagKey: Any] {
            nilExcisedValue = dictionaryValue.filter { (_, value) -> Bool in
                if value is NSNull { return false }
                return true
            }
        }
        dict[CodingKeys.value.rawValue] = nilExcisedValue ?? NSNull()
        dict[CodingKeys.version.rawValue] = version ?? (exciseNil ? Constants.nilVersionPlaceholder : NSNull())
        return dict
    }

    func isEqual(to other: FeatureFlag?) -> Bool {
        guard let other = other else { return false }
        if value == nil {
            if other.value != nil { return false }
        } else {
            if !AnyComparer.isEqual(value, to: other.value) { return false }
        }
        if version == nil {
            if other.version != nil { return false }
        } else {
            if version != other.version { return false }
        }
        return true
    }
}
