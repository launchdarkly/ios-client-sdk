//
//  LDFlagConfigTrackerTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/19/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDFlagConfigTracker.h"
#import "NSDate+ReferencedDate.h"
#import "LDFlagConfigValue+Testable.h"
#import "LDFlagCounter.h"

@interface LDFlagConfigTrackerTest : XCTestCase

@end

@implementation LDFlagConfigTrackerTest

-(void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

-(void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testInitAndTrackerConstructors {
    NSInteger creationMillis = [[NSDate date] millisSince1970];
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];

    XCTAssertTrue(labs(tracker.startDateMillis - creationMillis) <= 1);
    XCTAssertNotNil(tracker.flagCounters);
    XCTAssertEqual(tracker.flagCounters.count, 0);
}

-(void)testLogRequestForKnownValues {
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];
    for (NSString* flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        NSInteger logRequestForUniqueValueCount = 0;

        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            logRequestForUniqueValueCount += 1;
            [tracker logRequestForFlagKey:flagKey flagConfigValue:flagConfigValue defaultValue:defaultValue];

            LDFlagCounter *flagCounter = tracker.flagCounters[flagKey];
            XCTAssertNotNil(flagCounter);    //Verify the logRequest call added a new LDFlagCounter
            if (!flagCounter) { continue; }

            XCTAssertEqual(flagCounter.valueCounters.count, logRequestForUniqueValueCount); //Verify the logRequest call added a new LDFlagValueCounter
            LDFlagValueCounter *flagValueCounter = [flagCounter valueCounterForVariation:flagConfigValue.version];  //TODO: When the variation is added to the LDFlagConfigValue, use that instead
            XCTAssertNotNil(flagValueCounter);
            if (!flagValueCounter) { continue; }

            XCTAssertEqualObjects(flagValueCounter.value, flagConfigValue.value);
            XCTAssertEqual(flagValueCounter.variation, flagConfigValue.version);    //TODO: When the variation is added to the LDFlagConfigValue, use that instead
            XCTAssertEqual(flagValueCounter.version, flagConfigValue.version);
            XCTAssertEqual(flagValueCounter.known, YES);
            XCTAssertEqual(flagValueCounter.count, 1);

            //Make a second call to logRequest with the same flag key & value. Verify no new flagValueCounters, and the existing flagValueCounter was incremented
            [tracker logRequestForFlagKey:flagKey flagConfigValue:flagConfigValue defaultValue:defaultValue];
            XCTAssertEqual(flagCounter.valueCounters.count, logRequestForUniqueValueCount);
            XCTAssertEqual(flagValueCounter.count, 2);

            //Make a third call to logRequest with the same value and verify no new flagValueCounters, and the count was incremented
            [tracker logRequestForFlagKey:flagKey flagConfigValue:flagConfigValue defaultValue:defaultValue];
            XCTAssertEqual(flagCounter.valueCounters.count, logRequestForUniqueValueCount);
            XCTAssertEqual(flagValueCounter.count, 3);
        }
    }
}

-(void)testLogRequestForUnknownFlagValues {
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];
    for (NSString* flagKey in [LDFlagConfigValue flagKeys]) {
        id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];

        [tracker logRequestForFlagKey:flagKey flagConfigValue:nil defaultValue:defaultValue];

        LDFlagCounter *flagCounter = tracker.flagCounters[flagKey];
        XCTAssertNotNil(flagCounter);    //Verify the logRequest call added a new LDFlagCounter
        if (!flagCounter) { continue; }

        XCTAssertEqual(flagCounter.valueCounters.count, 1);    //Verify the logRequest call added a new LDFlagValueCounter
        LDFlagValueCounter *flagValueCounter = [flagCounter valueCounterForVariation:kLDFlagConfigVariationDoesNotExist];
        XCTAssertNotNil(flagValueCounter);
        if (!flagValueCounter) { continue; }

        XCTAssertEqualObjects(flagValueCounter.value, defaultValue);
        XCTAssertEqual(flagValueCounter.variation, kLDFlagConfigVariationDoesNotExist);
        XCTAssertEqual(flagValueCounter.version, kLDFlagConfigVersionDoesNotExist);
        XCTAssertEqual(flagValueCounter.known, NO);
        XCTAssertEqual(flagValueCounter.count, 1);

        //Make a second call to logRequest with an unknown value. Verify no new flagValueCounters, and the existing flagValueCounter was incremented
        [tracker logRequestForFlagKey:flagKey flagConfigValue:nil defaultValue:defaultValue];
        XCTAssertEqual(flagCounter.valueCounters.count, 1);
        XCTAssertEqual(flagValueCounter.count, 2);

        //Make a third call to logRequest with the same value and verify no new flagValueCounters, and the count was incremented
        [tracker logRequestForFlagKey:flagKey flagConfigValue:nil defaultValue:defaultValue];
        XCTAssertEqual(flagCounter.valueCounters.count, 1);
        XCTAssertEqual(flagValueCounter.count, 3);
    }
}
@end
