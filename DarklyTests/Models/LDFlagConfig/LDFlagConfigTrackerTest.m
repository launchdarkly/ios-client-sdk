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
#import "LDFlagCounter+Testable.h"
#import "LDFlagValueCounter.h"
#import "LDEventTrackingContext.h"
#import "LDFlagConfigTracker.h"
#import "LDFlagConfigTracker+Testable.h"

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
    LDMillisecond creationMillis = [[NSDate date] millisSince1970];
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];

    XCTAssertTrue(labs(tracker.startDateMillis - creationMillis) <= 1);
    XCTAssertNotNil(tracker.mutableFlagCounters);
    XCTAssertFalse(tracker.hasTrackedEvents);
}

-(void)testLogRequestForKnownValues {
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];
    for (NSString* flagKey in [LDFlagConfigValue flagKeys]) {
        NSArray<LDFlagConfigValue*> *flagConfigValues = [LDFlagConfigValue stubFlagConfigValuesForFlagKey:flagKey];
        id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];
        NSInteger logRequestForUniqueValueCount = 0;

        for (LDFlagConfigValue *flagConfigValue in flagConfigValues) {
            logRequestForUniqueValueCount += 1;
            [tracker logRequestForFlagKey:flagKey reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultValue:defaultValue];

            XCTAssertTrue(tracker.hasTrackedEvents);

            LDFlagCounter *flagCounter = tracker.mutableFlagCounters[flagKey];
            XCTAssertNotNil(flagCounter);    //Verify the logRequest call added a new LDFlagCounter
            if (!flagCounter) { continue; }

            XCTAssertTrue(flagCounter.hasLoggedRequests);
            XCTAssertEqual(flagCounter.flagValueCounters.count, logRequestForUniqueValueCount); //Verify the logRequest call added a new LDFlagValueCounter
            LDFlagValueCounter *flagValueCounter = [flagCounter valueCounterForFlagConfigValue:flagConfigValue];
            XCTAssertNotNil(flagValueCounter);
            if (!flagValueCounter) { continue; }

            XCTAssertEqualObjects(flagValueCounter.flagConfigValue, flagConfigValue);
            XCTAssertEqual(flagValueCounter.known, YES);
            XCTAssertEqual(flagValueCounter.count, 1);

            //Make a second call to logRequest with the same flag key & value. Verify no new flagValueCounters, and the existing flagValueCounter was incremented
            [tracker logRequestForFlagKey:flagKey reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultValue:defaultValue];
            XCTAssertEqual(flagCounter.flagValueCounters.count, logRequestForUniqueValueCount);
            XCTAssertEqual(flagValueCounter.count, 2);

            //Make a third call to logRequest with the same value and verify no new flagValueCounters, and the count was incremented
            [tracker logRequestForFlagKey:flagKey reportedFlagValue:flagConfigValue.value flagConfigValue:flagConfigValue defaultValue:defaultValue];
            XCTAssertEqual(flagCounter.flagValueCounters.count, logRequestForUniqueValueCount);
            XCTAssertEqual(flagValueCounter.count, 3);
        }
    }
}

-(void)testLogRequestForUnknownFlagValues {
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];
    for (NSString* flagKey in [LDFlagConfigValue flagKeys]) {
        id defaultValue = [LDFlagConfigValue defaultValueForFlagKey:flagKey];

        [tracker logRequestForFlagKey:flagKey reportedFlagValue:defaultValue flagConfigValue:nil defaultValue:defaultValue];

        LDFlagCounter *flagCounter = tracker.mutableFlagCounters[flagKey];
        XCTAssertNotNil(flagCounter);    //Verify the logRequest call added a new LDFlagCounter
        if (!flagCounter) { continue; }

        XCTAssertEqual(flagCounter.flagValueCounters.count, 1);    //Verify the logRequest call added a new LDFlagValueCounter
        LDFlagValueCounter *flagValueCounter = [flagCounter valueCounterForFlagConfigValue:nil];
        XCTAssertNotNil(flagValueCounter);
        if (!flagValueCounter) { continue; }

        XCTAssertNil(flagValueCounter.flagConfigValue);
        XCTAssertEqual(flagValueCounter.known, NO);
        XCTAssertEqual(flagValueCounter.count, 1);

        //Make a second call to logRequest with an unknown value. Verify no new flagValueCounters, and the existing flagValueCounter was incremented
        [tracker logRequestForFlagKey:flagKey reportedFlagValue:defaultValue flagConfigValue:nil defaultValue:defaultValue];
        XCTAssertEqual(flagCounter.flagValueCounters.count, 1);
        XCTAssertEqual(flagValueCounter.count, 2);

        //Make a third call to logRequest with the same value and verify no new flagValueCounters, and the count was incremented
        [tracker logRequestForFlagKey:flagKey reportedFlagValue:defaultValue flagConfigValue:nil defaultValue:defaultValue];
        XCTAssertEqual(flagCounter.flagValueCounters.count, 1);
        XCTAssertEqual(flagValueCounter.count, 3);
    }
}

-(void)testLogRequestForEmptyFlagKey {
    LDFlagConfigTracker *tracker = [LDFlagConfigTracker tracker];
    LDEventTrackingContext *eventTrackingContext = [[LDEventTrackingContext alloc] init];
    LDFlagConfigValue *flagConfigValue = [LDFlagConfigValue flagConfigValueFromJsonFileNamed:@"boolConfigIsABool-true" flagKey:kLDFlagKeyIsABool eventTrackingContext:eventTrackingContext];

    [tracker logRequestForFlagKey:@"" reportedFlagValue:@YES flagConfigValue:flagConfigValue defaultValue:@NO];

    XCTAssertFalse(tracker.hasTrackedEvents);
}

-(void)testCopyWithZone {
    LDFlagConfigTracker *originalTracker = [LDFlagConfigTracker stubTracker];

    LDFlagConfigTracker *copiedTracker = [originalTracker copy];

    XCTAssertTrue(copiedTracker != originalTracker);    //pointers differ
    XCTAssertEqual(copiedTracker.startDateMillis, originalTracker.startDateMillis);
    for (NSString *flagKey in originalTracker.mutableFlagCounters.allKeys) {
        //FlagCounter
        LDFlagCounter *originalFlagCounter = originalTracker.mutableFlagCounters[flagKey];
        LDFlagCounter *copiedFlagCounter = copiedTracker.mutableFlagCounters[flagKey];
        XCTAssertTrue(copiedFlagCounter != originalFlagCounter);    //pointers differ
        XCTAssertEqualObjects(copiedFlagCounter.flagKey, originalFlagCounter.flagKey);
        XCTAssertEqualObjects(copiedFlagCounter.defaultValue, originalFlagCounter.defaultValue);
        XCTAssertTrue(copiedFlagCounter.flagValueCounters != originalFlagCounter.flagValueCounters);    //pointers differ
        XCTAssertEqual(copiedFlagCounter.flagValueCounters.count, originalFlagCounter.flagValueCounters.count);
        if (copiedFlagCounter.flagValueCounters.count != originalFlagCounter.flagValueCounters.count) {
            return;
        }
        for (NSInteger index = 0; index < originalFlagCounter.flagValueCounters.count; index++) {
            //FlagValueCounter
            LDFlagValueCounter *originalFlagValueCounter = originalFlagCounter.flagValueCounters[index];
            LDFlagValueCounter *copiedFlagValueCounter = copiedFlagCounter.flagValueCounters[index];
            XCTAssertTrue(copiedFlagValueCounter != originalFlagValueCounter);    //pointers differ
            XCTAssertEqualObjects(copiedFlagValueCounter.reportedFlagValue, originalFlagValueCounter.reportedFlagValue);
            XCTAssertEqual(copiedFlagValueCounter.isKnown, originalFlagValueCounter.isKnown);
            XCTAssertEqual(copiedFlagValueCounter.count, originalFlagValueCounter.count);

            //FlagConfigValue
            LDFlagConfigValue *originalFlagConfigValue = originalFlagValueCounter.flagConfigValue;
            LDFlagConfigValue *copiedFlagConfigValue = copiedFlagValueCounter.flagConfigValue;
            XCTAssertTrue(copiedFlagConfigValue != originalFlagConfigValue);    //pointers differ
            XCTAssertEqualObjects(copiedFlagConfigValue.value, originalFlagConfigValue.value);
            XCTAssertEqual(copiedFlagConfigValue.modelVersion, originalFlagConfigValue.modelVersion);
            XCTAssertEqual(copiedFlagConfigValue.variation, originalFlagConfigValue.variation);
            XCTAssertEqualObjects(copiedFlagConfigValue.flagVersion, originalFlagConfigValue.flagVersion);

            //EventTrackingContext
            LDEventTrackingContext *originalEventTrackingContext = originalFlagConfigValue.eventTrackingContext;
            LDEventTrackingContext *copiedEventTrackingContext = copiedFlagConfigValue.eventTrackingContext;
            XCTAssertTrue(copiedEventTrackingContext != originalEventTrackingContext);    //pointers differ
            XCTAssertEqual(copiedEventTrackingContext.trackEvents, originalEventTrackingContext.trackEvents);
            XCTAssertEqualObjects(copiedEventTrackingContext.debugEventsUntilDate, originalEventTrackingContext.debugEventsUntilDate);
        }
    }
}
@end
