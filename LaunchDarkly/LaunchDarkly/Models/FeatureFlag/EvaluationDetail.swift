//
//  EvaluationDetail.swift
//  LaunchDarkly_iOS
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

public final class EvaluationDetail<T> {
    public internal(set) var value: T
    public internal(set) var variationIndex: Int?
    public internal(set) var reason: [String: Any]?
    
    internal init(value: T, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex
        self.reason = reason
    }
}
