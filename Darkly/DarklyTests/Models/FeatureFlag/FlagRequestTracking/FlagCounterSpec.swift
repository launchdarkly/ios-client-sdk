//
//  FlagCounterSpec.swift
//  DarklyTests
//
//  Created by Mark Pokorny on 6/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import Darkly

final class FlagCounterSpec: QuickSpec {
    override func spec() {
        initSpec()
    }

    private func initSpec() {
        describe("init") {
            var flagCounter: FlagCounter!
            var defaultValue: Any?
            it("creates a flag counter") {
                DarklyServiceMock.FlagKeys.all.forEach { (flagKey) in
                    defaultValue = DarklyServiceMock.FlagValues.value(from: flagKey)

                    flagCounter = FlagCounter(flagKey: flagKey, defaultValue: defaultValue)

                    expect(flagCounter.flagKey) == flagKey
                    expect(AnyComparer.isEqual(flagCounter.defaultValue, to: defaultValue, considerNilAndNullEqual: true)).to(beTrue())
                    expect(flagCounter.flagValueCounters.isEmpty).to(beTrue())
                }
            }
        }
    }
}
