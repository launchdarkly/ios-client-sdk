//
//  LDFlagValueCounterTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagValueCounter.h"
#import "LDFlagValueCounter+Testable.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDFlagConfigValue.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDEventTrackingContext+Testable.h"

extern const NSInteger kLDFlagConfigValueItemDoesNotExist;
extern const NSInteger kLDFlagConfigValueItemDoesNotExist;

@interface LDFlagValueCounterTest : XCTestCase
@property (nonatomic, strong) NSDictionary<NSString*, LDFlagConfigValue*> *flagConfigDictionary;
@end

@implementation LDFlagValueCounterTest

- (void)setUp {
    [super setUp];
    self.flagConfigDictionary = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags" eventTrackingContext:[LDEventTrackingContext stub]].featuresJsonDictionary;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testInitAndCounterWithFlagConfigValueConstructors {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            LDFlagValueCounter *flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:flagConfigValue reportedFlagValue:flagConfigValue.value];

            XCTAssertEqualObjects(flagValueCounter.flagConfigValue, flagConfigValue);
            XCTAssertEqualObjects(flagValueCounter.reportedFlagValue, flagConfigValue.value);
            XCTAssertEqual(flagValueCounter.count, 1);
            XCTAssertEqual(flagValueCounter.known, YES);
        }
    }

    id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:kLDFlagKeyIsABool];
    LDFlagValueCounter *flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:nil reportedFlagValue:defaultValue];
    XCTAssertNil(flagValueCounter.flagConfigValue);
    XCTAssertEqualObjects(flagValueCounter.reportedFlagValue, defaultValue);
    XCTAssertEqual(flagValueCounter.count, 1);
    XCTAssertEqual(flagValueCounter.known, NO);
}

-(void)testDictionaryValue {
    for (NSString *flagKey in self.flagConfigDictionary.allKeys) {
        LDFlagConfigValue *flagConfigValue = self.flagConfigDictionary[flagKey];
        LDFlagValueCounter *flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:flagConfigValue reportedFlagValue:flagConfigValue.value];

        NSDictionary *flagValueCounterDictionary = [flagValueCounter dictionaryValue];

        XCTAssertEqualObjects(flagValueCounterDictionary[kLDFlagConfigValueKeyValue], flagConfigValue.value);
        XCTAssertEqual([flagValueCounterDictionary[kLDFlagConfigValueKeyVariation] integerValue], flagConfigValue.variation);
        XCTAssertEqualObjects(flagValueCounterDictionary[kLDFlagConfigValueKeyVersion], flagConfigValue.flagVersion);
        XCTAssertNil(flagValueCounterDictionary[kLDFlagConfigValueKeyFlagVersion]);
        XCTAssertNil(flagValueCounterDictionary[kLDEventTrackingContextKeyTrackEvents]);
        XCTAssertNil(flagValueCounterDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);

        //test version & variation do not exist
        flagConfigValue.modelVersion = kLDFlagConfigValueItemDoesNotExist;
        flagConfigValue.variation = kLDFlagConfigValueItemDoesNotExist;
        flagConfigValue.flagVersion = nil;
        flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:flagConfigValue reportedFlagValue:flagConfigValue.value];

        flagValueCounterDictionary = [flagValueCounter dictionaryValue];

        XCTAssertEqualObjects(flagValueCounterDictionary[kLDFlagConfigValueKeyValue], flagConfigValue.value);
        XCTAssertNil(flagValueCounterDictionary[kLDFlagConfigValueKeyVariation]);
        XCTAssertNil(flagValueCounterDictionary[kLDFlagConfigValueKeyVersion]);
        XCTAssertNil(flagValueCounterDictionary[kLDFlagConfigValueKeyFlagVersion]);
        XCTAssertNil(flagValueCounterDictionary[kLDEventTrackingContextKeyTrackEvents]);
        XCTAssertNil(flagValueCounterDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);
    }

    //flagConfigValue nil
    id defaultValue = @(YES);
    LDFlagValueCounter *flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:nil reportedFlagValue:defaultValue];

    NSDictionary *flagValueCounterDictionary = [flagValueCounter dictionaryValue];
    
    XCTAssertEqualObjects(flagValueCounterDictionary[kLDFlagConfigValueKeyValue], defaultValue);
    XCTAssertEqualObjects(flagValueCounterDictionary[kLDFlagValueCounterKeyUnknown], @(YES));
    XCTAssertEqualObjects(flagValueCounterDictionary[kLDFlagValueCounterKeyCount], @(1));
    XCTAssertNil(flagValueCounterDictionary[kLDFlagConfigValueKeyVariation]);
    XCTAssertNil(flagValueCounterDictionary[kLDFlagConfigValueKeyVersion]);
    XCTAssertNil(flagValueCounterDictionary[kLDFlagConfigValueKeyFlagVersion]);
    XCTAssertNil(flagValueCounterDictionary[kLDEventTrackingContextKeyTrackEvents]);
    XCTAssertNil(flagValueCounterDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate]);
}

@end
