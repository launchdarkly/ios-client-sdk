//
//  LDFlagCounterTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagCounter.h"
#import "LDFlagCounter+Testable.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigValue+Testable.h"

extern NSString * const kLDFlagKeyIsABool;
extern NSString * const kLDFlagKeyIsANumber;
extern NSString * const kLDFlagKeyIsADouble;
extern NSString * const kLDFlagKeyIsAString;
extern NSString * const kLDFlagKeyIsAnArray;
extern NSString * const kLDFlagKeyIsADictionary;
extern NSString * const kLDFlagKeyIsANull;

@interface LDFlagCounterTest : XCTestCase
@end

@implementation LDFlagCounterTest

-(void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

-(void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testInitAndCounterWithFlagKey {
    NSDictionary<NSString*, LDFlagConfigValue*> *flagConfigDictionary = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-excludeNulls-withVersions"].featuresJsonDictionary;
    for (NSString *flagKey in flagConfigDictionary.allKeys) {
        LDFlagConfigValue *flagConfigValue = flagConfigDictionary[flagKey];

        LDFlagCounter *flagCounter = [LDFlagCounter counterWithFlagKey:flagKey defaultValue:flagConfigValue.value];

        XCTAssertEqualObjects(flagCounter.flagKey, flagKey);
        XCTAssertEqualObjects(flagCounter.defaultValue, flagConfigValue.value);
        XCTAssertEqual(flagCounter.valueCounters.count, 0);
    }
}

/* Tests logRequest by logging a simulated known flagConfigValue for each flag value type 3 times. The first should add a flagValueCounter that contains the value, version, & variation. Subsequent logRequests that have the same variation should increment the counter on the existing flagValueCounter. The test also verifies that the logRequest call doesn't create a new flagValueCounter.
   The default value can change with every call to the LDClient's variation method. The defaultValue passed into logRequest updates the defaultValue recorded. Since LaunchDarkly doesn't care if the version changes, there is no test to verify the default value is updated by a logRequest call.
 NOTE: The variation comes from LD to indicate a unique flag value.
 */
-(void)testLogRequestForKnownFlagValues {
    for (NSString* flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        LDFlagCounter *flagCounter = [LDFlagCounter counterWithFlagKey:flagKey defaultValue:defaultValue];
        NSInteger logRequestForUniqueValueCount = 0;

        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            logRequestForUniqueValueCount += 1;
            [flagCounter logRequestWithValue:flagConfigValue.value version:flagConfigValue.version variation:flagConfigValue.version defaultValue:defaultValue];    //TODO: When the variation is added to the LDFlagConfigValue, use that instead

            XCTAssertEqual(flagCounter.valueCounters.count, logRequestForUniqueValueCount);    //Verify the logRequest call added a new LDFlagValueCounter
            LDFlagValueCounter *flagValueCounter = [flagCounter valueCounterForVariation:flagConfigValue.version];  //TODO: When the variation is added to the LDFlagConfigValue, use that instead
            XCTAssertNotNil(flagValueCounter);
            if (!flagValueCounter) { continue; }

            XCTAssertEqualObjects(flagValueCounter.value, flagConfigValue.value);
            XCTAssertEqual(flagValueCounter.variation, flagConfigValue.version);    //TODO: When the variation is added to the LDFlagConfigValue, use that instead
            XCTAssertEqual(flagValueCounter.version, flagConfigValue.version);
            XCTAssertEqual(flagValueCounter.unknown, NO);
            XCTAssertEqual(flagValueCounter.count, 1);

            //Make a second call to logRequest with the same value. Verify no new flagValueCounters, and the existing flagValueCounter was incremented
            [flagCounter logRequestWithValue:flagConfigValue.value version:flagConfigValue.version variation:flagConfigValue.version defaultValue:defaultValue];    //TODO: When the variation is added to the LDFlagConfigValue, use that instead
            XCTAssertEqual(flagCounter.valueCounters.count, logRequestForUniqueValueCount);
            XCTAssertEqual(flagValueCounter.count, 2);

            //Make a third call to logRequest with the same value and verify no new flagValueCounters, and the count was incremented
            [flagCounter logRequestWithValue:flagConfigValue.value version:flagConfigValue.version variation:flagConfigValue.version defaultValue:defaultValue];    //TODO: When the variation is added to the LDFlagConfigValue, use that instead
            XCTAssertEqual(flagCounter.valueCounters.count, logRequestForUniqueValueCount);
            XCTAssertEqual(flagValueCounter.count, 3);
        }
    }
}

-(void)testLogRequestForUnknownFlagValues {
    for (NSString* flagKey in [LDFlagConfigValue flagKeys]) {
        id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        LDFlagCounter *flagCounter = [LDFlagCounter counterWithFlagKey:flagKey defaultValue:defaultValue];

        [flagCounter logRequestWithValue:nil version:kLDFlagConfigVersionDoesNotExist variation:kLDFlagConfigVariationDoesNotExist defaultValue:defaultValue];

        XCTAssertEqual(flagCounter.valueCounters.count, 1);    //Verify the logRequest call added a new LDFlagValueCounter
        LDFlagValueCounter *flagValueCounter = [flagCounter valueCounterForVariation:kLDFlagConfigVariationDoesNotExist];
        XCTAssertNotNil(flagValueCounter);
        if (!flagValueCounter) { continue; }

        XCTAssertNil(flagValueCounter.value);
        XCTAssertEqual(flagValueCounter.variation, kLDFlagConfigVariationDoesNotExist);
        XCTAssertEqual(flagValueCounter.version, kLDFlagConfigVersionDoesNotExist);
        XCTAssertEqual(flagValueCounter.unknown, YES);
        XCTAssertEqual(flagValueCounter.count, 1);

        //Make a second call to logRequest with an unknown value. Verify no new flagValueCounters, and the existing flagValueCounter was incremented
        [flagCounter logRequestWithValue:nil version:kLDFlagConfigVersionDoesNotExist variation:kLDFlagConfigVariationDoesNotExist defaultValue:defaultValue];
        XCTAssertEqual(flagCounter.valueCounters.count, 1);
        XCTAssertEqual(flagValueCounter.count, 2);

        //Make a third call to logRequest with the same value and verify no new flagValueCounters, and the count was incremented
        [flagCounter logRequestWithValue:nil version:kLDFlagConfigVersionDoesNotExist variation:kLDFlagConfigVariationDoesNotExist defaultValue:defaultValue];
        XCTAssertEqual(flagCounter.valueCounters.count, 1);
        XCTAssertEqual(flagValueCounter.count, 3);
    }
}

-(void)testDictionaryValueForKnownFlagValues {
    for (NSString* flagKey in [LDFlagConfigValue flagKeys]) {
        LDFlagCounter *flagCounter = [LDFlagCounter stubForFlagKey:flagKey];
        NSDictionary *flagCounterDictionary = [flagCounter dictionaryValue];

        XCTAssertTrue([flagCounter hasPropertiesMatchingDictionary:flagCounterDictionary]);
    }
}

-(void)testDictionaryValueForUnknownFlagValues {
    for (NSString* flagKey in [LDFlagConfigValue flagKeys]) {
        LDFlagCounter *flagCounter = [LDFlagCounter stubForFlagKey:flagKey useUnknownValues:YES];
        NSDictionary *flagCounterDictionary = [flagCounter dictionaryValue];

        XCTAssertTrue([flagCounter hasPropertiesMatchingDictionary:flagCounterDictionary]);
    }
}

@end
