//
//  LDThrottlerTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 4/4/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import "DarklyConstants.h"
#import "LDThrottler.h"
#import "LDThrottler+Testable.h"

@interface LDThrottlerTest: DarklyXCTestCase

@end

const NSTimeInterval delayInterval = 10.0;

@implementation LDThrottlerTest
- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testInitWithMaxDelaySeconds {
    LDThrottler *throttler = [[LDThrottler alloc] initWithMaxDelayInterval:delayInterval];
    XCTAssertTrue(throttler.maxDelayInterval == delayInterval);
    XCTAssertTrue(throttler.runAttempts == 0);
    XCTAssertTrue(throttler.delayInterval == 0);
    XCTAssertNil(throttler.delayTimer);
}

-(void)testInitWithMaxDelaySecondsTooLong {
    LDThrottler *throttler = [[LDThrottler alloc] initWithMaxDelayInterval:kMaxThrottlingDelayInterval + 1.0];
    XCTAssertTrue(throttler.maxDelayInterval == kMaxThrottlingDelayInterval);
    XCTAssertTrue(throttler.runAttempts == 0);
    XCTAssertTrue(throttler.delayInterval == 0);
    XCTAssertNil(throttler.delayTimer);
}

-(void)testInitWithMaxDelaySecondsTooShort {
    LDThrottler *throttler = [[LDThrottler alloc] initWithMaxDelayInterval:0];
    XCTAssertTrue(throttler.maxDelayInterval == kMaxThrottlingDelayInterval);
    XCTAssertTrue(throttler.runAttempts == 0);
    XCTAssertTrue(throttler.delayInterval == 0);
    XCTAssertNil(throttler.delayTimer);
}

-(void)testRunThrottledFirstTry {
    LDThrottler *throttler = [[LDThrottler alloc] initWithMaxDelayInterval:delayInterval];
    XCTestExpectation *timerFiredCalledExpectation = [self expectationWithDescription:@"Timer fired called expectation"];
    throttler.timerFiredCallback = ^{
        [timerFiredCalledExpectation fulfill];
    };
    __block NSInteger completionBlockCallCount = 0;
    __block NSDate *completionBlockCallDate;
    NSDate *runThrottledStartDate = [NSDate date];

    [throttler runThrottled:^{
        completionBlockCallCount += 1;
        completionBlockCallDate = [NSDate date];
    }];

    [self waitForExpectations:@[timerFiredCalledExpectation] timeout:2.0];

    XCTAssertTrue(completionBlockCallCount == 1);
    XCTAssertNotNil(completionBlockCallDate);
    if (completionBlockCallDate) {
        NSTimeInterval delayTime = [completionBlockCallDate timeIntervalSinceDate:runThrottledStartDate];
        XCTAssertTrue(delayTime < 0.1);
    }
    XCTAssertTrue(throttler.runAttempts == 0);
    XCTAssertTrue(throttler.delayInterval == 0);
    XCTAssertNil(throttler.timerStartDate);
    XCTAssertNil(throttler.delayTimer);
}

-(void)testRunThrottledSecondTry {
    LDThrottler *throttler = [[LDThrottler alloc] initWithMaxDelayInterval:delayInterval];
    XCTestExpectation *timerFiredCalledExpectation = [self expectationWithDescription:@"Timer fired called expectation"];
    throttler.timerFiredCallback = ^{
        [timerFiredCalledExpectation fulfill];
    };
    __block NSInteger completionBlockCallCount = 0;
    __block NSMutableArray<NSDate*> *completionBlockCallDates = [NSMutableArray arrayWithCapacity:2];
    NSDate *runThrottledStartDate = [NSDate date];

    for (NSUInteger attempt = 0; attempt < 2; attempt++) {
        [throttler runThrottled:^{
            completionBlockCallCount += 1;
            [completionBlockCallDates addObject:[NSDate date]];
        }];
    }

    [self waitForExpectations:@[timerFiredCalledExpectation] timeout:4.0];

    XCTAssertTrue(completionBlockCallCount == 2);
    XCTAssertTrue(completionBlockCallDates.count == 2);
    if (completionBlockCallDates.count == 2) {
        NSTimeInterval delayTime = [completionBlockCallDates[0] timeIntervalSinceDate:runThrottledStartDate];
        XCTAssertTrue(delayTime < 0.1);
        delayTime = [completionBlockCallDates[1] timeIntervalSinceDate:completionBlockCallDates[0]];
        XCTAssertTrue(delayTime < 4.0);
    }
    XCTAssertTrue(throttler.runAttempts == 0);
    XCTAssertTrue(throttler.delayInterval == 0);
    XCTAssertNil(throttler.timerStartDate);
    XCTAssertNil(throttler.delayTimer);
}

-(void)testRunThrottledMultipleTries {
    LDThrottler *throttler = [[LDThrottler alloc] initWithMaxDelayInterval:delayInterval];
    NSUInteger runAttempts = ceil(log2(delayInterval));

    __block NSInteger completionBlockCallCount = 0;
    NSDate *timerStartDate;
    for (NSUInteger attempt = 0; attempt < runAttempts; attempt++) {
        NSTimeInterval delayIntervalForPreviousAttempt = throttler.delayInterval;
        [throttler runThrottled:^{
            completionBlockCallCount += 1;
        }];
        if (attempt == 0) {
            timerStartDate = throttler.timerStartDate;
        }
        XCTAssertTrue(delayIntervalForPreviousAttempt < throttler.delayInterval);
        XCTAssertEqual(timerStartDate, throttler.timerStartDate);
        XCTAssertNotNil(throttler.delayTimer);
    }
    //Didn't wait for the delay timer to fire,
    XCTAssertTrue(completionBlockCallCount == 1);
    XCTAssertTrue(throttler.runAttempts == runAttempts);
}

-(void)testRunThrottledMaxDelay {
    LDThrottler *throttler = [[LDThrottler alloc] initWithMaxDelayInterval:delayInterval];
    __block NSInteger completionBlockCallCount = 0;
    NSDate *timerStartDate;
    NSUInteger runAttempts = ceil(log2(delayInterval)) + 1;

    for (NSUInteger attempt = 0; attempt < runAttempts; attempt++) {
        NSTimeInterval delayIntervalForPreviousAttempt = throttler.delayInterval;
        [throttler runThrottled:^{
            completionBlockCallCount += 1;
        }];
        if (attempt == 0) {
            timerStartDate = throttler.timerStartDate;
        }
        XCTAssertTrue(delayIntervalForPreviousAttempt < throttler.delayInterval || throttler.delayInterval == delayInterval);
        XCTAssertEqual(timerStartDate, throttler.timerStartDate);
        XCTAssertNotNil(throttler.delayTimer);
    }

    //Didn't wait for the delay timer to fire,
    XCTAssertTrue(completionBlockCallCount == 1);
    XCTAssertTrue(throttler.runAttempts == runAttempts);
    XCTAssertTrue(throttler.delayInterval == delayInterval);
}

@end
