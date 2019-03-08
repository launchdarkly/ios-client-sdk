//
//  ObjcLDFlagValueSourceSpec.swift
//  LaunchDarklyTests
//
//  Created by Mark Pokorny on 12/13/18. +JMJ
//  Copyright © 2018 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class ObjcLDFlagValueSourceSpec: QuickSpec {

    struct TestContext {

    }

    override func spec() {
        initSpec()
        rawValueSpec()
        stringValueSpec()
        isEqualSpec()
    }

    private func initSpec() {
        initWithSourceAndTypeMismatchSpec()
        initWithRawValueSpec()
    }

    private func initWithSourceAndTypeMismatchSpec() {
        describe("initWithSourceAndTypeMismatch") {
            var objcFlagValueSource: ObjcLDFlagValueSource!
            ObjcLDFlagValueSource.allCases.forEach { (typeMismatch: Bool, flagValueSource: LDFlagValueSource) in
                context("source exists") {
                    beforeEach {
                        objcFlagValueSource = ObjcLDFlagValueSource(flagValueSource, typeMismatch: typeMismatch)
                    }
                    it ("creates a wrapped LDFlagValueSource that equals \(flagValueSource) and typeMismatch \(typeMismatch)") {
                        expect(objcFlagValueSource.typeMismatch) == typeMismatch
                        expect(objcFlagValueSource.flagValueSource).toNot(beNil())
                        guard let wrappedSource = objcFlagValueSource.flagValueSource
                        else {
                            return
                        }
                        expect(wrappedSource) == flagValueSource
                    }
                }
            }
            [false, true].forEach { (typeMismatch) in
                context("source does not exist") {
                    beforeEach {
                        objcFlagValueSource = ObjcLDFlagValueSource(nil, typeMismatch: typeMismatch)
                    }
                    it ("creates a wrapped LDFlagValueSource that is nil and typeMismatch \(typeMismatch)") {
                        expect(objcFlagValueSource.typeMismatch) == typeMismatch
                        expect(objcFlagValueSource.flagValueSource).to(beNil())
                    }
                }
            }
        }
    }

    private func initWithRawValueSpec() {
        describe("initWithRawValue") {
            var objcFlagValueSource: ObjcLDFlagValueSource?
            for rawValue in ObjcLDFlagValueSource.nilSource...ObjcLDFlagValueSource.typeMismatch {
                context("valid raw value = \(rawValue)") {
                    beforeEach {
                        objcFlagValueSource = ObjcLDFlagValueSource(rawValue: rawValue)
                    }
                    it("creates a wrapped LDFlagValueSource that matches \(rawValue)") {
                        expect(objcFlagValueSource).toNot(beNil())
                        guard let objcFlagValueSource = objcFlagValueSource
                        else {
                            return
                        }
                        expect(objcFlagValueSource.typeMismatch) == (rawValue == ObjcLDFlagValueSource.typeMismatch)
                        if rawValue == ObjcLDFlagValueSource.nilSource || rawValue == ObjcLDFlagValueSource.typeMismatch {
                            expect(objcFlagValueSource.flagValueSource).to(beNil())
                        } else {
                            expect(objcFlagValueSource.flagValueSource).toNot(beNil())
                            guard let wrappedSource = objcFlagValueSource.flagValueSource
                            else {
                                return
                            }
                            expect(wrappedSource) == LDFlagValueSource(intValue: rawValue)!
                        }
                    }
                }
            }
            [ObjcLDFlagValueSource.nilSource - 1, ObjcLDFlagValueSource.typeMismatch + 1].forEach { (rawValue) in
                context("invalid raw value = \(rawValue)") {
                    beforeEach {
                        objcFlagValueSource = ObjcLDFlagValueSource(rawValue: rawValue)
                    }
                    it("does not create a wrapped LDFlagValueSource") {
                        expect(objcFlagValueSource).to(beNil())
                    }
                }
            }
        }
    }

    private func rawValueSpec() {
        describe("rawValue") {
            var objcFlagValueSource: ObjcLDFlagValueSource!
            var wrappedRawValue: Int!
            ObjcLDFlagValueSource.allCases.forEach { (typeMismatch: Bool, flagValueSource: LDFlagValueSource) in
                context("source exists") {
                    beforeEach {
                        objcFlagValueSource = ObjcLDFlagValueSource(flagValueSource, typeMismatch: typeMismatch)

                        wrappedRawValue = objcFlagValueSource.rawValue
                    }
                    it ("reports a wrapped raw value that matches \(flagValueSource) and typeMismatch \(typeMismatch)") {
                        if typeMismatch {
                            expect(wrappedRawValue) == ObjcLDFlagValueSource.typeMismatch
                        } else {
                            expect(wrappedRawValue) == flagValueSource.intRawValue
                        }
                    }
                }
            }
            [false, true].forEach { (typeMismatch) in
                context("source does not exist") {
                    beforeEach {
                        objcFlagValueSource = ObjcLDFlagValueSource(nil, typeMismatch: typeMismatch)

                        wrappedRawValue = objcFlagValueSource.rawValue
                    }
                    it ("reports a wrapped raw value that matches nil and typeMismatch \(typeMismatch)") {
                        if typeMismatch {
                            expect(wrappedRawValue) == ObjcLDFlagValueSource.typeMismatch
                        } else {
                            expect(wrappedRawValue) == ObjcLDFlagValueSource.nilSource
                        }
                    }
                }
            }
        }
    }

    private func stringValueSpec() {
        describe("stringValue") {
            var objcFlagValueSource: ObjcLDFlagValueSource!
            var wrappedStringValue: String!
            ObjcLDFlagValueSource.allCases.forEach { (typeMismatch: Bool, flagValueSource: LDFlagValueSource) in
                context("source exists") {
                    beforeEach {
                        objcFlagValueSource = ObjcLDFlagValueSource(flagValueSource, typeMismatch: typeMismatch)

                        wrappedStringValue = objcFlagValueSource.stringValue
                    }
                    it ("reports a wrapped raw value that matches \(flagValueSource) and typeMismatch \(typeMismatch)") {
                        if typeMismatch {
                            expect(wrappedStringValue) == ObjcLDFlagValueSource.StringConstants.typeMismatch
                        } else {
                            expect(wrappedStringValue) == "\(flagValueSource)"
                        }
                    }
                }
            }
            [false, true].forEach { (typeMismatch) in
                context("source does not exist") {
                    beforeEach {
                        objcFlagValueSource = ObjcLDFlagValueSource(nil, typeMismatch: typeMismatch)

                        wrappedStringValue = objcFlagValueSource.stringValue
                    }
                    it ("reports a wrapped raw value that matches nil and typeMismatch \(typeMismatch)") {
                        if typeMismatch {
                            expect(wrappedStringValue) == ObjcLDFlagValueSource.StringConstants.typeMismatch
                        } else {
                            expect(wrappedStringValue) == ObjcLDFlagValueSource.StringConstants.nilSource
                        }
                    }
                }
            }
        }
    }

    private func isEqualSpec() {
        isEqualToObjectSpec()
        isEqualToConstantSpec()
    }

    private func isEqualToObjectSpec() {
        describe("isEqualToObject") {
            var receiverSource: ObjcLDFlagValueSource!
            var otherSource: ObjcLDFlagValueSource!
            var result: Bool!
            context("sources exist") {
                LDFlagValueSource.allCases.forEach { (receiver) in
                    context("no types mismatch") {
                        context("sources match") {
                            beforeEach {
                                receiverSource = ObjcLDFlagValueSource(receiver, typeMismatch: false)
                                otherSource = ObjcLDFlagValueSource(receiver, typeMismatch: false)

                                result = receiverSource.isEqual(toObject: otherSource)
                            }
                            it("reports true for source \(receiver)") {
                                expect(result) == true
                            }
                        }
                        LDFlagValueSource.allCases.forEach { (other) in
                            guard receiver != other
                            else {
                                return
                            }
                            context("sources do not match") {
                                beforeEach {
                                    receiverSource = ObjcLDFlagValueSource(receiver, typeMismatch: false)
                                    otherSource = ObjcLDFlagValueSource(other, typeMismatch: false)

                                    result = receiverSource.isEqual(toObject: otherSource)
                                }
                                it("reports false for receiver source \(receiver) other source \(other)") {
                                    expect(result) == false
                                }
                            }
                        }
                    }
                    context("receiver type mismatch") {
                        LDFlagValueSource.allCases.forEach { (other) in
                            context("other type matches") {
                                beforeEach {
                                    receiverSource = ObjcLDFlagValueSource(receiver, typeMismatch: true)
                                    otherSource = ObjcLDFlagValueSource(other, typeMismatch: false)

                                    result = receiverSource.isEqual(toObject: otherSource)
                                }
                                it("reports false for receiver source \(receiver) other source \(other)") {
                                    expect(result) == false
                                }
                            }
                            context("other type mismatches") {
                                beforeEach {
                                    receiverSource = ObjcLDFlagValueSource(receiver, typeMismatch: true)
                                    otherSource = ObjcLDFlagValueSource(other, typeMismatch: true)

                                    result = receiverSource.isEqual(toObject: otherSource)
                                }
                                it("reports true for receiver source \(receiver) other source \(other)") {
                                    expect(result) == true
                                }
                            }
                        }
                    }
                    context("other type mismatch") {
                        LDFlagValueSource.allCases.forEach { (other) in
                            context("receiver type matches") {
                                beforeEach {
                                    receiverSource = ObjcLDFlagValueSource(receiver, typeMismatch: false)
                                    otherSource = ObjcLDFlagValueSource(other, typeMismatch: true)

                                    result = receiverSource.isEqual(toObject: otherSource)
                                }
                                it("reports false for receiver source \(receiver) other source \(other)") {
                                    expect(result) == false
                                }
                            }
                        }
                    }
                    context("other source does not exist") {
                        beforeEach {
                            receiverSource = ObjcLDFlagValueSource(receiver, typeMismatch: false)
                            otherSource = ObjcLDFlagValueSource(nil, typeMismatch: false)

                            result = receiverSource.isEqual(toObject: otherSource)
                        }
                        it("reports false for receiver source \(receiver)") {
                            expect(result) == false
                        }
                    }
                }
            }
            context("receiver source does not exist") {
                LDFlagValueSource.allCases.forEach { (other) in
                    context("other source exists") {
                        context("with type mismatch") {
                            beforeEach {
                                receiverSource = ObjcLDFlagValueSource(nil, typeMismatch: false)
                                otherSource = ObjcLDFlagValueSource(other, typeMismatch: true)

                                result = receiverSource.isEqual(toObject: otherSource)
                            }
                            it("reports false for receiver source nil other source \(other)") {
                                expect(result) == false
                            }
                        }
                        context("with no type mismatch") {
                            beforeEach {
                                receiverSource = ObjcLDFlagValueSource(nil, typeMismatch: false)
                                otherSource = ObjcLDFlagValueSource(other, typeMismatch: false)

                                result = receiverSource.isEqual(toObject: otherSource)
                            }
                            it("reports false for receiver source nil other source \(other)") {
                                expect(result) == false
                            }
                        }
                    }
                }
                context("other source does not exist") {
                    context("with no type mismatch") {
                        beforeEach {
                            receiverSource = ObjcLDFlagValueSource(nil, typeMismatch: false)
                            otherSource = ObjcLDFlagValueSource(nil, typeMismatch: false)

                            result = receiverSource.isEqual(toObject: otherSource)
                        }
                        it("reports true") {
                            expect(result) == true
                        }
                    }
                    context("with receiver type mismatch") {
                        beforeEach {
                            receiverSource = ObjcLDFlagValueSource(nil, typeMismatch: true)
                            otherSource = ObjcLDFlagValueSource(nil, typeMismatch: false)

                            result = receiverSource.isEqual(toObject: otherSource)
                        }
                        it("reports false") {
                            expect(result) == false
                        }
                    }
                    context("with other type mismatch") {
                        beforeEach {
                            receiverSource = ObjcLDFlagValueSource(nil, typeMismatch: false)
                            otherSource = ObjcLDFlagValueSource(nil, typeMismatch: true)

                            result = receiverSource.isEqual(toObject: otherSource)
                        }
                        it("reports false") {
                            expect(result) == false
                        }
                    }
                    context("with both type mismatches") {
                        beforeEach {
                            receiverSource = ObjcLDFlagValueSource(nil, typeMismatch: true)
                            otherSource = ObjcLDFlagValueSource(nil, typeMismatch: true)

                            result = receiverSource.isEqual(toObject: otherSource)
                        }
                        it("reports true") {
                            expect(result) == true
                        }
                    }
                }
            }
            context("other object is not an ObjcLDFlagValueSource") {
                beforeEach {
                    receiverSource = ObjcLDFlagValueSource(.server, typeMismatch: false)

                    result = receiverSource.isEqual(toObject: NSObject())
                }
                it("reports false") {
                    expect(result) == false
                }
            }
            context("other object is missing") {
                beforeEach {
                    receiverSource = ObjcLDFlagValueSource(.server, typeMismatch: false)

                    result = receiverSource.isEqual(toObject: nil)
                }
                it("reports false") {
                    expect(result) == false
                }
            }
        }
    }

    private func isEqualToConstantSpec() {
        describe("isEqualToConstant") {
            var objcFlagValueSource: ObjcLDFlagValueSource!
            var rawValue: Int!
            var expectedResult: Bool!
            var result: Bool!
            ObjcLDFlagValueSource.allCases.forEach { (typeMismatch, flagValueSource) in
                context("source exists") {
                    ObjcLDFlagValueSource.allConstants.forEach { (constantValue) in
                        context("constant in bounds") {
                            beforeEach {
                                objcFlagValueSource = ObjcLDFlagValueSource(flagValueSource, typeMismatch: typeMismatch)
                                rawValue = objcFlagValueSource.rawValue
                                expectedResult = (rawValue == constantValue)

                                result = objcFlagValueSource.isEqual(toConstant: constantValue)
                            }
                            it("reports expected result for source \(flagValueSource), mismatch \(typeMismatch) and \(constantValue)") {
                                expect(result) == expectedResult
                            }
                        }
                    }
                    [ObjcLDFlagValueSource.nilSource - 1, ObjcLDFlagValueSource.typeMismatch + 1].forEach { (constantValue) in
                        context("constant out of bounds") {
                            beforeEach {
                                objcFlagValueSource = ObjcLDFlagValueSource(flagValueSource, typeMismatch: typeMismatch)
                                rawValue = objcFlagValueSource.rawValue

                                result = objcFlagValueSource.isEqual(toConstant: constantValue)
                            }
                            it("reports false for source \(flagValueSource), mismatch \(typeMismatch) and \(constantValue)") {
                                expect(result) == false
                            }
                        }
                    }
                }
            }
            context("source does not exist") {
                ObjcLDFlagValueSource.allConstants.forEach { (constantValue) in
                    context("constant in bounds") {
                        context("type mismatches") {
                            beforeEach {
                                objcFlagValueSource = ObjcLDFlagValueSource(nil, typeMismatch: true)
                                rawValue = objcFlagValueSource.rawValue
                                expectedResult = (rawValue == constantValue)

                                result = objcFlagValueSource.isEqual(toConstant: constantValue)
                            }
                            it("reports expected result for source nil, mismatch true and \(constantValue)") {
                                expect(result) == expectedResult
                            }
                        }
                        context("type does not mismatch") {
                            beforeEach {
                                objcFlagValueSource = ObjcLDFlagValueSource(nil, typeMismatch: false)
                                rawValue = objcFlagValueSource.rawValue
                                expectedResult = (rawValue == constantValue)

                                result = objcFlagValueSource.isEqual(toConstant: constantValue)
                            }
                            it("reports expected result for source nil, mismatch false and \(constantValue)") {
                                expect(result) == expectedResult
                            }
                        }
                    }
                }
                [ObjcLDFlagValueSource.nilSource - 1, ObjcLDFlagValueSource.typeMismatch + 1].forEach { (constantValue) in
                    context("constant out of bounds") {
                        context("type mismatches") {
                            beforeEach {
                                objcFlagValueSource = ObjcLDFlagValueSource(nil, typeMismatch: true)
                                rawValue = objcFlagValueSource.rawValue

                                result = objcFlagValueSource.isEqual(toConstant: constantValue)
                            }
                            it("reports false for source nil, mismatch true and \(constantValue)") {
                                expect(result) == false
                            }
                        }
                        context("type does not mismatch") {
                            beforeEach {
                                objcFlagValueSource = ObjcLDFlagValueSource(nil, typeMismatch: false)
                                rawValue = objcFlagValueSource.rawValue
                                expectedResult = (rawValue == constantValue)

                                result = objcFlagValueSource.isEqual(toConstant: constantValue)
                            }
                            it("reports false for source nil, mismatch false and \(constantValue)") {
                                expect(result) == false
                            }
                        }
                    }
                }
            }
        }
    }
}

extension ObjcLDFlagValueSource {
    class var allCases: [(typeMismatch: Bool, flagValueSource: LDFlagValueSource)] {
        var cases = [(typeMismatch: Bool, flagValueSource: LDFlagValueSource)]()
        [false, true].forEach { (typeMismatch) in
            LDFlagValueSource.allCases.forEach { (flagValueSource) in
                cases.append((typeMismatch, flagValueSource))
            }
        }

        return cases
    }

    class var allConstants: [Int] {
        return Array(ObjcLDFlagValueSource.nilSource...ObjcLDFlagValueSource.typeMismatch)
    }
}
