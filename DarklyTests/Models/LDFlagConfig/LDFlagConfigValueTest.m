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
#import "LDEventTrackingContext+Testable.h"

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

-(void)testInitAndConstructor {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:YES]) {

            NSDictionary *flagConfigValueDictionary = [LDFlagConfigValue flagConfigJsonObjectFromFileNamed:fixtureFileName
                                                                                                   flagKey:flagKey
                                                                                      eventTrackingContext:eventTrackingContext];
            LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];

            XCTAssertTrue([flagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary[flagKey]]);
            XCTAssertTrue([eventTrackingContext hasPropertiesMatchingDictionary:flagConfigValueDictionary[flagKey]]);
        }
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:NO]) {
            NSDictionary *flagConfigValueDictionary = [NSJSONSerialization jsonObjectFromFileNamed:fixtureFileName];
            LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];

            XCTAssertTrue([flagConfigValue.value isEqual:flagConfigValueDictionary[flagKey]]);
            XCTAssertEqual(flagConfigValue.variation, kLDFlagConfigValueItemDoesNotExist);
            XCTAssertEqual(flagConfigValue.version, kLDFlagConfigValueItemDoesNotExist);
            XCTAssertNil(flagConfigValue.eventTrackingContext);
        }
    }
}

-(void)testInitializer_ObjectIsNil {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:nil];

    XCTAssertNil(subject);
}

-(void)testEncodeAndDecode_withVersion {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool" eventTrackingContext:eventTrackingContext];

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:subject];
    LDFlagConfigValue *restored = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([subject isEqual:restored]);
}

-(void)testEncodeAndDecode_withoutVersion {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withoutVersion" flagKey:@"isABool" eventTrackingContext:nil];

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:subject];
    LDFlagConfigValue *restored = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([subject isEqual:restored]);
}

-(void)testDictionaryValue_withVersion {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion"
                                                                                     flagKey:@"isABool"
                                                                        eventTrackingContext:eventTrackingContext];

    NSDictionary *flagDictionary = [flagConfigValue dictionaryValue];

    XCTAssertEqual(flagConfigValue.value, flagDictionary[kLDFlagConfigValueKeyValue]);
    XCTAssertTrue([flagDictionary[kLDFlagConfigValueKeyVersion] isKindOfClass:[NSNumber class]]);
    XCTAssertEqual(flagConfigValue.version, [flagDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
    XCTAssertEqual(flagConfigValue.variation, [flagDictionary[kLDFlagConfigValueKeyVariation] integerValue]);
    XCTAssertTrue([flagConfigValue.eventTrackingContext hasPropertiesMatchingDictionary:flagDictionary]);
}

-(void)testDictionaryValue_withoutVersion {
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withoutVersion" flagKey:@"isABool" eventTrackingContext:nil];

    NSDictionary *flagDictionary = [flagConfigValue dictionaryValue];

    XCTAssertEqualObjects(flagConfigValue.value, flagDictionary[kLDFlagConfigValueKeyValue]);
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyVersion]);
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyVariation]);
    XCTAssertNil(flagDictionary[kLDEventTrackingContextKeyTrackEvents]);
    XCTAssertNil(flagDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);
}

-(void)testIsEqual_valuesAreTheSame_withVersion {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:YES]) {
            NSDictionary *flagConfigValueDictionary = [NSJSONSerialization jsonObjectFromFileNamed:fixtureFileName];
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];

            XCTAssertTrue([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesAreTheSame_withoutVersion {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:NO]) {
            NSDictionary *flagConfigValueDictionary = [NSJSONSerialization jsonObjectFromFileNamed:fixtureFileName];
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];

            XCTAssertTrue([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesDiffer_differentValues_withVersion {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        if ([flagKey isEqualToString:kLDFlagKeyIsANull]) { continue; }  //There are no alternate values for [NSNull null]
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:YES]) {
            NSDictionary *flagConfigValueDictionary = [NSJSONSerialization jsonObjectFromFileNamed:fixtureFileName];
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            other.value = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
            if ([flagKey isEqualToString:kLDFlagKeyIsABool]) {
                other.value = @(![subject.value boolValue]);
            }

            XCTAssertFalse([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesDiffer_differentValues_withoutVersion {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        if ([flagKey isEqualToString:kLDFlagKeyIsANull]) { continue; }  //There are no alternate values for [NSNull null]
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:NO]) {
            NSDictionary *flagConfigValueDictionary = [NSJSONSerialization jsonObjectFromFileNamed:fixtureFileName];
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            other.value = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
            if ([flagKey isEqualToString:kLDFlagKeyIsABool]) {
                other.value = @(![subject.value boolValue]);
            }

            XCTAssertFalse([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesDiffer_differentVariations {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:YES]) {
            NSDictionary *flagConfigValueDictionary = [NSJSONSerialization jsonObjectFromFileNamed:fixtureFileName];
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            other.variation += 1;

            XCTAssertFalse([subject isEqual:other]);

            other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            other.variation = kLDFlagConfigValueItemDoesNotExist;

            XCTAssertFalse([subject isEqual:other]);

            other.variation = subject.variation;
            subject.variation = kLDFlagConfigValueItemDoesNotExist;

            XCTAssertFalse([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesDiffer_differentVersions {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:YES]) {
            NSDictionary *flagConfigValueDictionary = [NSJSONSerialization jsonObjectFromFileNamed:fixtureFileName];
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            other.version += 1;

            XCTAssertFalse([subject isEqual:other]);

            other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            other.version = kLDFlagConfigValueItemDoesNotExist;

            XCTAssertFalse([subject isEqual:other]);

            other.version = subject.version;
            subject.version = kLDFlagConfigValueItemDoesNotExist;

            XCTAssertFalse([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesDiffer_differentObjects {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool" eventTrackingContext:nil];

    XCTAssertFalse([subject isEqual:@"someString"]);
}

-(void)testIsEqual_valuesDiffer_otherIsNil {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool" eventTrackingContext:nil];

    XCTAssertFalse([subject isEqual:nil]);
}

- (void)testHasPropertiesMatchingDictionary_withVersions {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];

        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey withVersions:YES eventTrackingContext:eventTrackingContext];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            //matching dictionary
            NSDictionary *flagConfigValueDictionary = [flagConfigValue dictionaryValue];

            XCTAssertTrue([flagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary]);
            XCTAssertNotNil(flagConfigValueDictionary[kLDFlagConfigValueKeyVersion]);
            XCTAssertNotNil(flagConfigValueDictionary[kLDFlagConfigValueKeyVariation]);
            XCTAssertTrue([flagConfigValue.eventTrackingContext hasPropertiesMatchingDictionary:flagConfigValueDictionary]);

            //mismatched dictionary
            LDFlagConfigValue *differingFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary];
            if (![flagKey isEqualToString:kLDFlagKeyIsANull]) { //There's no alternate value to supply for null values
                differingFlagConfigValue.value = defaultFlagValue;
                if ([flagKey isEqualToString:kLDFlagKeyIsABool]) {  //Since there are only YES/NO, make it different by taking the complement
                    differingFlagConfigValue.value = @(![flagConfigValue.value boolValue]);
                }
                XCTAssertFalse([differingFlagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary]);
            }

            differingFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary];
            differingFlagConfigValue.variation = flagConfigValue.variation += 1;
            XCTAssertFalse([differingFlagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary]);

            NSMutableDictionary *differingFlagConfigDictionary = [NSMutableDictionary dictionaryWithDictionary:[flagConfigValue dictionaryValue]];
            [differingFlagConfigDictionary removeObjectForKey:kLDFlagConfigValueKeyVariation];
            XCTAssertFalse([flagConfigValue hasPropertiesMatchingDictionary:differingFlagConfigDictionary]);

            differingFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary];
            differingFlagConfigValue.version = flagConfigValue.version += 1;
            XCTAssertFalse([differingFlagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary]);

            differingFlagConfigDictionary = [NSMutableDictionary dictionaryWithDictionary:[flagConfigValue dictionaryValue]];
            [differingFlagConfigDictionary removeObjectForKey:kLDFlagConfigValueKeyVersion];
            XCTAssertFalse([flagConfigValue hasPropertiesMatchingDictionary:differingFlagConfigDictionary]);
        }
    }
}

- (void)testHasPropertiesMatchingDictionary_withoutVersions {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey withVersions:NO eventTrackingContext:nil];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            NSDictionary *flagConfigValueDictionary = [flagConfigValue dictionaryValue];

            XCTAssertTrue([flagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary]);
            XCTAssertNil(flagConfigValueDictionary[kLDFlagConfigValueKeyVersion]);
            XCTAssertNil(flagConfigValueDictionary[kLDFlagConfigValueKeyVariation]);
            XCTAssertNil(flagConfigValueDictionary[kLDEventTrackingContextKeyTrackEvents]);
            XCTAssertNil(flagConfigValueDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);

            LDFlagConfigValue *differingFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary];
            if (![flagKey isEqualToString:kLDFlagKeyIsANull]) {
                differingFlagConfigValue.value = defaultFlagValue;
                if ([flagKey isEqualToString:kLDFlagKeyIsABool]) {
                    differingFlagConfigValue.value = @(![flagConfigValue.value boolValue]);
                }
                XCTAssertFalse([differingFlagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary]);
            }

            differingFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary];
            differingFlagConfigValue.version = flagConfigValue.version += 1;
            XCTAssertFalse([differingFlagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary]);

            differingFlagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary];
            differingFlagConfigValue.variation = flagConfigValue.variation += 1;
            XCTAssertFalse([differingFlagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary]);
        }
    }
}

@end
