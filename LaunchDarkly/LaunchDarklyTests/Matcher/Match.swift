//
//  Match.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 10/4/17. +JMJ
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Nimble

/**
 Used by the `toMatch` matcher.

 This is the return type for the closure.
 */
public enum ToMatchResult {
    case matched
    case failed(reason: String)
}

/**
 A Nimble matcher that takes in a closure for validation.

 Return `.matched` when the validation succeeds.
 Return `.failed` with a failure reason when the validation fails.
 */
public func match() -> Predicate<() -> ToMatchResult> {
    return Predicate.define { actualExpression in
        let optActual = try actualExpression.evaluate()
        guard let actual = optActual
        else {
            return PredicateResult(status: .fail, message: .fail("expected a closure, got <nil>"))
        }

        switch actual() {
        case .matched:
            return PredicateResult(
                bool: true,
                message: .expectedCustomValueTo("match", "<matched>")
            )
        case .failed(let reason):
            return PredicateResult(
                bool: false,
                message: .expectedCustomValueTo("match", "<failed> because <\(reason)>")
            )
        }
    }
}
