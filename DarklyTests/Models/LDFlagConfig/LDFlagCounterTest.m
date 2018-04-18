//
//  LDFlagCounterTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/18/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagCounter.h"
#import "LDFlagConfigModel.h"
#import "LDFlagConfigModel+Testable.h"
#import "LDFlagConfigValue.h"

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
        XCTAssertEqual(flagCounter.counters.count, 0);
    }
}

-(void)testLogRequest {

}

@end
