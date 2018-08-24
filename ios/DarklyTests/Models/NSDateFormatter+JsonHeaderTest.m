//
//  NSDateFormatter+JsonHeaderTest.m
//  DarklyTests
//
//  Created by Mark Pokorny on 5/8/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSDateFormatter+JsonHeader.h"

@interface NSDateFormatter_JsonHeaderTest : XCTestCase

@end

@implementation NSDateFormatter_JsonHeaderTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

-(void)testJsonHeaderDateFormatter {
    NSString *targetDateString = @"Mon, 07 May 2018 19:46:29 GMT";

    //Mon, 07 May 2018 19:46:29 GMT
    NSDateComponents *dateComponents = [[NSDateComponents alloc] init];
    dateComponents.calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    dateComponents.year = 2018;
    dateComponents.month = 5;
    dateComponents.day = 7;
    dateComponents.hour = 19;
    dateComponents.minute = 46;
    dateComponents.second = 29;
    dateComponents.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    NSDate *targetDate = [dateComponents date];

    NSDateFormatter *subject = [NSDateFormatter jsonHeaderDateFormatter];

    NSDate *formatterDate = [subject dateFromString:targetDateString];
    XCTAssertEqualObjects(formatterDate, targetDate);

    NSString *formatterDateString = [subject stringFromDate:targetDate];
    XCTAssertEqualObjects(formatterDateString, targetDateString);

}

@end
