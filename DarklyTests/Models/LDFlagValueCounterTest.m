//
//  LDFlagValueCounterTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagValueCounter.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"

@interface LDFlagValueCounterTest : XCTestCase

@end

@implementation LDFlagValueCounterTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testInitAndCounterWithValueConstructors {
    LDFlagConfigModel *flagConfig = [LDFlagConfigModel flagConfigFromJsonFileNamed:@"featureFlags-excludeNulls-withVersions"];
    for (NSString *flagKey in flagConfig.featuresJsonDictionary.allKeys) {
        LDFlagConfigValue *flagConfigValue = flagConfig.featuresJsonDictionary[flagKey];
        NSInteger variation = arc4random_uniform(9) + 1;

        LDFlagValueCounter *flagValueCounter = [LDFlagValueCounter counterWithValue:flagConfigValue.value variation:variation version:flagConfigValue.version];

        XCTAssertEqualObjects(flagValueCounter.value, flagConfigValue.value);
        XCTAssertEqual(flagValueCounter.variation, variation);
        XCTAssertEqual(flagValueCounter.version, flagConfigValue.version);
        XCTAssertEqual(flagValueCounter.count, 0);
        XCTAssertEqual(flagValueCounter.unknown, NO);
    }
}


@end
