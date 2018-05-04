//
//  LDEventTrackingContextTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 5/4/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LDEventTrackingContext.h"
#import "LDEventTrackingContext+Testable.h"
#import "NSDate+ReferencedDate.h"

@interface LDEventTrackingContextTest : XCTestCase

@end

@implementation LDEventTrackingContextTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testContextAndInitWithObject {
    NSDate *debugEventsUntilDate = [[NSDate date] dateByAddingTimeInterval:30.0];
    for (NSNumber *boolObject in @[@NO, @YES]) {
        BOOL trackEvents = [boolObject boolValue];
        NSDictionary *contextDictionary = @{kLDEventTrackingContextKeyTrackEvents: boolObject, kLDEventTrackingContextKeyDebugEventsUntilDate: @([debugEventsUntilDate millisSince1970])};

        LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext contextWithObject:contextDictionary];

        XCTAssertEqual(eventTrackingContext.trackEvents, trackEvents);
        XCTAssertTrue([eventTrackingContext.debugEventsUntilDate isWithinTimeInterval:1.0 ofDate:debugEventsUntilDate]);

        //without the debugEventsUntilDate
        contextDictionary = @{kLDEventTrackingContextKeyTrackEvents: boolObject};

        eventTrackingContext = [LDEventTrackingContext contextWithObject:contextDictionary];

        XCTAssertEqual(eventTrackingContext.trackEvents, trackEvents);
        XCTAssertNil(eventTrackingContext.debugEventsUntilDate);
    }

    LDEventTrackingContext *eventTrackingContext = [LDEventTrackingContext contextWithObject:nil];
    XCTAssertNil(eventTrackingContext);

    eventTrackingContext = [LDEventTrackingContext contextWithObject:@{}];
    XCTAssertNil(eventTrackingContext);

    eventTrackingContext = [LDEventTrackingContext contextWithObject:@{kLDEventTrackingContextKeyDebugEventsUntilDate: @([debugEventsUntilDate millisSince1970])}];
    XCTAssertNil(eventTrackingContext);

    eventTrackingContext = [LDEventTrackingContext contextWithObject:@(3)];
    XCTAssertNil(eventTrackingContext);
}

@end
