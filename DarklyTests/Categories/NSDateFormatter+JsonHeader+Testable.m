//
//  NSDateFormatter+JsonHeader+Testable.m
//  DarklyTests
//
//  Created by Mark Pokorny on 5/8/18. +JMJ
//  Copyright © 2018 LaunchDarkly. All rights reserved.
//

#import "NSDateFormatter+JsonHeader.h"
#import "NSDateFormatter+JsonHeader+Testable.h"

NSString * const kDateHeaderValueDate = @"Mon, 07 May 2018 19:46:29 GMT";

@implementation NSDateFormatter(JsonHeader_Testable)
+(NSDate*)eventDateHeaderStub {
    return [[NSDateFormatter jsonHeaderDateFormatter] dateFromString:kDateHeaderValueDate];
}
@end
