//
//  LDEvaluationDetail.swift
//  LaunchDarkly_iOS
//
//  Copyright © 2019 Catamorphic Co. All rights reserved.
//

import Foundation

/**
 An object returned by the SDK's `variationDetail` methods, combining the result of a flag evaluation with an
 explanation of how it is calculated.
 */
public final class LDEvaluationDetail<T> {
    /// The value of the flag for the current user.
    public internal(set) var value: T
    /// The index of the returned value within the flag's list of variations, or `nil` if the default was returned.
    public internal(set) var variationIndex: Int?
    /// A structure representing the main factor that influenced the resultant flag evaluation value.
    public internal(set) var reason: [String: Any]?

    internal init(value: T, variationIndex: Int?, reason: [String: Any]?) {
        self.value = value
        self.variationIndex = variationIndex
        self.reason = reason
    }
}
