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

            //omit value
            NSMutableDictionary *partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary[flagKey]];
            [partialFlagConfigValueDictionary removeObjectForKey:kLDFlagConfigValueKeyValue];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertEqualObjects(flagConfigValue.value, [NSNull null]);
            XCTAssertEqual(flagConfigValue.modelVersion, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
            XCTAssertEqual(flagConfigValue.variation, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVariation] integerValue]);

            //omit version
            partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary[flagKey]];
            [partialFlagConfigValueDictionary removeObjectForKey:kLDFlagConfigValueKeyVersion];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertEqualObjects(flagConfigValue.value, partialFlagConfigValueDictionary[kLDFlagConfigValueKeyValue]);
            XCTAssertEqual(flagConfigValue.modelVersion, kLDFlagConfigValueItemDoesNotExist);
            XCTAssertEqual(flagConfigValue.variation, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVariation] integerValue]);

            //omit variation
            partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary[flagKey]];
            [partialFlagConfigValueDictionary removeObjectForKey:kLDFlagConfigValueKeyVariation];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertEqualObjects(flagConfigValue.value, partialFlagConfigValueDictionary[kLDFlagConfigValueKeyValue]);
            XCTAssertEqual(flagConfigValue.modelVersion, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
            XCTAssertEqual(flagConfigValue.variation, kLDFlagConfigValueItemDoesNotExist);
        }
    }
}

-(void)testInitializer_ObjectIsNil {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:nil];

    XCTAssertNil(subject);
}

-(void)testEncodeAndDecode {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion" flagKey:@"isABool" eventTrackingContext:eventTrackingContext];

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:flagConfigValue];
    LDFlagConfigValue *restored = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([flagConfigValue isEqual:restored]);

    flagConfigValue.value = [NSNull null];
    flagConfigValue.modelVersion = kLDFlagConfigValueItemDoesNotExist;
    flagConfigValue.variation = kLDFlagConfigValueItemDoesNotExist;

    archive = [NSKeyedArchiver archivedDataWithRootObject:flagConfigValue];
    restored = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([flagConfigValue isEqual:restored]);
}

-(void)testDictionaryValue {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true-withVersion"
                                                                                     flagKey:@"isABool"
                                                                        eventTrackingContext:eventTrackingContext];

    NSDictionary *flagDictionary = [flagConfigValue dictionaryValue];

    XCTAssertEqualObjects(flagConfigValue.value, flagDictionary[kLDFlagConfigValueKeyValue]);
    XCTAssertTrue([flagDictionary[kLDFlagConfigValueKeyVersion] isKindOfClass:[NSNumber class]]);
    XCTAssertEqual(flagConfigValue.modelVersion, [flagDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
    XCTAssertEqual(flagConfigValue.variation, [flagDictionary[kLDFlagConfigValueKeyVariation] integerValue]);
    XCTAssertTrue([flagConfigValue.eventTrackingContext hasPropertiesMatchingDictionary:flagDictionary]);

    flagConfigValue.value = [NSNull null];
    flagConfigValue.variation = kLDFlagConfigValueItemDoesNotExist;
    flagConfigValue.modelVersion = kLDFlagConfigValueItemDoesNotExist;

    flagDictionary = [flagConfigValue dictionaryValue];

    XCTAssertEqualObjects(flagConfigValue.value, [NSNull null]);
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyVariation]);
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyVersion]);
}

-(void)testIsEqual_valuesAreTheSame {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey includeVersion:YES]) {
            NSDictionary *flagConfigValueDictionary = [NSJSONSerialization jsonObjectFromFileNamed:fixtureFileName];
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];

            XCTAssertTrue([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesDiffer_differentValues {
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
            other.modelVersion += 1;

            XCTAssertFalse([subject isEqual:other]);

            other = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            other.modelVersion = kLDFlagConfigValueItemDoesNotExist;

            XCTAssertFalse([subject isEqual:other]);

            other.modelVersion = subject.modelVersion;
            subject.modelVersion = kLDFlagConfigValueItemDoesNotExist;

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

- (void)testHasPropertiesMatchingDictionary {
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
            differingFlagConfigValue.modelVersion = flagConfigValue.modelVersion += 1;
            XCTAssertFalse([differingFlagConfigValue hasPropertiesMatchingDictionary:flagConfigValueDictionary]);

            differingFlagConfigDictionary = [NSMutableDictionary dictionaryWithDictionary:[flagConfigValue dictionaryValue]];
            [differingFlagConfigDictionary removeObjectForKey:kLDFlagConfigValueKeyVersion];
            XCTAssertFalse([flagConfigValue hasPropertiesMatchingDictionary:differingFlagConfigDictionary]);
        }
    }
}

@end
