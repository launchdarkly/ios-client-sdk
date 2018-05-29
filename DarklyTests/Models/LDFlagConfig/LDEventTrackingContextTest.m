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

-(void)testContextAndInitWithObjectAndDictionaryValue {
    NSDate *debugEventsUntilDate = [[NSDate date] dateByAddingTimeInterval:30.0];
    for (NSNumber *boolObject in @[@NO, @YES]) {
        BOOL trackEvents = [boolObject boolValue];
        LDEventTrackingContext *originalContext = [LDEventTrackingContext contextWithTrackEvents:trackEvents debugEventsUntilDate:debugEventsUntilDate];
        NSMutableDictionary *contextDictionary = [NSMutableDictionary dictionaryWithDictionary:[originalContext dictionaryValue]];

        LDEventTrackingContext *restoredContext = [LDEventTrackingContext contextWithObject:[contextDictionary copy]];

        XCTAssertEqualObjects(restoredContext, originalContext);

        //without the debugEventsUntilDate
        originalContext = [LDEventTrackingContext contextWithTrackEvents:trackEvents debugEventsUntilDate:nil];
        contextDictionary = [NSMutableDictionary dictionaryWithDictionary:[originalContext dictionaryValue]];

        restoredContext = [LDEventTrackingContext contextWithObject:[contextDictionary copy]];

        XCTAssertEqualObjects(restoredContext, originalContext);

        //null debugEventsUntilDate
        originalContext = [LDEventTrackingContext contextWithTrackEvents:trackEvents debugEventsUntilDate:nil];
        contextDictionary = [NSMutableDictionary dictionaryWithDictionary:[originalContext dictionaryValue]];
        contextDictionary[kLDEventTrackingContextKeyDebugEventsUntilDate] = [NSNull null];

        restoredContext = [LDEventTrackingContext contextWithObject:[contextDictionary copy]];

        XCTAssertEqualObjects(restoredContext, originalContext);
    }

    LDEventTrackingContext *trackingContext = [LDEventTrackingContext contextWithObject:nil];
    XCTAssertNil(trackingContext);

    trackingContext = [LDEventTrackingContext contextWithObject:@{}];
    XCTAssertNil(trackingContext);

    trackingContext = [LDEventTrackingContext contextWithObject:@{kLDEventTrackingContextKeyTrackEvents: [NSNull null]}];
    XCTAssertNil(trackingContext);

    trackingContext = [LDEventTrackingContext contextWithObject:@{kLDEventTrackingContextKeyDebugEventsUntilDate: @([debugEventsUntilDate millisSince1970])}];
    XCTAssertNil(trackingContext);

    trackingContext = [LDEventTrackingContext contextWithObject:@(3)];
    XCTAssertNil(trackingContext);
}

-(void)testEncodeAndDecodeWithCoder {
    NSDate *debugEventsUntilDate = [[NSDate date] dateByAddingTimeInterval:30.0];
    for (NSNumber *boolObject in @[@NO, @YES]) {
        BOOL trackEvents = [boolObject boolValue];
        LDEventTrackingContext *originalContext = [LDEventTrackingContext contextWithTrackEvents:trackEvents debugEventsUntilDate:debugEventsUntilDate];

        NSData *encodedContext = [NSKeyedArchiver archivedDataWithRootObject:originalContext];
        XCTAssertNotNil(encodedContext);

        LDEventTrackingContext *restoredContext = [NSKeyedUnarchiver unarchiveObjectWithData:encodedContext];
        XCTAssertEqualObjects(restoredContext, originalContext);
    }
}

@end
