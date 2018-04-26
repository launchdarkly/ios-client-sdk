//
//  LDFlagConfigValueTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 1/31/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSJSONSerialization+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigValue+Testable.h"

@interface LDFlagConfigValueTest : XCTestCase

@end

@implementation LDFlagConfigValueTest

-(void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

-(void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testInitializer_boolValue_withVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool"];

    XCTAssertTrue([(NSNumber*)subject.value boolValue]);
    XCTAssertEqual(subject.version, 4);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_boolValue_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withoutVersion" flagKey:@"isABool"];

    XCTAssertTrue([(NSNumber*)subject.value boolValue]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_numberValue_withVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"numberConfigIsANumber-2-withVersion" flagKey:@"isANumber"];

    XCTAssertEqual([(NSNumber*)subject.value integerValue], 2);
    XCTAssertEqual(subject.version, 4);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_numberValue_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"numberConfigIsANumber-2-withoutVersion" flagKey:@"isANumber"];

    XCTAssertEqual([(NSNumber*)subject.value integerValue], 2);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_doubleValue_withVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"doubleConfigIsADouble-Pi-withVersion" flagKey:@"isADouble"];

    XCTAssertEqual([(NSNumber*)subject.value doubleValue], M_PI);
    XCTAssertEqual(subject.version, 3);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_doubleValue_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"doubleConfigIsADouble-Pi-withoutVersion" flagKey:@"isADouble"];

    XCTAssertEqual([(NSNumber*)subject.value doubleValue], M_PI);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_stringValue_withVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"stringConfigIsAString-someString-withVersion" flagKey:@"isAString"];

    XCTAssertTrue([subject.value isEqualToString:@"someString"]);
    XCTAssertEqual(subject.version, 3);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_stringValue_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"stringConfigIsAString-someString-withoutVersion" flagKey:@"isAString"];

    XCTAssertTrue([subject.value isEqualToString:@"someString"]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_arrayValue_withVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"arrayConfigIsAnArray-123-withVersion" flagKey:@"isAnArray"];

    NSArray *targetArray = @[@(1), @(2), @(3)];
    XCTAssertTrue([subject.value isEqualToArray:targetArray]);
    XCTAssertEqual(subject.version, 5);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_arrayValue_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"arrayConfigIsAnArray-123-withoutVersion" flagKey:@"isAnArray"];

    NSArray *targetArray = @[@(1), @(2), @(3)];
    XCTAssertTrue([subject.value isEqualToArray:targetArray]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_dictionaryValue_withVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key-withVersion" flagKey:@"isADictionary"];

    NSDictionary *targetDictionary = @{@"keyA": @(true), @"keyB": @[@(1), @(2), @(3)], @"keyC": @{@"keyD": @"someStringValue"}};
    XCTAssertTrue([subject.value isEqualToDictionary:targetDictionary]);
    XCTAssertEqual(subject.version, 4);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_dictionaryValue_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"dictionaryConfigIsADictionary-3Key-withoutVersion" flagKey:@"isADictionary"];

    NSDictionary *targetDictionary = @{@"keyA": @(true), @"keyB": @[@(1), @(2), @(3)], @"keyC": @{@"keyD": @"someStringValue"}};
    XCTAssertTrue([subject.value isEqualToDictionary:targetDictionary]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_ObjectIsNil {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:nil];

    XCTAssertNil(subject);
}

-(void)testInitializer_nullValue_withVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"nullConfigIsANull-null-withVersion" flagKey:@"isANull"];

    XCTAssertTrue([subject.value isEqual:[NSNull null]]);
    XCTAssertEqual(subject.version, 2);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testInitializer_nullValue_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"nullConfigIsANull-null-withoutVersion" flagKey:@"isANull"];

    XCTAssertTrue([subject.value isEqual:[NSNull null]]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
    XCTAssertEqual(subject.variation, kLDFlagConfigVariationDoesNotExist);
}

-(void)testEncodeAndDecode_withVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool"];

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:subject];
    LDFlagConfigValue *restored = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([subject isEqual:restored]);
}

-(void)testEncodeAndDecode_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withoutVersion" flagKey:@"isABool"];

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:subject];
    LDFlagConfigValue *restored = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([subject isEqual:restored]);
}

-(void)testDictionaryValue_withVersion {
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool"];

    NSDictionary *flagDictionary = [flagConfigValue dictionaryValue];

    XCTAssertEqual(flagConfigValue.value, flagDictionary[kLDFlagConfigValueKeyValue]);
    XCTAssertTrue([flagDictionary[kLDFlagConfigValueKeyVersion] isKindOfClass:[NSNumber class]]);
    XCTAssertEqual(flagConfigValue.version, [flagDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyVariation]);
}

-(void)testDictionaryValue_withoutVersion {
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withoutVersion" flagKey:@"isABool"];

    NSDictionary *flagDictionary = [flagConfigValue dictionaryValue];

    XCTAssertEqual(flagConfigValue.value, flagDictionary[kLDFlagConfigValueKeyValue]);
    XCTAssertTrue([flagDictionary[kLDFlagConfigValueKeyVersion] isKindOfClass:[NSNumber class]]);
    XCTAssertTrue(flagConfigValue.version == [(NSNumber*)flagDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyVariation]);
}

-(void)testIsEqual_valuesAreTheSame_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    XCTAssertTrue([subject isEqual:other]);
}

-(void)testIsEqual_valuesAreTheSame_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    XCTAssertTrue([subject isEqual:other]);
}

-(void)testIsEqual_valuesDiffer_differentValues_withVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool"];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-false-withVersion" flagKey:@"isABool"];

    XCTAssertFalse([subject isEqual:other]);
}

-(void)testIsEqual_valuesDiffer_differentValues_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withoutVersion" flagKey:@"isABool"];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-false-withoutVersion" flagKey:@"isABool"];

    XCTAssertFalse([subject isEqual:other]);
}

-(void)testIsEqual_valuesDiffer_differentVersions {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool"];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool"];
    other.version += 1;

    XCTAssertFalse([subject isEqual:other]);
}

-(void)testIsEqual_valuesDiffer_differentObjects {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool"];

    XCTAssertFalse([subject isEqual:@"someString"]);
}

-(void)testIsEqual_valuesDiffer_otherIsNil {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool"];

    XCTAssertFalse([subject isEqual:nil]);
}

@end
