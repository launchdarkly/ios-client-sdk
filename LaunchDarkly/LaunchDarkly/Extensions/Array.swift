//
//  Array.swift
//  LaunchDarkly
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation

extension Array {
    func isEqual(to other: [Any]) -> Bool {
        guard self.count == other.count
        else {
            return false
        }
        for index in 0..<self.count where !AnyComparer.isEqual(self[index], to: other[index]) {
            return false
        }
        return true
    }
}
