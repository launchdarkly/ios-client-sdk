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
#import "NSDate+ReferencedDate.h"
#import "NSNumber+LaunchDarkly.h"

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
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey]) {
            NSDictionary *flagConfigValueDictionary = [LDFlagConfigValue flagConfigJsonObjectFromFileNamed:fixtureFileName
                                                                                                   flagKey:flagKey
                                                                                      eventTrackingContext:eventTrackingContext][flagKey];
            LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary];

            //Core items
            XCTAssertEqualObjects(flagConfigValue.value, flagConfigValueDictionary[kLDFlagConfigValueKeyValue]);
            XCTAssertEqual(flagConfigValue.modelVersion, [flagConfigValueDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
            XCTAssertEqual(flagConfigValue.variation, [flagConfigValueDictionary[kLDFlagConfigValueKeyVariation] integerValue]);

            //Optional items
            XCTAssertEqualObjects(flagConfigValue.flagVersion, flagConfigValueDictionary[kLDFlagConfigValueKeyFlagVersion]);
            XCTAssertEqual(flagConfigValue.eventTrackingContext.trackEvents, eventTrackingContext.trackEvents);
            XCTAssertTrue([flagConfigValue.eventTrackingContext.debugEventsUntilDate isWithinTimeInterval:1.0 ofDate:eventTrackingContext.debugEventsUntilDate]);

            //omit value
            NSMutableDictionary *partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary];
            [partialFlagConfigValueDictionary removeObjectForKey:kLDFlagConfigValueKeyValue];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertEqualObjects(flagConfigValue.value, [NSNull null]);
            XCTAssertEqual(flagConfigValue.modelVersion, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
            XCTAssertEqual(flagConfigValue.variation, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVariation] integerValue]);

            //omit version
            partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary];
            [partialFlagConfigValueDictionary removeObjectForKey:kLDFlagConfigValueKeyVersion];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertEqualObjects(flagConfigValue.value, partialFlagConfigValueDictionary[kLDFlagConfigValueKeyValue]);
            XCTAssertEqual(flagConfigValue.modelVersion, kLDFlagConfigValueItemDoesNotExist);
            XCTAssertEqual(flagConfigValue.variation, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVariation] integerValue]);

            //null version
            partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary];
            partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVersion] = [NSNull null];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertEqualObjects(flagConfigValue.value, partialFlagConfigValueDictionary[kLDFlagConfigValueKeyValue]);
            XCTAssertEqual(flagConfigValue.modelVersion, kLDFlagConfigValueItemDoesNotExist);
            XCTAssertEqual(flagConfigValue.variation, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVariation] integerValue]);

            //omit variation
            partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary];
            [partialFlagConfigValueDictionary removeObjectForKey:kLDFlagConfigValueKeyVariation];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertEqualObjects(flagConfigValue.value, partialFlagConfigValueDictionary[kLDFlagConfigValueKeyValue]);
            XCTAssertEqual(flagConfigValue.modelVersion, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
            XCTAssertEqual(flagConfigValue.variation, kLDFlagConfigValueItemDoesNotExist);

            //null variation
            partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary];
            partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVariation] = [NSNull null];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertEqualObjects(flagConfigValue.value, partialFlagConfigValueDictionary[kLDFlagConfigValueKeyValue]);
            XCTAssertEqual(flagConfigValue.modelVersion, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
            XCTAssertEqual(flagConfigValue.variation, kLDFlagConfigValueItemDoesNotExist);

            //omit optional items
            partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary];
            [partialFlagConfigValueDictionary removeObjectForKey:kLDFlagConfigValueKeyFlagVersion];
            [partialFlagConfigValueDictionary removeObjectForKey:kLDEventTrackingContextKeyTrackEvents];
            [partialFlagConfigValueDictionary removeObjectForKey:kLDEventTrackingContextKeyDebugEventsUntilDate];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertNil(flagConfigValue.eventTrackingContext);
            XCTAssertNil(flagConfigValue.flagVersion);

            //null flag version
            partialFlagConfigValueDictionary = [NSMutableDictionary dictionaryWithDictionary:flagConfigValueDictionary];
            partialFlagConfigValueDictionary[kLDFlagConfigValueKeyFlagVersion] = [NSNull null];

            flagConfigValue = [LDFlagConfigValue flagConfigValueWithObject:[partialFlagConfigValueDictionary copy]];
            XCTAssertEqualObjects(flagConfigValue.value, partialFlagConfigValueDictionary[kLDFlagConfigValueKeyValue]);
            XCTAssertEqual(flagConfigValue.modelVersion, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVersion] integerValue]);
            XCTAssertEqual(flagConfigValue.variation, [partialFlagConfigValueDictionary[kLDFlagConfigValueKeyVariation] integerValue]);
            XCTAssertNil(flagConfigValue.flagVersion);
        }
    }
}

-(void)testInitializer_ObjectIsNil {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:nil];

    XCTAssertNil(subject);
}

-(void)testEncodeAndDecode {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true" flagKey:@"isABool" eventTrackingContext:eventTrackingContext];

    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:flagConfigValue];
    LDFlagConfigValue *restoredFlagConfigValue = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertEqualObjects(flagConfigValue, restoredFlagConfigValue);
    //Optional items
    XCTAssertEqualObjects(flagConfigValue.flagVersion, restoredFlagConfigValue.flagVersion);
    XCTAssertEqual(restoredFlagConfigValue.eventTrackingContext.trackEvents, eventTrackingContext.trackEvents);
    XCTAssertTrue([restoredFlagConfigValue.eventTrackingContext.debugEventsUntilDate isWithinTimeInterval:1.0 ofDate:eventTrackingContext.debugEventsUntilDate]);

    flagConfigValue.value = [NSNull null];
    flagConfigValue.modelVersion = kLDFlagConfigValueItemDoesNotExist;
    flagConfigValue.variation = kLDFlagConfigValueItemDoesNotExist;
    flagConfigValue.flagVersion = nil;
    flagConfigValue.eventTrackingContext = nil;

    archive = [NSKeyedArchiver archivedDataWithRootObject:flagConfigValue];
    restoredFlagConfigValue = [NSKeyedUnarchiver unarchiveObjectWithData:archive];

    XCTAssertTrue([flagConfigValue isEqual:restoredFlagConfigValue]);
    XCTAssertNil(flagConfigValue.eventTrackingContext);
    XCTAssertNil(flagConfigValue.flagVersion);
}

-(void)testDictionaryValue {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true"
                                                                                     flagKey:@"isABool"
                                                                        eventTrackingContext:eventTrackingContext];

    NSDictionary *flagDictionary = [flagConfigValue dictionaryValueUseFlagVersionForVersion:NO includeEventTrackingContext:YES];

    //Core items
    XCTAssertEqualObjects(flagDictionary[kLDFlagConfigValueKeyValue], flagConfigValue.value);
    XCTAssertEqual([flagDictionary[kLDFlagConfigValueKeyVersion] integerValue], flagConfigValue.modelVersion);
    XCTAssertEqual([flagDictionary[kLDFlagConfigValueKeyVariation] integerValue], flagConfigValue.variation);
    //Optional items
    XCTAssertEqualObjects(flagDictionary[kLDFlagConfigValueKeyFlagVersion], flagConfigValue.flagVersion);
    XCTAssertEqual([flagDictionary[kLDEventTrackingContextKeyTrackEvents] boolValue], eventTrackingContext.trackEvents);
    XCTAssertTrue([[NSDate dateFromMillisSince1970:[flagDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate] ldMillisecondValue]]
                   isWithinTimeInterval:1.0 ofDate:eventTrackingContext.debugEventsUntilDate]);

    flagDictionary = [flagConfigValue dictionaryValueUseFlagVersionForVersion:YES includeEventTrackingContext:NO];

    //Core items
    XCTAssertEqualObjects(flagDictionary[kLDFlagConfigValueKeyValue], flagConfigValue.value);
    XCTAssertEqualObjects(flagDictionary[kLDFlagConfigValueKeyVersion], flagConfigValue.flagVersion);
    XCTAssertEqual([flagDictionary[kLDFlagConfigValueKeyVariation] integerValue], flagConfigValue.variation);
    //Optional items
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyFlagVersion]);
    XCTAssertNil(flagDictionary[kLDEventTrackingContextKeyTrackEvents]);
    XCTAssertNil(flagDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);

    flagConfigValue.value = [NSNull null];
    flagConfigValue.variation = kLDFlagConfigValueItemDoesNotExist;
    flagConfigValue.modelVersion = kLDFlagConfigValueItemDoesNotExist;
    flagConfigValue.flagVersion = nil;
    flagConfigValue.eventTrackingContext = nil;

    flagDictionary = [flagConfigValue dictionaryValue];

    //Core items
    XCTAssertEqualObjects(flagConfigValue.value, [NSNull null]);
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyVariation]);
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyVersion]);
    //Optional items
    XCTAssertNil(flagDictionary[kLDFlagConfigValueKeyFlagVersion]);
    XCTAssertNil(flagDictionary[kLDEventTrackingContextKeyTrackEvents]);
    XCTAssertNil(flagDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);
}

-(void)testIsEqual_valuesAreTheSame {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey]) {
            NSDictionary *flagConfigValueDictionary = [NSJSONSerialization jsonObjectFromFileNamed:fixtureFileName];
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueWithObject:flagConfigValueDictionary[flagKey]];
            //Include optional items that differ in other to ensure equality only considers core items
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:fixtureFileName flagKey:flagKey eventTrackingContext:eventTrackingContext];
            other.flagVersion = @([other.flagVersion integerValue] + 1);

            XCTAssertTrue([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesDiffer_differentVariations {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey]) {
            //Include optional items that are the same in other to ensure equality only considers core items
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:fixtureFileName flagKey:flagKey eventTrackingContext:eventTrackingContext];
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:fixtureFileName flagKey:flagKey eventTrackingContext:eventTrackingContext];
            other.variation += 1;

            XCTAssertFalse([subject isEqual:other]);

            other.variation = kLDFlagConfigValueItemDoesNotExist;

            XCTAssertFalse([subject isEqual:other]);

            other.variation = subject.variation;
            subject.variation = kLDFlagConfigValueItemDoesNotExist;

            XCTAssertFalse([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesDiffer_differentVersions {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        for (NSString *fixtureFileName in [LDFlagConfigValue fixtureFileNamesForFlagKey:flagKey]) {
            //Include optional items that are the same in other to ensure equality only considers core items
            LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:fixtureFileName flagKey:flagKey eventTrackingContext:eventTrackingContext];
            LDFlagConfigValue *other = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:fixtureFileName flagKey:flagKey eventTrackingContext:eventTrackingContext];
            other.modelVersion += 1;

            XCTAssertFalse([subject isEqual:other]);

            other.modelVersion = kLDFlagConfigValueItemDoesNotExist;

            XCTAssertFalse([subject isEqual:other]);

            other.modelVersion = subject.modelVersion;
            subject.modelVersion = kLDFlagConfigValueItemDoesNotExist;

            XCTAssertFalse([subject isEqual:other]);
        }
    }
}

-(void)testIsEqual_valuesDiffer_differentObjects {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true" flagKey:@"isABool" eventTrackingContext:nil];

    XCTAssertFalse([subject isEqual:@"someString"]);
}

-(void)testIsEqual_valuesDiffer_otherIsNil {
    LDFlagConfigValue *subject = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true" flagKey:@"isABool" eventTrackingContext:nil];

    XCTAssertFalse([subject isEqual:nil]);
}

- (void)testHasPropertiesMatchingDictionary {
    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext stub];
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        id defaultFlagValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];

        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey eventTrackingContext:eventTrackingContext];
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
