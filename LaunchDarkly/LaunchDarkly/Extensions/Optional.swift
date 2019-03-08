//
//  Optional.swift
//  LaunchDarkly
//
//  Created by Mark Pokorny on 10/24/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

extension Optional where Wrapped: Collection {
    var isNilOrEmpty: Bool {
        guard case let .some(value) = self
        else {
            return true
        }
        return value.isEmpty
    }
}
