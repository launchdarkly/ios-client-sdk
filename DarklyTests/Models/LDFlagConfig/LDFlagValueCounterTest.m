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

extern const NSInteger kLDFlagConfigValueItemDoesNotExist;
extern const NSInteger kLDFlagConfigValueItemDoesNotExist;

@interface LDFlagValueCounterTest : XCTestCase
@property (nonatomic, strong) NSDictionary<NSString*, LDFlagConfigValue*> *flagConfigDictionary;
@end

@implementation LDFlagValueCounterTest

- (void)setUp {
    [super setUp];
    self.flagConfigDictionary = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-withVersions"].featuresJsonDictionary;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testInitAndCounterWithFlagConfigValueConstructors {
    for (NSString *flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            LDFlagValueCounter *flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:flagConfigValue];

            XCTAssertEqualObjects(flagValueCounter.flagConfigValue, flagConfigValue);
            XCTAssertEqual(flagValueCounter.count, 1);
            XCTAssertEqual(flagValueCounter.known, YES);
        }
    }

    LDFlagValueCounter *flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:nil];
    XCTAssertNil(flagValueCounter.flagConfigValue);
    XCTAssertEqual(flagValueCounter.count, 1);
    XCTAssertEqual(flagValueCounter.known, NO);
}

-(void)testDictionaryValue {
    for (NSString *flagKey in self.flagConfigDictionary.allKeys) {
        LDFlagConfigValue *flagConfigValue = self.flagConfigDictionary[flagKey];
        LDFlagValueCounter *flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:flagConfigValue];

        NSDictionary *flagValueCounterDictionary = [flagValueCounter dictionaryValue];

        XCTAssertTrue([flagValueCounter hasPropertiesMatchingDictionary:flagValueCounterDictionary]);

        //test version & variation do not exist
        flagConfigValue.modelVersion = kLDFlagConfigValueItemDoesNotExist;
        flagConfigValue.variation = kLDFlagConfigValueItemDoesNotExist;
        flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:flagConfigValue];

        flagValueCounterDictionary = [flagValueCounter dictionaryValue];

        XCTAssertTrue([flagValueCounter hasPropertiesMatchingDictionary:flagValueCounterDictionary]);
    }

    //flagConfigValue nil
    LDFlagValueCounter *flagValueCounter = [LDFlagValueCounter counterWithFlagConfigValue:nil];

    NSDictionary *flagValueCounterDictionary = [flagValueCounter dictionaryValue];

    XCTAssertTrue([flagValueCounter hasPropertiesMatchingDictionary:flagValueCounterDictionary]);
}

@end
