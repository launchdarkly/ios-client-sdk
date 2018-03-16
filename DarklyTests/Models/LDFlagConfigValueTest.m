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

extern NSString * const kLDFlagConfigJsonDictionaryKeyValue;
extern NSString * const kLDFlagConfigJsonDictionaryKeyVersion;

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
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    XCTAssertTrue([(NSNumber*)subject.value boolValue]);
    XCTAssertEqual(subject.version, 4);
}

-(void)testInitializer_boolValue_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    XCTAssertTrue([(NSNumber*)subject.value boolValue]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
}

-(void)testInitializer_numberValue_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"numberConfigIsANumber-2-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isANumber"]];

    XCTAssertEqual([(NSNumber*)subject.value integerValue], 2);
    XCTAssertEqual(subject.version, 4);
}

-(void)testInitializer_numberValue_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"numberConfigIsANumber-2-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isANumber"]];

    XCTAssertEqual([(NSNumber*)subject.value integerValue], 2);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
}

-(void)testInitializer_doubleValue_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"doubleConfigIsADouble-Pi-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isADouble"]];

    XCTAssertEqual([(NSNumber*)subject.value doubleValue], M_PI);
    XCTAssertEqual(subject.version, 3);
}

-(void)testInitializer_doubleValue_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"doubleConfigIsADouble-Pi-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isADouble"]];

    XCTAssertEqual([(NSNumber*)subject.value doubleValue], M_PI);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
}

-(void)testInitializer_stringValue_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"stringConfigIsAString-someString-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isAString"]];

    XCTAssertTrue([subject.value isEqualToString:@"someString"]);
    XCTAssertEqual(subject.version, 3);
}

-(void)testInitializer_stringValue_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"stringConfigIsAString-someString-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isAString"]];

    XCTAssertTrue([subject.value isEqualToString:@"someString"]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
}

-(void)testInitializer_arrayValue_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"arrayConfigIsAnArray-123-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isAnArray"]];

    NSArray *targetArray = @[@(1), @(2), @(3)];
    XCTAssertTrue([subject.value isEqualToArray:targetArray]);
    XCTAssertEqual(subject.version, 5);
}

-(void)testInitializer_arrayValue_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"arrayConfigIsAnArray-123-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isAnArray"]];

    NSArray *targetArray = @[@(1), @(2), @(3)];
    XCTAssertTrue([subject.value isEqualToArray:targetArray]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
}

-(void)testInitializer_dictionaryValue_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"dictionaryConfigIsADictionary-3Key-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isADictionary"]];

    NSDictionary *targetDictionary = @{@"keyA": @(true), @"keyB": @[@(1), @(2), @(3)], @"keyC": @{@"keyD": @"someStringValue"}};
    XCTAssertTrue([subject.value isEqualToDictionary:targetDictionary]);
    XCTAssertEqual(subject.version, 4);
}

-(void)testInitializer_dictionaryValue_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"dictionaryConfigIsADictionary-3Key-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isADictionary"]];

    NSDictionary *targetDictionary = @{@"keyA": @(true), @"keyB": @[@(1), @(2), @(3)], @"keyC": @{@"keyD": @"someStringValue"}};
    XCTAssertTrue([subject.value isEqualToDictionary:targetDictionary]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
}

-(void)testInitializer_ObjectIsNil {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:nil];

    XCTAssertNil(subject);
}

-(void)testInitializer_nullValue_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"nullConfigIsANull-null-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isANull"]];

    XCTAssertTrue([subject.value isEqual:[NSNull null]]);
    XCTAssertEqual(subject.version, 2);
}

-(void)testInitializer_nullValue_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"nullConfigIsANull-null-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isANull"]];

    XCTAssertTrue([subject.value isEqual:[NSNull null]]);
    XCTAssertEqual(subject.version, kLDFlagConfigVersionDoesNotExist);
}

-(void)testEncodeAndDecode_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:subject];
    LDFlagConfigValue *restored = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([subject isEqual:restored]);
}

-(void)testEncodeAndDecode_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:subject];
    LDFlagConfigValue *restored = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([subject isEqual:restored]);
}

-(void)testDictionaryValue_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    NSDictionary *flagDictionary = [flagConfigValue dictionaryValue];

    XCTAssertEqual(flagConfigValue.value, flagDictionary[kLDFlagConfigJsonDictionaryKeyValue]);
    XCTAssertTrue([flagDictionary[kLDFlagConfigJsonDictionaryKeyVersion] isKindOfClass:[NSNumber class]]);
    XCTAssertTrue(flagConfigValue.version == [(NSNumber*)flagDictionary[kLDFlagConfigJsonDictionaryKeyVersion] integerValue]);
}

-(void)testDictionaryValue_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withoutVersion"];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    NSDictionary *flagDictionary = [flagConfigValue dictionaryValue];

    XCTAssertEqual(flagConfigValue.value, flagDictionary[kLDFlagConfigJsonDictionaryKeyValue]);
    XCTAssertTrue([flagDictionary[kLDFlagConfigJsonDictionaryKeyVersion] isKindOfClass:[NSNumber class]]);
    XCTAssertTrue(flagConfigValue.version == [(NSNumber*)flagDictionary[kLDFlagConfigJsonDictionaryKeyVersion] integerValue]);
}

-(void)testEqual_valuesAreTheSame_withVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    XCTAssertTrue([subject isEqual:other]);
}

-(void)testEqual_valuesAreTheSame_withoutVersion {
    id flagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigStub[@"isABool"]];

    XCTAssertTrue([subject isEqual:other]);
}

-(void)testEqual_valuesDiffer_differentValues_withVersion {
    id subjectFlagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:subjectFlagConfigStub[@"isABool"]];

    id otherFlagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-false-withVersion"];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:otherFlagConfigStub[@"isABool"]];

    XCTAssertFalse([subject isEqual:other]);
}

-(void)testEqual_valuesDiffer_differentValues_withoutVersion {
    id subjectFlagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withoutVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:subjectFlagConfigStub[@"isABool"]];

    id otherFlagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-false-withoutVersion"];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:otherFlagConfigStub[@"isABool"]];

    XCTAssertFalse([subject isEqual:other]);
}

-(void)testEqual_valuesDiffer_differentVersions {
    id subjectFlagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:subjectFlagConfigStub[@"isABool"]];

    id otherFlagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:otherFlagConfigStub[@"isABool"]];
    other.version += 1;

    XCTAssertFalse([subject isEqual:other]);
}

-(void)testEqual_valuesDiffer_differentObjects {
    id subjectFlagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:subjectFlagConfigStub[@"isABool"]];

    XCTAssertFalse([subject isEqual:@"someString"]);
}

-(void)testEqual_valuesDiffer_otherIsNil {
    id subjectFlagConfigStub = [NSJSONSerialization jsonObjectFromFileNamed:@"boolConfigIsABool-true-withVersion"];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:subjectFlagConfigStub[@"isABool"]];

    XCTAssertFalse([subject isEqual:nil]);
}

@end
